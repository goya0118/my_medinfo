import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/drug_api_service.dart';
import '../models/drug_info.dart';
import '../services/camera_manager.dart';
import 'drug_info_screen.dart';

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
  
  // 진동 관련
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

  // 진동 관련 메서드들
  void _startScanningVibration() {
    if (_isVibrating) return;
    _isVibrating = true;
    _vibrationLoop();
  }

  void _vibrationLoop() async {
    while (_isVibrating && _isScanning && mounted) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (_isVibrating && _isScanning && mounted) {
        HapticFeedback.lightImpact();
      }
    }
  }

  void _stopVibration() {
    _isVibrating = false;
  }

  void _successVibration() {
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
        
        // 통합 인식 시작 (바코드 + 알약)
        _cameraManager.startDetection(
          onBarcodeDetected: _onBarcodeDetected,
          onPillDetected: _onPillDetected,
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

  // 바코드 감지 처리
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

  // 알약 감지 처리
  void _onPillDetected(PillClassificationResult? result) async {
    if (result == null || !_isScanning || !mounted) return;

    print('알약 인식됨: ${result.className} (${result.confidence})');

    // 성공 진동 및 스캔 중지
    _successVibration();
    _stopVibration();
    _cameraManager.stopDetection();

    if (mounted) {
      setState(() {
        _isScanning = false;
        _isLoading = false;
      });

      // 알약 결과 화면으로 이동
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PillInfoScreen(
            pillResult: result,
            scanTime: DateTime.now(),
          ),
        ),
      ).then((_) {
        // 화면에서 돌아왔을 때 스캔 재시작
        _restartScanning();
      });
    }
  }

  // 의약품 정보 조회 (바코드용)
  Future<void> _fetchDrugInfo(String barcode) async {
    try {
      print('API 호출 시작: $barcode');
      final drugInfo = await DrugApiService.getDrugInfo(barcode);
      
      if (mounted) {
        setState(() {
          _drugInfo = drugInfo;
          _isLoading = false;
        });

        if (drugInfo != null) {
          // 성공시 새 화면으로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DrugInfoScreen(
                drugInfo: drugInfo,
                barcode: barcode,
              ),
            ),
          ).then((_) {
            // 화면에서 돌아왔을 때 스캔 재시작
            _restartScanning();
          });
        } else {
          Fluttertoast.showToast(
            msg: "의약품 정보를 찾을 수 없습니다",
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
          
          _restartScanning();
        }
      }

    } catch (e) {
      print('API 호출 오류: $e');
      _handleError('API 호출 중 오류가 발생했습니다: ${e.toString()}');
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
          onPillDetected: _onPillDetected,
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
        content: const Text('바코드와 알약 인식을 위해 카메라 권한이 필요합니다.\n\n설정 > 개인정보 보호 및 보안 > 카메라에서 이 앱의 권한을 허용해주세요.'),
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
      appBar: AppBar(
        title: const Text('🏥 스마트 의약품 스캐너'),
        backgroundColor: Colors.blue.shade100,
        actions: [
          IconButton(
            onPressed: _toggleFlash,
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            onPressed: _restartCamera,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 현재 모드 표시 (시각장애인용 간단 메시지)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Text(
                '바코드나 알약을 카메라에 비춰주세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18, // 큰 글씨
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            
            // 카메라 스캐너 (비율 제한 제거)
            Expanded(
              flex: 4, // 더 많은 공간 할당
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      // 카메라 뷰 (Camera 사용) - 전체 영역 채우기
                      if (_cameraManager.isInitialized)
                        Positioned.fill(
                          child: FittedBox(
                            fit: BoxFit.cover, // 전체 영역 채우기
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
                        
                      // 로딩 오버레이
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
              ),
            ),
            
            // 상태 및 결과 표시 (공간 축소)
            Expanded(
              flex: 1, // 공간 축소
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 상태 메시지 (큰 글씨로)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _isScanning 
                              ? Colors.green.shade100 
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage != null
                              ? '❌ $_errorMessage'
                              : _cameraInitialized
                                  ? (_isScanning 
                                      ? '🔍 바코드 또는 알약을 카메라에 비춰주세요'
                                      : _isLoading
                                          ? '⏳ 의약품 정보를 조회하는 중...'
                                          : '✅ 인식 완료!')
                                  : '📷 카메라를 초기화하는 중입니다...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16, // 더 큰 글씨
                            fontWeight: FontWeight.bold,
                            color: _errorMessage != null 
                                ? Colors.red.shade700
                                : _isScanning ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 사용 안내 삭제
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 알약 정보 화면 (기존과 동일)
class PillInfoScreen extends StatelessWidget {
  final PillClassificationResult pillResult;
  final DateTime scanTime;

  const PillInfoScreen({
    super.key,
    required this.pillResult,
    required this.scanTime,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💊 알약 정보'),
        backgroundColor: Colors.green.shade100,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: 공유 기능
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 메인 정보 카드
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 알약명
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.medication,
                              color: Colors.green.shade600,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'AI 인식 결과',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  pillResult.className,
                                  style: const TextStyle(
                                    fontSize: 22, // 더 큰 글씨
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // 신뢰도
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.analytics,
                              color: Colors.blue.shade600,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '인식 신뢰도',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(pillResult.confidence * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: pillResult.confidence > 0.8 
                                      ? Colors.green.shade700
                                      : pillResult.confidence > 0.6
                                        ? Colors.orange.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 인식 정보 카드
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.camera_alt,
                            color: Colors.grey.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '인식 정보',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // 클래스 인덱스
                      Row(
                        children: [
                          const Text(
                            '클래스 ID: ',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            '${pillResult.classIndex}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // 인식 시간
                      Row(
                        children: [
                          const Text(
                            '인식 시간: ',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            scanTime.toString().substring(0, 19),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 액션 버튼들 (더 큰 버튼)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showDetailSearchDialog(context);
                      },
                      icon: const Icon(Icons.search, size: 20),
                      label: const Text(
                        '상세 정보 검색',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.camera_alt, size: 20),
                      label: const Text(
                        '다시 촬영',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // 주의사항 (더 큰 글씨)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_outlined,
                      color: Colors.red.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI 인식 결과는 참고용입니다. 복용 전 반드시 의사나 약사와 상담하세요.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('상세 정보 검색'),
        content: Text('${pillResult.className}의 상세 정보를 검색하시겠습니까?\n\n(향후 LLM 연동 예정)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('상세 정보 검색 기능은 개발 중입니다.'),
                ),
              );
            },
            child: const Text('검색'),
          ),
        ],
      ),
    );
  }
}