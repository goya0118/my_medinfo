import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/drug_api_service.dart';
import '../models/drug_info.dart';
import '../services/camera_manager.dart';
import 'ai_chat_screen.dart'; // 바코드와 YOLO 객체 인식 모두 AI Chat으로 이동
import 'package:medinfo/screens/home_screen.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final CameraManager _cameraManager = CameraManager();
  
  bool _isScanning = true;
  bool _isLoading = false;
  bool _cameraInitialized = false;
  String? _lastScannedBarcode;
  DateTime? _lastScanTime;
  DrugInfo? _drugInfo;
  String? _errorMessage;
  

  bool _isVibrating = false;
  
  static const Duration _scanCooldown = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _stopVibration();
    _cameraManager.dispose();
    super.dispose();
  }


  void _startScanningVibration() {
    if (_isVibrating) return;
    _isVibrating = true;
    _vibrationLoop();
  }

  void _vibrationLoop() async {
    while (_isVibrating && _isScanning && mounted) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (_isVibrating && _isScanning && mounted) {
        HapticFeedback.lightImpact();
      }
    }
  }

  void _stopVibration() {
    _isVibrating = false;
  }

  void _successVibration() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
  }

  // 통합 카메라 초기화
  Future<void> _initializeCamera() async {
    setState(() {
      _cameraInitialized = false;
      _errorMessage = null;
    });

    try {
      final result = await _cameraManager.initializeCamera();
      
      if (!mounted) return;

      if (result.isSuccess) {
        setState(() {
          _cameraInitialized = true;
          _errorMessage = null;
        });

        _startScanningVibration();
        
        // 통합 인식 시작 (바코드 + YOLO 객체)
        _cameraManager.startDetection(
          onBarcodeDetected: _onBarcodeDetected,
          onYOLODetected: _onYOLODetected, // YOLO 객체 인식 추가
        );
        
      } else {
        setState(() {
          _errorMessage = result.getUserMessage();
        });
        
        if (result.isPermissionDenied) {
          _showPermissionDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '카메라 초기화 중 오류가 발생했습니다: $e';
        });
      }
    }
  }

  // 바코드 감지 처리 (기존과 동일 - DrugDetailScreen으로 이동)
  void _onBarcodeDetected(String barcode) async {
    try {
      if (!_isScanning || !mounted) return;

      if (barcode.isEmpty) return;

      final now = DateTime.now();
      if (_lastScannedBarcode == barcode && 
          _lastScanTime != null && 
          now.difference(_lastScanTime!) < _scanCooldown) {
        return;
      }

      _lastScannedBarcode = barcode;
      _lastScanTime = now;

      print('바코드 스캔됨: $barcode');

      // 성공 진동 및 스캔 중지
      _successVibration();
      _stopVibration();
      _cameraManager.stopDetection(); // 모든 인식 중지

      if (mounted) {
        setState(() {
          _isScanning = false;
          _isLoading = true;
          _drugInfo = null;
          _errorMessage = null;
        });
      }

      await _fetchDrugInfo(barcode);
      
    } catch (e) {
      print('바코드 감지 오류: $e');
      _handleError('바코드 처리 중 오류가 발생했습니다.');
    }
  }

  // ✅ 새로 추가: YOLO 객체 감지 처리 (의약품 정보 검색 후 AI Chat Screen으로 이동)
  void _onYOLODetected(List<YOLODetection> detections) async {
    if (detections.isEmpty || !_isScanning || !mounted) return;

    try {
      // 가장 신뢰도가 높은 detection 선택
      final bestDetection = detections.reduce((a, b) => 
        a.confidence > b.confidence ? a : b);

      print('YOLO 객체 인식됨: ${bestDetection.className} (${bestDetection.confidence})');

      // 성공 진동 및 스캔 중지
      _successVibration();
      _stopVibration();
      _cameraManager.stopDetection();

      if (mounted) {
        setState(() {
          _isScanning = false;
          _isLoading = true; // 로딩 표시
          _drugInfo = null;
          _errorMessage = null;
        });
      }

      // ✅ YOLO 클래스 이름으로 의약품 정보 검색 (통합 메서드 사용)
      await _fetchDrugInfo('', yoloClassName: bestDetection.className, yoloDetections: detections);
      
    } catch (e) {
      print('YOLO 객체 감지 오류: $e');
      _handleError('객체 인식 처리 중 오류가 발생했습니다.');
    }
  }



  // ✅ 통합: 의약품 정보 조회 (바코드 + YOLO 통합)
  Future<void> _fetchDrugInfo(String barcode, {String? yoloClassName, List<YOLODetection>? yoloDetections}) async {
    try {
      String searchQuery = barcode;
      String searchType = '바코드';
      
      // YOLO 인식인지 바코드 스캔인지 구분
      if (yoloClassName != null) {
        searchQuery = yoloClassName;
        searchType = 'YOLO 객체';
      }
      
      print('$searchType API 호출 시작: $searchQuery');
      
      // 바코드든 YOLO든 동일한 API 호출 (필요시 DrugApiService 수정)
      DrugInfo? drugInfo;
      if (yoloClassName != null) {
        // YOLO 클래스 이름으로 검색 (DrugApiService에 추가 필요)
        drugInfo = await DrugApiService.getDrugInfoByName(yoloClassName);
      } else {
        // 기존 바코드 검색
        drugInfo = await DrugApiService.getDrugInfo(barcode);
      }
      
      if (mounted) {
        setState(() {
          _drugInfo = drugInfo;
          _isLoading = false;
        });

        if (drugInfo != null) {
          // ✅ 통합: AI Chat Screen으로 이동 (간단한 방식)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AiChatScreen(drugInfo: drugInfo),
            ),
          ).then((_) {
            // 화면에서 돌아왔을 때 스캔 재시작
            _restartScanning();
          });
        } else {
          Fluttertoast.showToast(
            msg: yoloClassName != null 
              ? "\"$yoloClassName\" 의약품 정보를 찾을 수 없습니다"
              : "의약품 정보를 찾을 수 없습니다",
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
          
          _restartScanning();
        }
      }

    } catch (e) {
      print('API 호출 오류: $e');
      _handleError('${yoloClassName != null ? "객체 인식" : "바코드 스캔"} 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  // 에러 처리
  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
      
      Fluttertoast.showToast(
        msg: message,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );

      _restartScanning();
    }
  }

  // 스캔 재시작
  void _restartScanning() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isScanning = true;
        });
        _startScanningVibration();
        
        // 통합 인식 재시작
        _cameraManager.startDetection(
          onBarcodeDetected: _onBarcodeDetected,
          onYOLODetected: _onYOLODetected,
        );
      }
    });
  }

  // 권한 다이얼로그
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카메라 권한 필요'),
        content: const Text('바코드와 객체 인식을 위해 카메라 권한이 필요합니다.\n\n설정 > 개인정보 보호 및 보안 > 카메라에서 이 앱의 권한을 허용해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _initializeCamera();
            },
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  void _toggleFlash() {
    _cameraManager.toggleFlash();
  }

  void _restartCamera() async {
    await _initializeCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleHeader(
        title: const Text(
          '의약품 스캐너',
          style: TextStyle(
            color: Color(0xFF5B32F4),
            fontSize: 30,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xff5B32F4)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            onPressed: _restartCamera,
            icon: const Icon(Icons.refresh, color: Color(0xff5B32F4), size: 28),
            splashRadius: 24,
          ),
        ],
      ),
      // appBar: AppBar(
      //   title: const Text('의약품 스캐너'),
      //   backgroundColor: Colors.blue.shade100,
      //   actions: [
      //     IconButton(
      //       onPressed: _toggleFlash,
      //       icon: const Icon(Icons.flash_on),
      //     ),
      //     IconButton(
      //       onPressed: _restartCamera,
      //       icon: const Icon(Icons.refresh),
      //     ),
      //   ],
      // ),
      body: SafeArea(
        child: Stack(
          children: [
            // ✅ 카메라 뷰 - 비율 유지하면서 전체 화면
            if (_cameraManager.isInitialized)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover, // 비율 유지하면서 화면 채우기
                  child: SizedBox(
                    width: _cameraManager.cameraController!.value.previewSize!.height,
                    height: _cameraManager.cameraController!.value.previewSize!.width,
                    child: CameraPreview(_cameraManager.cameraController!),
                  ),
                ),
              )
            else
              Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_errorMessage != null) ...[
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ] else ...[
                        const SpinKitFadingCircle(
                          color: Colors.white,
                          size: 50.0,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '카메라를 초기화하는 중...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _restartCamera,
                        child: const Text(
                          '카메라 재시작',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
            // ✅ 로딩 오버레이만 유지 (필요할 때만 표시)
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SpinKitFadingCircle(
                        color: Colors.white,
                        size: 50.0,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '의약품 정보를 조회하는 중...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}