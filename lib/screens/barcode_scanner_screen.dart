import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../services/drug_api_service.dart';
import '../models/drug_info.dart';
import '../services/camera_manager.dart';
import 'ai_chat_screen.dart'; // 👈 AI 채팅 화면으로 이동하기 위해 import

// PillInfoScreen과 PillClassificationResult가 이 파일에 정의되어 있지 않다면,
// 관련 코드를 포함한 파일(예: pill_info_screen.dart)을 import 해야 합니다.
// 만약 알약 인식 기능이 없다면 PillInfoScreen 관련 코드는 삭제해도 됩니다.

class BarcodeScannerScreen extends StatefulWidget {
  // 👈 'const'가 없어야 합니다.
  BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final CameraManager _cameraManager = CameraManager();

  bool _isScanning = true;
  bool _isLoading = false;
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

  void _successVibration() {
    HapticFeedback.heavyImpact();
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      await _cameraManager.initializeCamera();
      if (!mounted) return;
      
      setState(() {});
      _startScanningVibration();
      _cameraManager.startDetection(onBarcodeDetected: _onBarcodeDetected);

    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '카메라 초기화 중 오류: $e';
        });
      }
    }
  }

  void _onBarcodeDetected(String barcode) async {
    if (!_isScanning || !mounted || barcode.isEmpty) return;

    final now = DateTime.now();
    if (_lastScannedBarcode == barcode && 
        _lastScanTime != null && 
        now.difference(_lastScanTime!) < _scanCooldown) {
      return;
    }

    _lastScannedBarcode = barcode;
    _lastScanTime = now;

    _successVibration();
    _stopVibration();
    _cameraManager.stopDetection();

    if (mounted) {
      setState(() {
        _isScanning = false;
        _isLoading = true;
        _drugInfo = null;
        _errorMessage = null;
      });
    }
    await _fetchDrugInfo(barcode);
  }
  
  Future<void> _fetchDrugInfo(String barcode) async {
    try {
      final drugInfo = await DrugApiService.getDrugInfo(barcode);
      
      if (mounted) {
        setState(() {
          _drugInfo = drugInfo;
          _isLoading = false;
        });

        if (drugInfo != null) {
          // ✅ 스캔 성공 시 AiChatScreen으로 이동
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AiChatScreen(drugInfo: drugInfo),
            ),
          ).then((_) {
            _restartScanning();
          });
        } else {
          Fluttertoast.showToast(msg: "의약품 정보를 찾을 수 없습니다");
          _restartScanning();
        }
      }
    } catch (e) {
      _handleError('API 호출 중 오류: ${e.toString()}');
    }
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
      Fluttertoast.showToast(msg: message);
      _restartScanning();
    }
  }

  void _restartScanning() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isScanning = true;
        });
        _startScanningVibration();
        _cameraManager.startDetection(onBarcodeDetected: _onBarcodeDetected);
      }
    });
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
        title: const Text('의약품 스캐너'),
        actions: [
          IconButton(onPressed: _toggleFlash, icon: const Icon(Icons.flash_on)),
          IconButton(onPressed: _restartCamera, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (_cameraManager.isInitialized)
              CameraPreview(_cameraManager.cameraController!)
            else
              Center(child: Text(_errorMessage ?? '카메라 초기화 중...')),
            
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SpinKitFadingCircle(color: Colors.white, size: 50.0),
                      SizedBox(height: 16),
                      Text('의약품 정보 조회 중...', style: TextStyle(color: Colors.white, fontSize: 18)),
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