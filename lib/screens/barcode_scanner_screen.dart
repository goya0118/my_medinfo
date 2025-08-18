import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/drug_api_service.dart';
import '../models/drug_info.dart';
// 위에서 만든 CameraManager를 import
import '../services/camera_manager.dart'; // 파일 경로에 맞게 수정하세요

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // CameraManager 사용
  final CameraManager _cameraManager = CameraManager();
  
  bool _isScanning = true;
  bool _isLoading = false;
  bool _cameraInitialized = false;
  String? _lastScannedBarcode;
  DateTime? _lastScanTime;
  DrugInfo? _drugInfo;
  String? _errorMessage;
  
  // 중복 스캔 방지 (3초 쿨다운)
  static const Duration _scanCooldown = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _initializeCamera(); // 수정된 초기화 함수 호출
  }

  @override
  void dispose() {
    _cameraManager.dispose(); // CameraManager의 dispose 사용
    super.dispose();
  }

  // 수정된 카메라 초기화 함수 (더 간단하게)
  Future<void> _initializeCamera() async {
    setState(() {
      _cameraInitialized = false;
      _errorMessage = null;
    });

    try {
      // 먼저 MobileScanner가 직접 처리하도록 시도
      final result = await _cameraManager.initializeCamera();
      
      if (!mounted) return;

      if (result.isSuccess) {
        // 성공
        setState(() {
          _cameraInitialized = true;
          _errorMessage = null;
        });
      } else {
        // 실패시 권한 상태 재확인
        final permissionStatus = await _cameraManager.checkPermissionStatus();
        print('실제 권한 상태: $permissionStatus');
        
        if (permissionStatus == PermissionStatus.permanentlyDenied) {
          setState(() {
            _errorMessage = '설정에서 카메라 권한을 허용해주세요';
          });
          _showSettingsDialog();
        } else if (permissionStatus == PermissionStatus.denied) {
          setState(() {
            _errorMessage = '카메라 권한이 필요합니다';
          });
          _showPermissionDialog();
        } else if (permissionStatus == PermissionStatus.granted || permissionStatus == PermissionStatus.limited) {
          // 권한은 있는데 카메라 초기화 실패
          setState(() {
            _errorMessage = result.getUserMessage();
          });
        } else {
          setState(() {
            _errorMessage = result.getUserMessage();
          });
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

  // 권한 요청 다이얼로그 (수정)
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카메라 권한 필요'),
        content: const Text('바코드 스캔을 위해 카메라 권한이 필요합니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // 권한 요청 후 다시 카메라 초기화
              final granted = await _cameraManager.requestPermission();
              if (granted) {
                _initializeCamera();
              } else {
                setState(() {
                  _errorMessage = '카메라 권한이 거부되었습니다';
                });
              }
            },
            child: const Text('권한 허용'),
          ),
        ],
      ),
    );
  }

  // 설정으로 이동 다이얼로그
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('권한 설정 필요'),
        content: const Text('설정에서 카메라 권한을 허용해주세요.\n\n설정 > 개인정보 보호 및 보안 > 카메라'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cameraManager.openAppSettings();
              // 설정에서 돌아온 후 카메라 재초기화
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  _initializeCamera();
                }
              });
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  void _onBarcodeDetect(BarcodeCapture capture) async {
    try {
      // 스캔 중지 상태면 무시
      if (!_isScanning || !mounted) return;

      // 바코드 데이터 안전하게 추출
      if (capture.barcodes.isEmpty) return;
      
      final barcode = capture.barcodes.first;
      final code = barcode.rawValue;
      
      if (code == null || code.isEmpty) return;

      // 중복 스캔 방지
      final now = DateTime.now();
      if (_lastScannedBarcode == code && 
          _lastScanTime != null && 
          now.difference(_lastScanTime!) < _scanCooldown) {
        return;
      }

      _lastScannedBarcode = code;
      _lastScanTime = now;

      print('바코드 스캔됨: $code');

      // 스캔 일시 중지
      if (mounted) {
        setState(() {
          _isScanning = false;
          _isLoading = true;
          _drugInfo = null;
          _errorMessage = null;
        });
      }

      // 의약품 정보 조회
      await _fetchDrugInfo(code);
      
    } catch (e) {
      print('바코드 감지 오류: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '바코드 처리 중 오류가 발생했습니다.';
        });
        
        // 오류 시에도 스캔 재시작
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isScanning = true;
            });
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
          Fluttertoast.showToast(
            msg: "의약품 정보를 찾았습니다!",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            backgroundColor: Colors.green,
            textColor: Colors.white,
          );
        } else {
          Fluttertoast.showToast(
            msg: "의약품 정보를 찾을 수 없습니다",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            backgroundColor: Colors.orange,
            textColor: Colors.white,
          );
        }

        // 3초 후 스캔 재시작
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _isScanning = true;
            });
          }
        });
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

        // 오류 시에도 스캔 재시작
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isScanning = true;
            });
          }
        });
      }
    }
  }

  void _toggleFlash() {
    _cameraManager.toggleFlash(); // CameraManager의 toggleFlash 사용
  }

  void _restartCamera() async {
    await _initializeCamera(); // 수정된 초기화 함수 사용
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
                      
                      // 스캔 가이드 (카메라가 초기화된 경우에만 표시)
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