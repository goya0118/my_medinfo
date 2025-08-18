import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 진동을 위한 HapticFeedback
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/drug_api_service.dart';
import '../models/drug_info.dart';
import '../services/camera_manager.dart';
import 'drug_info_screen.dart'; // 새로 만든 의약품 정보 화면
import '../services/medication_log_service.dart';

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
  
  // 진동 관련 변수 추가
  bool _isVibrating = false;
  
  static const Duration _scanCooldown = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _stopVibration(); // 진동 중지
    _cameraManager.dispose();
    super.dispose();
  }

  // 진동 관련 메서드들 추가
  void _startScanningVibration() {
    if (_isVibrating) return;
    
    _isVibrating = true;
    _vibrationLoop();
  }

  void _vibrationLoop() async {
    while (_isVibrating && _isScanning && mounted) {
      await Future.delayed(const Duration(milliseconds: 1000)); // 1.5초마다
      if (_isVibrating && _isScanning && mounted) {
        HapticFeedback.lightImpact(); // 약한 진동
      }
    }
  }

  void _stopVibration() {
    _isVibrating = false;
  }

  void _superSuccessVibration() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact(); // 연속 2번
  }

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
        // 카메라 초기화 성공 시 진동 시작
        _startScanningVibration();
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

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카메라 권한 필요'),
        content: const Text('바코드 스캔을 위해 카메라 권한이 필요합니다.\n\n설정 > 개인정보 보호 및 보안 > 카메라에서 이 앱의 권한을 허용해주세요.'),
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

  void _onBarcodeDetect(BarcodeCapture capture) async {
    try {
      if (!_isScanning || !mounted) return;

      if (capture.barcodes.isEmpty) return;
      
      final barcode = capture.barcodes.first;
      final code = barcode.rawValue;
      
      if (code == null || code.isEmpty) return;

      final now = DateTime.now();
      if (_lastScannedBarcode == code && 
          _lastScanTime != null && 
          now.difference(_lastScanTime!) < _scanCooldown) {
        return;
      }

      _lastScannedBarcode = code;
      _lastScanTime = now;

      print('바코드 스캔됨: $code');

      // 성공 진동
      _superSuccessVibration();
      _stopVibration(); // 스캔 중 진동 중지

      if (mounted) {
        setState(() {
          _isScanning = false;
          _isLoading = true;
          _drugInfo = null;
          _errorMessage = null;
        });
      }

      await _fetchDrugInfo(code);
      
    } catch (e) {
      print('바코드 감지 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '바코드 처리 중 오류가 발생했습니다.';
        });
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isScanning = true;
            });
            _startScanningVibration(); // 진동 재시작
          }
        });
      }
    }
  }

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
            if (mounted) {
              setState(() {
                _isScanning = true;
              });
              _startScanningVibration(); // 진동 재시작
            }
          });
        } else {
          Fluttertoast.showToast(
            msg: "의약품 정보를 찾을 수 없습니다",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
          
          // 정보를 찾지 못한 경우 3초 후 스캔 재시작
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _isScanning = true;
              });
              _startScanningVibration(); // 진동 재시작
            }
          });
        }
      }

    } catch (e) {
      print('API 호출 오류: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'API 호출 중 오류가 발생했습니다: ${e.toString()}';
        });
        
        Fluttertoast.showToast(
          msg: "API 호출 중 오류가 발생했습니다",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isScanning = true;
            });
            _startScanningVibration(); // 진동 재시작
          }
        });
      }
    }
  }

  void _toggleFlash() {
    _cameraManager.toggleFlash();
  }

  void _restartCamera() async {
    await _initializeCamera();
  }

  // 복용 기록 다이얼로그 (수량만 선택)
  void _showMedicationLogDialog() {
    if (_drugInfo == null || _lastScannedBarcode == null) return;

    int selectedQuantity = 1; // 기본 1정

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('복용 기록 추가'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '약품: ${_drugInfo!.itemName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('복용 수량:'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      if (selectedQuantity > 1) setState(() => selectedQuantity--);
                    },
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$selectedQuantity정', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => setState(() => selectedQuantity++),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await MedicationLogService.saveMedicationLog(
                  drugName: _drugInfo!.itemName,
                  takenAt: DateTime.now(),
                  quantity: selectedQuantity,
                );
                Navigator.of(context).pop();
                Fluttertoast.showToast(
                  msg: success ? '복용 기록이 저장되었습니다!' : '복용 기록 저장에 실패했습니다',
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.CENTER,
                  backgroundColor: success ? Colors.green : Colors.red,
                  textColor: Colors.white,
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('저장', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏥 의약품 바코드 스캐너'),
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
            // 카메라 스캐너
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      // 카메라 뷰
                      if (_cameraManager.controller != null && _cameraInitialized)
                        MobileScanner(
                          controller: _cameraManager.controller!,
                          onDetect: _onBarcodeDetect,
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
                                      style: const TextStyle(color: Colors.red),
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
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _restartCamera,
                                  child: const Text('카메라 재시작'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // 스캔 가이드
                      if (_cameraInitialized)
                        Center(
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _isScanning ? Colors.green : Colors.orange,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
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
                                    fontSize: 16,
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
            
            // 상태 및 결과 표시
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 상태 메시지
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
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
                                      ? '🔍 바코드를 스캔 영역에 맞춰주세요'
                                      : _isLoading
                                          ? '⏳ 의약품 정보를 조회하는 중...'
                                          : '✅ 스캔 완료! 3초 후 다시 스캔됩니다')
                                  : '📷 카메라를 초기화하는 중입니다...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _errorMessage != null 
                                ? Colors.red.shade700
                                : _isScanning ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // 의약품 정보 표시
                      if (_drugInfo != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '🏥 의약품 정보',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              Text(
                                '📋 바코드: ${_lastScannedBarcode ?? ""}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              Text(
                                _drugInfo!.itemName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              
                              if (_drugInfo!.company.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '제조사: ${_drugInfo!.company}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                              
                              const SizedBox(height: 8),
                              Text(
                                '조회 시간: ${DateTime.now().toString().substring(11, 19)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // 복용 기록 버튼
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showMedicationLogDialog(),
                                  icon: const Icon(Icons.add_circle_outline),
                                  label: const Text(
                                    '복용 기록 추가',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (!_isLoading && _errorMessage == null) ...[
                        const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.qr_code_scanner,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                '바코드를 스캔하여\n의약품 정보를 확인하세요',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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