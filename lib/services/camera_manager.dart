import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;

class CameraManager {
  // Camera 컨트롤러
  CameraController? _cameraController;
  
  // ML Kit 바코드 스캐너 (동적 생성)
  BarcodeScanner? _barcodeScanner;
  
  /// ML Kit 바코드 스캐너 초기화 (null 안전성 강화)
  void _initializeBarcodeScanner() {
    try {
      _barcodeScanner?.close(); // 기존 것 정리
      
      // 기본 바코드 스캐너 생성 (모든 포맷 지원)
      _barcodeScanner = BarcodeScanner();
      print('✅ 새로운 바코드 스캐너 생성');
    } catch (e) {
      print('⚠️ 바코드 스캐너 초기화 오류: $e');
      // 재시도 (동기 방식)
      try {
        _barcodeScanner = BarcodeScanner();
        print('✅ 바코드 스캐너 재시도 성공');
      } catch (e2) {
        print('❌ 바코드 스캐너 재시도도 실패: $e2');
        _barcodeScanner = null;
      }
    }
  }
  
  // TensorFlow Lite 모델
  Interpreter? _pillModel;
  List<String>? _labels;
  Map<String, dynamic>? _modelInfo;
  
  // 인식 상태
  bool _isPillDetectionActive = false;
  bool _isBarcodeDetectionActive = false;
  bool _isPillDetectionRunning = false;
  bool _isBarcodeDetectionRunning = false;
  bool _isImageStreamActive = false;
  
  // 콜백
  Function(String)? _onBarcodeDetected;
  Function(PillClassificationResult?)? _onPillDetected;
  
  // 마지막 처리 시간 (중복 방지)
  DateTime? _lastPillDetectionTime;
  DateTime? _lastBarcodeDetectionTime;
  
  // 중복 인식 방지
  String? _lastDetectedBarcode;
  DateTime? _lastBarcodeSuccessTime;
  
  // 화면 전환 추적
  bool _isNavigatingAway = false;
  DateTime? _lastNavigationTime;
  
  // 위젯 생명주기 추적 (중요!)
  bool _isWidgetActive = false;
  String? _currentWidgetId;
  
  // 성능 최적화 설정
  static const int _barcodeDetectionInterval = 500; // 0.5초
  static const int _pillDetectionInterval = 2000;   // 2초
  static const int _barcodeSkipDuration = 5000;     // 5초간 같은 바코드 스킵 (늘림)
  static const int _navigationCooldown = 3000;     // 화면 전환 후 3초 쿨다운 (늘림)
  
  bool get isInitialized => _cameraController?.value.isInitialized == true;
  CameraController? get cameraController => _cameraController;

  /// 통합 카메라 초기화
  Future<CameraInitResult> initializeCamera() async {
    try {
      print('🔍 Camera + ML Kit 통합 카메라 초기화 시작');
      
      // 기존 정리
      await dispose();
      
      // 1. TensorFlow Lite 모델 로드 (알약 인식용)
      await _loadTensorFlowLiteModel();
      
      // 2. Camera 초기화
      await _initializeCamera();
      
      // 3. ML Kit 바코드 스캐너 초기화
      _initializeBarcodeScanner();
      
      print('✅ 통합 카메라 초기화 완료');
      return CameraInitResult.success();
      
    } catch (e) {
      print('❌ 카메라 초기화 실패: $e');
      await dispose();
      
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('permission') || 
          errorStr.contains('denied') ||
          errorStr.contains('access')) {
        return CameraInitResult.permissionDenied();
      }
      
      return CameraInitResult.error('카메라 초기화 실패: $e');
    }
  }

  /// Camera 초기화
  Future<void> _initializeCamera() async {
    print('📷 Camera 초기화');
    
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw Exception('사용 가능한 카메라가 없습니다');
    }
    
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    
    // Android에서 ML Kit 호환성을 위해 NV21 포맷 사용
    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21, // Android: NV21, iOS: YUV420 자동 선택
    );
    
    await _cameraController!.initialize();
    
    // 초기화 후 잠깐 대기
    await Future.delayed(Duration(milliseconds: 500));
    
    print('✅ Camera 초기화 완료 (해상도: ${_cameraController!.value.previewSize})');
  }

  /// TensorFlow Lite 모델 로드
  Future<void> _loadTensorFlowLiteModel() async {
    try {
      print('🤖 TensorFlow Lite 모델 로딩');
      
      _pillModel = await Interpreter.fromAsset('assets/models/pill_classifier_mobile.tflite');
      print('✅ TensorFlow Lite 모델 로드 완료');
      
      final modelInfoString = await rootBundle.loadString('assets/models/model_info.json');
      _modelInfo = json.decode(modelInfoString);
      print('✅ 모델 정보 로드 완료');
      
      final labelsString = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelsString.trim().split('\n');
      print('✅ 라벨 로드 완료: ${_labels!.length}개 클래스');
      
    } catch (e) {
      print('❌ TensorFlow Lite 모델 로드 실패: $e');
      throw e;
    }
  }

  /// 통합 인식 시작 (바코드 + 알약)
  void startDetection({
    Function(String)? onBarcodeDetected,
    Function(PillClassificationResult?)? onPillDetected,
    bool enableVibration = true,
    bool clearPreviousResults = true, // 이전 결과 초기화 옵션
    String? widgetId, // 위젯 식별자 추가
  }) {
    _onBarcodeDetected = onBarcodeDetected;
    _onPillDetected = onPillDetected;
    
    // 위젯 활성화 및 식별자 설정
    _isWidgetActive = true;
    _currentWidgetId = widgetId ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('⚠️ 카메라가 초기화되지 않음');
      return;
    }

    print('🔄 통합 인식 시작 (바코드: ${onBarcodeDetected != null}, 알약: ${onPillDetected != null})');
    print('🆔 위젯 ID: $_currentWidgetId');
    
    _isBarcodeDetectionActive = onBarcodeDetected != null;
    _isPillDetectionActive = onPillDetected != null;
    _lastPillDetectionTime = null;
    _lastBarcodeDetectionTime = null;
    
    // 화면 전환 상태 초기화
    _isNavigatingAway = false;
    _lastNavigationTime = null;
    
    // 이전 결과 강제 초기화 (중요!)
    if (clearPreviousResults) {
      _lastDetectedBarcode = null;
      _lastBarcodeSuccessTime = null;
      print('🧹 이전 바코드 인식 결과 강제 초기화 (위젯: $_currentWidgetId)');
    }
    
    // 바코드 스캐너 재확인
    if (_isBarcodeDetectionActive && _barcodeScanner == null) {
      print('⚠️ 바코드 스캐너가 null, 재초기화 시도');
      _initializeBarcodeScanner();
    }
    
    // 이미지 스트림 시작
    _startImageStream();
    
    // Android에서 진동 테스트
    if (enableVibration) {
      _testVibration();
    }
  }

  /// 진동 테스트 (Android 호환성 확인)
  Future<void> _testVibration() async {
    try {
      print('📳 진동 테스트 시작');
      await HapticFeedback.lightImpact();
      print('✅ 진동 테스트 성공');
    } catch (e) {
      print('❌ 진동 테스트 실패: $e');
      // Android에서 다른 진동 방식 시도
      try {
        await HapticFeedback.vibrate();
        print('✅ 대안 진동 방식 성공');
      } catch (e2) {
        print('❌ 모든 진동 방식 실패: $e2');
      }
    }
  }

  /// 이미지 스트림 시작 (플랫폼별 최적화)
  void _startImageStream() {
    if (_isImageStreamActive) return;
    
    print('📸 이미지 스트림 시작');
    _isImageStreamActive = true;
    
    // 스트림 시작 전 충분한 대기 (이전 프레임 완전 클리어)
    Future.delayed(Duration(milliseconds: 800), () {
      if (!_isImageStreamActive) return; // 중간에 중지되었으면 리턴
      
      print('📸 실제 이미지 스트림 시작');
      _cameraController!.startImageStream((CameraImage image) async {
        if (!_isImageStreamActive || _isNavigatingAway) return;
        
        // 백그라운드에서 처리 (UI 블로킹 방지)
        Future.microtask(() async {
          await _processImage(image);
        });
      });
    });
  }

  /// 이미지 처리 (바코드 + 알약) - 최적화된 타이밍
  Future<void> _processImage(CameraImage cameraImage) async {
    try {
      // 화면 전환 중이면 모든 처리 중단
      if (_isNavigatingAway) {
        return;
      }
      
      final now = DateTime.now();
      
      // 1. 바코드 인식 (0.5초 간격, 중복 스킵)
      if (_isBarcodeDetectionActive && !_isBarcodeDetectionRunning) {
        if (_lastBarcodeDetectionTime == null || 
            now.difference(_lastBarcodeDetectionTime!).inMilliseconds >= _barcodeDetectionInterval) {
          _lastBarcodeDetectionTime = now;
          
          // 백그라운드에서 비동기 처리 (UI 끊김 방지)
          _detectBarcodeAsync(cameraImage);
        }
      }
      
      // 2. 알약 인식 (2초 간격)
      if (_isPillDetectionActive && !_isPillDetectionRunning) {
        if (_lastPillDetectionTime == null || 
            now.difference(_lastPillDetectionTime!).inMilliseconds >= _pillDetectionInterval) {
          _lastPillDetectionTime = now;
          
          // 백그라운드에서 비동기 처리 (UI 끊김 방지)
          _detectPillAsync(cameraImage);
        }
      }
      
    } catch (e) {
      print('❌ 이미지 처리 오류: $e');
      // 화면 전환 중 오류는 무시
      if (_isNavigatingAway) {
        print('🚫 화면 전환 중 이미지 처리 오류 발생, 무시');
      }
    }
  }

  /// 비동기 바코드 인식 (UI 블로킹 방지)
  void _detectBarcodeAsync(CameraImage cameraImage) {
    if (_isBarcodeDetectionRunning || _isNavigatingAway) return;
    
    // 별도 isolate에서 처리
    Future.microtask(() async {
      if (!_isNavigatingAway) { // 한 번 더 체크
        await _detectBarcode(cameraImage);
      }
    });
  }

  /// 비동기 알약 인식 (UI 블로킹 방지)
  void _detectPillAsync(CameraImage cameraImage) {
    if (_isPillDetectionRunning || _isNavigatingAway) return;
    
    // 별도 isolate에서 처리
    Future.microtask(() async {
      if (!_isNavigatingAway) { // 한 번 더 체크
        await _detectPill(cameraImage);
      }
    });
  }

  /// ML Kit 바코드 인식 (null 체크 강화된 버전)
  Future<void> _detectBarcode(CameraImage cameraImage) async {
    if (_isBarcodeDetectionRunning) return;
    
    _isBarcodeDetectionRunning = true;
    
    try {
      final now = DateTime.now();
      
      // 위젯이 비활성화되었으면 즉시 종료
      if (!_isWidgetActive) {
        print('🚫 위젯 비활성화 상태, 바코드 인식 중단');
        return;
      }
      
      // 화면 전환 중이면 즉시 종료
      if (_isNavigatingAway) {
        print('🚫 화면 전환 중이므로 바코드 인식 완전 중단');
        return;
      }
      
      // 바코드 스캐너 null 체크 (중요!)
      if (_barcodeScanner == null) {
        print('❌ 바코드 스캐너가 null입니다. 재초기화 시도...');
        _initializeBarcodeScanner();
        if (_barcodeScanner == null) {
          print('❌ 바코드 스캐너 재초기화 실패');
          return;
        }
      }
      
      // 네비게이션 쿨다운 체크 (강화)
      if (_lastNavigationTime != null) {
        final timeSinceNavigation = now.difference(_lastNavigationTime!).inMilliseconds;
        if (timeSinceNavigation < _navigationCooldown) {
          print('🚫 네비게이션 쿨다운 중 (${timeSinceNavigation}ms/${_navigationCooldown}ms)');
          return;
        }
      }
      
      // 강화된 중복 바코드 스킵 로직
      if (_lastDetectedBarcode != null && _lastBarcodeSuccessTime != null) {
        final timeSinceLastDetection = now.difference(_lastBarcodeSuccessTime!).inMilliseconds;
        if (timeSinceLastDetection < _barcodeSkipDuration) {
          print('🚫 중복 바코드 스킵 (${timeSinceLastDetection}ms/${_barcodeSkipDuration}ms)');
          return;
        }
      }
      
      // 이미지 크기 줄여서 처리 속도 향상
      final inputImage = _createOptimizedInputImageSafe(cameraImage);
      if (inputImage == null) {
        print('❌ 최적화된 InputImage 생성 실패');
        return;
      }
      
      // 다시 한 번 상태 체크 (중요!)
      if (_isNavigatingAway || !_isWidgetActive) {
        print('🚫 InputImage 생성 후 상태 변경 감지, 중단');
        return;
      }
      
      print('📷 바코드 스캔 실행 중... (위젯: $_currentWidgetId)');
      
      // ML Kit 바코드 스캔 - null 체크 강화
      List<Barcode>? barcodes;
      try {
        barcodes = await _barcodeScanner!.processImage(inputImage);
      } catch (e) {
        print('❌ ML Kit 바코드 처리 오류: $e');
        // 스캐너 재초기화 시도
        print('🔄 바코드 스캐너 재초기화 시도...');
        _initializeBarcodeScanner();
        return;
      }
      
      // ML Kit 처리 후에도 상태 재확인
      if (_isNavigatingAway || !_isWidgetActive) {
        print('🚫 바코드 스캔 완료 후 상태 변경 감지, 결과 무시');
        return;
      }
      
      if (barcodes == null) {
        print('❌ 바코드 스캔 결과가 null');
        return;
      }
      
      print('📦 감지된 바코드 수: ${barcodes.length}');
      
      if (barcodes.isNotEmpty && _onBarcodeDetected != null) {
        final barcode = barcodes.first;
        if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
          // 강화된 중복 체크
          if (_lastDetectedBarcode == barcode.rawValue) {
            final timeSinceLastSuccess = now.difference(_lastBarcodeSuccessTime ?? DateTime(2000)).inMilliseconds;
            if (timeSinceLastSuccess < _barcodeSkipDuration) {
              print('🔄 동일한 바코드 감지, 스킵: ${barcode.rawValue} (${timeSinceLastSuccess}ms 전 인식)');
              return;
            }
          }
          
          // 최종 상태 체크 (콜백 호출 직전)
          if (_isNavigatingAway || !_isWidgetActive) {
            print('🚫 콜백 호출 직전 상태 변경 감지, 무시');
            return;
          }
          
          print('📦 새로운 바코드 감지: ${barcode.rawValue} (위젯: $_currentWidgetId)');
          
          // 즉시 모든 인식 차단 (추론 프로세스 포함)
          _emergencyStopAllDetection();
          
          // 성공 정보 저장
          _lastDetectedBarcode = barcode.rawValue;
          _lastBarcodeSuccessTime = now;
          
          // 성공 진동 실행
          await _vibrateSuccess();
          
          print('🚀 바코드 콜백 호출: ${barcode.rawValue}');
          _onBarcodeDetected!(barcode.rawValue!);
        }
      }
      
    } catch (e) {
      print('❌ 바코드 인식 오류: $e');
      print('❌ 오류 스택트레이스: ${StackTrace.current}');
      
      // 오류 발생 시에도 상태 체크
      if (_isNavigatingAway || !_isWidgetActive) {
        print('🚫 비활성 상태에서 오류 발생, 무시');
        return;
      }
      
      // 바코드 스캐너 재초기화 시도
      print('🔄 오류 복구를 위한 바코드 스캐너 재초기화...');
      _initializeBarcodeScanner();
      
    } finally {
      _isBarcodeDetectionRunning = false;
    }
  }

  /// 긴급 모든 인식 중단 (바코드 인식 성공 시 즉시 호출)
  void _emergencyStopAllDetection() {
    print('🚨 긴급 모든 인식 및 추론 중단 (위젯: $_currentWidgetId)');
    
    // 즉시 모든 상태 차단
    _isNavigatingAway = true;
    _isWidgetActive = false; // 위젯도 비활성화
    _lastNavigationTime = DateTime.now();
    _isPillDetectionActive = false;
    _isBarcodeDetectionActive = false;
    _isPillDetectionRunning = false;
    _isBarcodeDetectionRunning = false;
    
    // 이미지 스트림도 즉시 중단
    if (_isImageStreamActive) {
      _isImageStreamActive = false;
      try {
        _cameraController?.stopImageStream();
        print('✅ 긴급 이미지 스트림 중단 완료');
      } catch (e) {
        print('⚠️ 긴급 이미지 스트림 중단 오류: $e');
      }
    }
    
    print('✅ 모든 추론 프로세스 긴급 중단 완료');
  }

  /// 안전한 최적화된 InputImage 생성 (null 체크 강화)
  InputImage? _createOptimizedInputImageSafe(CameraImage cameraImage) {
    try {
      // 카메라 컨트롤러 null 체크
      if (_cameraController == null) {
        print('❌ 카메라 컨트롤러가 null');
        return null;
      }
      
      // 원본 이미지가 너무 크면 다운샘플링
      final originalWidth = cameraImage.width;
      final originalHeight = cameraImage.height;
      
      print('📐 원본 크기: ${originalWidth}x${originalHeight}');
      
      // 바코드 인식에는 480p 정도면 충분
      const int maxWidth = 640;
      const int maxHeight = 480;
      
      if (originalWidth <= maxWidth && originalHeight <= maxHeight) {
        // 원본 크기가 작으면 그대로 사용
        return _cameraImageToInputImageSafe(cameraImage);
      }
      
      // 다운샘플링이 필요한 경우 (여기서는 단순히 원본 사용)
      // 실제 구현에서는 이미지 리사이즈 로직 추가 가능
      print('📐 원본 크기 사용: ${originalWidth}x${originalHeight}');
      
      return _cameraImageToInputImageSafe(cameraImage);
      
    } catch (e) {
      print('❌ 안전한 최적화된 InputImage 생성 실패: $e');
      return null;
    }
  }

  /// 안전한 CameraImage를 InputImage로 변환 (null 체크 강화)
  InputImage? _cameraImageToInputImageSafe(CameraImage cameraImage) {
    try {
      // CameraImage 유효성 검사
      if (cameraImage.planes.isEmpty) {
        print('❌ CameraImage planes가 비어있음');
        return null;
      }
      
      // 카메라 컨트롤러 null 체크
      if (_cameraController == null) {
        print('❌ 카메라 컨트롤러가 null (InputImage 변환)');
        return null;
      }
      
      // CameraImage 메타데이터 설정
      final camera = _cameraController!.description;
      
      // 회전 각도 계산
      final sensorOrientation = camera.sensorOrientation;
      InputImageRotation? rotation;
      
      switch (sensorOrientation) {
        case 0:
          rotation = InputImageRotation.rotation0deg;
          break;
        case 90:
          rotation = InputImageRotation.rotation90deg;
          break;
        case 180:
          rotation = InputImageRotation.rotation180deg;
          break;
        case 270:
          rotation = InputImageRotation.rotation270deg;
          break;
        default:
          rotation = InputImageRotation.rotation0deg;
      }
      
      // InputImageFormat 설정 - null 체크 추가
      final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw);
      if (format == null) {
        print('❌ InputImageFormat이 null: ${cameraImage.format.raw}');
        return null;
      }
      
      // 첫 번째 plane null 체크
      if (cameraImage.planes.first.bytes.isEmpty) {
        print('❌ CameraImage bytes가 비어있음');
        return null;
      }
      
      // InputImageMetadata 생성
      final inputImageData = InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: cameraImage.planes.first.bytesPerRow,
      );
      
      // 모든 plane의 bytes 결합 - null 체크 강화
      final allBytes = WriteBuffer();
      for (final plane in cameraImage.planes) {
        if (plane.bytes.isNotEmpty) {
          allBytes.putUint8List(plane.bytes);
        }
      }
      
      final bytes = allBytes.done().buffer.asUint8List();
      if (bytes.isEmpty) {
        print('❌ 결합된 bytes가 비어있음');
        return null;
      }
      
      return InputImage.fromBytes(
        bytes: bytes,
        metadata: inputImageData,
      );
      
    } catch (e) {
      print('❌ 안전한 InputImage 변환 실패: $e');
      print('❌ 변환 오류 스택트레이스: ${StackTrace.current}');
      return null;
    }
  }

  /// 성공 진동 (Android 호환성 개선)
  Future<void> _vibrateSuccess() async {
    try {
      // 먼저 HapticFeedback 시도
      await HapticFeedback.heavyImpact();
      await Future.delayed(Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
      print('✅ HapticFeedback 성공 진동 완료');
    } catch (e) {
      print('⚠️ HapticFeedback 실패, 대안 진동 시도: $e');
      try {
        // 대안: 기본 진동
        await HapticFeedback.vibrate();
        await Future.delayed(Duration(milliseconds: 200));
        await HapticFeedback.vibrate();
        print('✅ 대안 진동 완료');
      } catch (e2) {
        print('❌ 모든 진동 방식 실패: $e2');
      }
    }
  }

  /// TensorFlow Lite 알약 인식 (최적화된 버전)
  Future<void> _detectPill(CameraImage cameraImage) async {
    if (_isPillDetectionRunning || _pillModel == null) return;
    
    // 화면 전환 중이면 즉시 종료
    if (_isNavigatingAway) {
      print('🚫 화면 전환 중이므로 알약 인식 완전 중단');
      return;
    }
    
    _isPillDetectionRunning = true;
    
    try {
      print('🔍 알약 인식 시작 (최적화됨)');
      
      // 전처리 중에도 화면 전환 상태 체크
      if (_isNavigatingAway) {
        print('🚫 전처리 시작 전 화면 전환 감지, 중단');
        return;
      }
      
      // 더 작은 이미지로 전처리 (속도 향상)
      final inputData = await _preprocessCameraImageOptimized(cameraImage);
      
      // 전처리 후에도 화면 전환 상태 체크
      if (_isNavigatingAway) {
        print('🚫 전처리 완료 후 화면 전환 감지, 중단');
        return;
      }
      
      if (inputData != null) {
        print('✅ 최적화된 전처리 완료, TensorFlow Lite 추론 시작');
        
        try {
          // 추론 시작 전 마지막 체크
          if (_isNavigatingAway) {
            print('🚫 TensorFlow Lite 추론 시작 전 화면 전환 감지, 중단');
            return;
          }
          
          // TensorFlow Lite 추론
          final outputData = await _runTFLiteInference(inputData);
          
          // 추론 완료 후에도 화면 전환 상태 체크
          if (_isNavigatingAway) {
            print('🚫 TensorFlow Lite 추론 완료 후 화면 전환 감지, 결과 무시');
            return;
          }
          
          if (outputData != null) {
            final result = _processPredictionSafe(outputData);
            
            // 결과 처리 후에도 화면 전환 상태 체크
            if (_isNavigatingAway) {
              print('🚫 결과 처리 후 화면 전환 감지, 콜백 무시');
              return;
            }
            
            if (result != null && _onPillDetected != null) {
              print('🎯 알약 인식 성공: ${result.className} (${(result.confidence * 100).toStringAsFixed(1)}%)');
              _onPillDetected!(result);
            } else {
              print('📉 신뢰도 부족 또는 인식 실패');
            }
          } else {
            print('❌ TensorFlow Lite 추론 결과가 null');
          }
          
        } catch (tfliteError) {
          print('❌ TensorFlow Lite 추론 오류: $tfliteError');
          // 오류 시에도 화면 전환 상태면 무시
          if (_isNavigatingAway) {
            print('🚫 화면 전환 중 추론 오류 발생, 무시');
            return;
          }
        }
        
      } else {
        print('❌ 최적화된 전처리 실패');
      }
      
    } catch (e) {
      print('❌ 알약 인식 전체 오류: $e');
      // 화면 전환 중 오류는 무시
      if (_isNavigatingAway) {
        print('🚫 화면 전환 중 전체 오류 발생, 무시');
        return;
      }
    } finally {
      _isPillDetectionRunning = false;
    }
  }

  /// 최적화된 CameraImage 전처리 (더 빠른 처리)
  Future<Float32List?> _preprocessCameraImageOptimized(CameraImage cameraImage) async {
    try {
      // 모델 정보 확인
      final targetWidth = _modelInfo!['input_width'] as int? ?? 224;
      final targetHeight = _modelInfo!['input_height'] as int? ?? 224;
      
      // 작은 타겟 크기로 설정 (속도 향상)
      final optimizedWidth = math.min(targetWidth, 224);
      final optimizedHeight = math.min(targetHeight, 224);
      
      print('🔍 최적화된 전처리 시작 - 타겟: ${optimizedWidth}x${optimizedHeight}');
      
      // Y 채널만 사용 (더 빠른 처리)
      final yBytes = cameraImage.planes[0].bytes;
      
      // 최적화된 Float32List 생성
      final inputData = _convertToFloat32ListOptimized(
        yBytes, 
        cameraImage.width, 
        cameraImage.height, 
        optimizedWidth, 
        optimizedHeight,
      );
      
      print('✅ 최적화된 전처리 완료 - 크기: ${inputData.length}');
      return inputData;
      
    } catch (e) {
      print('❌ 최적화된 전처리 실패: $e');
      return null;
    }
  }

  /// 최적화된 Float32List 변환 (더 빠른 처리)
  Float32List _convertToFloat32ListOptimized(
    Uint8List yData,
    int originalWidth,
    int originalHeight,
    int targetWidth,
    int targetHeight,
  ) {
    // ImageNet 정규화 값 (기본값 사용으로 속도 향상)
    final mean = [0.485, 0.456, 0.406];
    final std = [0.229, 0.224, 0.225];
    
    // Float32List 생성
    final inputData = Float32List(targetWidth * targetHeight * 3);
    
    final scaleX = originalWidth / targetWidth;
    final scaleY = originalHeight / targetHeight;
    
    int index = 0;
    
    // 간소화된 리샘플링 (속도 우선)
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < targetHeight; y += 2) { // 2픽셀씩 건너뛰어 속도 향상
        for (int x = 0; x < targetWidth; x += 2) {
          final sourceX = (x * scaleX).toInt().clamp(0, originalWidth - 1);
          final sourceY = (y * scaleY).toInt().clamp(0, originalHeight - 1);
          final sourceIndex = sourceY * originalWidth + sourceX;
          
          // 빠른 정규화
          double normalizedValue = -1.0; // 기본값
          if (sourceIndex < yData.length) {
            final pixelValue = yData[sourceIndex];
            normalizedValue = (pixelValue / 255.0 - mean[c]) / std[c];
          }
          
          // 4개 픽셀에 같은 값 적용 (속도 향상)
          if (index < inputData.length) inputData[index++] = normalizedValue;
          if (index < inputData.length) inputData[index++] = normalizedValue;
        }
      }
    }
    
    // 나머지 공간 채우기
    while (index < inputData.length) {
      inputData[index++] = -1.0;
    }
    
    return inputData;
  }

  /// TensorFlow Lite 추론 실행
  Future<List<double>?> _runTFLiteInference(Float32List inputData) async {
    try {
      // 입력 텐서 모양 가져오기
      final inputTensor = _pillModel!.getInputTensors().first;
      final outputTensor = _pillModel!.getOutputTensors().first;
      
      print('📊 입력 텐서 모양: ${inputTensor.shape}');
      print('📊 출력 텐서 모양: ${outputTensor.shape}');
      
      // 입력 데이터를 올바른 모양으로 변환
      final inputShape = inputTensor.shape;
      final reshapedInput = inputData.reshape(inputShape);
      
      // 출력 버퍼 준비
      final outputShape = outputTensor.shape;
      final List<List<double>> outputData = List.generate(
        outputShape[0], // 배치 크기 (보통 1)
        (i) => List.filled(outputShape[1], 0.0) // 클래스 수
      );
      
      // 추론 실행
      _pillModel!.run(reshapedInput, outputData);
      
      print('📊 추론 결과 크기: ${outputData[0].length}');
      print('📊 추론 결과 샘플: ${outputData[0].take(5).toList()}');
      
      // 첫 번째 배치의 결과 반환
      return outputData[0];
      
    } catch (e) {
      print('❌ TensorFlow Lite 추론 실행 실패: $e');
      return null;
    }
  }

  /// 안전한 예측 결과 처리 (Softmax + 엄격한 임계값)
  PillClassificationResult? _processPredictionSafe(List<double> prediction) {
    try {
      print('🔍 예측 결과 처리 시작 - 타입: ${prediction.runtimeType}');
      
      print('📊 Raw logits: ${prediction.take(5).toList()}...'); // 처음 5개만 출력
      
      if (prediction.isNotEmpty) {
        // Softmax 적용하여 확률로 변환
        final probabilities = _applySoftmax(prediction);
        print('📊 Softmax 적용 후: ${probabilities.take(5).toList()}...'); // 처음 5개만 출력
        
        final maxIndex = _getMaxIndex(probabilities);
        final confidence = probabilities[maxIndex];
        
        print('📊 최고 신뢰도: ${(confidence * 100).toStringAsFixed(1)}% (인덱스: $maxIndex)');
        
        // 상위 2개 클래스 간 차이 확인 (추가 안전장치)
        final sortedProbs = [...probabilities]..sort((a, b) => b.compareTo(a));
        final confidenceDiff = sortedProbs[0] - sortedProbs[1];
        print('📊 1위-2위 차이: ${(confidenceDiff * 100).toStringAsFixed(1)}%');
        
        // 엄격한 임계값: 90% 이상 + 1위와 2위 차이 20% 이상
        if (confidence > 0.9 && confidenceDiff > 0.2 && maxIndex < _labels!.length) {
          print('✅ 임계값 통과 - 알약 인식 확정');
          return PillClassificationResult(
            className: _labels![maxIndex],
            confidence: confidence,
            classIndex: maxIndex,
          );
        } else {
          print('❌ 임계값 미달 - 신뢰도: ${(confidence * 100).toStringAsFixed(1)}%, 차이: ${(confidenceDiff * 100).toStringAsFixed(1)}%');
        }
      } else {
        print('❌ prediction 배열이 비어있음');
      }
      
    } catch (e) {
      print('❌ 예측 결과 처리 실패: $e');
      print('❌ 처리 오류 타입: ${e.runtimeType}');
    }
    
    return null;
  }

  /// Softmax 함수 (안정성을 위해 최대값 빼기)
  List<double> _applySoftmax(List<double> logits) {
    if (logits.isEmpty) return [];
    
    // 수치 안정성을 위해 최대값 빼기
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final expValues = logits.map((x) => math.exp(x - maxLogit)).toList();
    final sumExp = expValues.fold(0.0, (a, b) => a + b); // reduce 대신 fold 사용
    
    // 0으로 나누기 방지
    if (sumExp == 0.0 || sumExp.isNaN || sumExp.isInfinite) {
      return List.filled(logits.length, 1.0 / logits.length);
    }
    
    // 안전한 나누기 연산
    return expValues.map((x) {
      final result = x / sumExp;
      return result.isNaN || result.isInfinite ? 0.0 : result;
    }).toList();
  }

  /// CameraImage 전처리 (Float32List 출력)
  Future<Float32List?> _preprocessCameraImage(CameraImage cameraImage) async {
    try {
      print('🔍 전처리 시작 - 이미지 크기: ${cameraImage.width}x${cameraImage.height}');
      
      final int width = cameraImage.width;
      final int height = cameraImage.height;
      
      // 모델 정보 확인
      final targetWidth = _modelInfo!['input_width'] as int;
      final targetHeight = _modelInfo!['input_height'] as int;
      
      print('🎯 타겟 크기: ${targetWidth}x${targetHeight}');
      
      // Y 채널(밝기)만 사용해서 Float32List로 변환
      final yBytes = cameraImage.planes[0].bytes;
      print('📊 Y 채널 크기: ${yBytes.length} bytes');
      
      // Float32List 생성 (0.0-1.0 범위)
      final inputData = _convertToFloat32List(
        yBytes, 
        width, 
        height, 
        targetWidth, 
        targetHeight,
      );
      
      print('✅ 전처리 완료 - Float32List 크기: ${inputData.length}');
      return inputData;
      
    } catch (e) {
      print('❌ 전처리 실패: $e');
      print('❌ 스택트레이스: ${StackTrace.current}');
      return null;
    }
  }

  /// Y 채널을 Float32List로 변환 (ImageNet 정규화 적용)
  Float32List _convertToFloat32List(
    Uint8List yData,
    int originalWidth,
    int originalHeight,
    int targetWidth,
    int targetHeight,
  ) {
    print('🔄 Float32List 변환 시작: ${originalWidth}x${originalHeight} → ${targetWidth}x${targetHeight}');
    
    // ImageNet 정규화 값 가져오기
    final mean = (_modelInfo!['mean'] as List).cast<double>();
    final std = (_modelInfo!['std'] as List).cast<double>();
    print('📊 ImageNet 정규화 - mean: $mean, std: $std');
    
    // Float32List 생성 (targetWidth * targetHeight * 3)
    final inputData = Float32List(targetWidth * targetHeight * 3);
    
    final scaleX = originalWidth / targetWidth;
    final scaleY = originalHeight / targetHeight;
    
    int index = 0;
    
    // RGB 3채널로 처리
    for (int c = 0; c < 3; c++) { // R, G, B
      for (int y = 0; y < targetHeight; y++) {
        for (int x = 0; x < targetWidth; x++) {
          // 원본에서 샘플링
          final sourceX = (x * scaleX).round().clamp(0, originalWidth - 1);
          final sourceY = (y * scaleY).round().clamp(0, originalHeight - 1);
          
          final sourceIndex = sourceY * originalWidth + sourceX;
          
          // 안전한 접근 및 ImageNet 정규화 적용
          double normalizedValue = (0.5 - mean[c]) / std[c]; // 기본값 (중간 회색)
          if (sourceIndex < yData.length) {
            final pixelValue = yData[sourceIndex];
            // ImageNet 정규화: (픽셀값/255 - mean) / std
            normalizedValue = (pixelValue / 255.0 - mean[c]) / std[c];
          }
          
          inputData[index++] = normalizedValue;
        }
      }
    }
    
    print('✅ Float32List 변환 완료 - 크기: ${inputData.length}');
    print('📊 정규화 샘플 값: ${inputData.take(3).map((v) => v.toStringAsFixed(3)).toList()}');
    return inputData;
  }

  /// 최대값 인덱스 찾기
  int _getMaxIndex(List<double> scores) {
    double maxScore = scores[0];
    int maxIndex = 0;
    
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > maxScore) {
        maxScore = scores[i];
        maxIndex = i;
      }
    }
    
    return maxIndex;
  }

  /// 인식 중지
  void stopDetection() {
    print('🛑 모든 인식 중지');
    _isPillDetectionActive = false;
    _isBarcodeDetectionActive = false;
    _isPillDetectionRunning = false;
    _isBarcodeDetectionRunning = false;
    
    // 화면 전환 상태로 설정
    _isNavigatingAway = true;
    _lastNavigationTime = DateTime.now();
    
    // 중복 방지 데이터 초기화
    _lastDetectedBarcode = null;
    _lastBarcodeSuccessTime = null;
    
    if (_isImageStreamActive) {
      _isImageStreamActive = false;
      try {
        _cameraController?.stopImageStream();
        print('✅ 이미지 스트림 중지 완료');
      } catch (e) {
        print('⚠️ 이미지 스트림 중지 오류: $e');
      }
    }
  }

  /// 완전한 카메라 중지 (화면 전환 시 사용)
  Future<void> pauseCamera() async {
    print('⏸️ 카메라 완전 중지 시작');
    
    // 즉시 화면 전환 상태로 설정
    _isNavigatingAway = true;
    _lastNavigationTime = DateTime.now();
    
    // 모든 인식 즉시 중단
    _emergencyStopAllDetection();
    
    try {
      // 1. 이미지 스트림 완전 정지
      if (_cameraController?.value.isStreamingImages == true) {
        await _cameraController!.stopImageStream();
        print('✅ 이미지 스트림 완전 정지');
      }
      
      // 2. 카메라 컨트롤러 완전 해제
      if (_cameraController?.value.isInitialized == true) {
        await _cameraController!.dispose();
        _cameraController = null;
        print('✅ 카메라 컨트롤러 완전 해제');
      }
      
      // 3. 충분한 대기 시간 (하드웨어 완전 정리)
      await Future.delayed(Duration(milliseconds: 1500));
      print('✅ 카메라 완전 중지 완료');
      
    } catch (e) {
      print('⚠️ 카메라 완전 중지 오류: $e');
    }
  }

  /// 카메라 재시작 (화면 복귀 시 사용) - 바코드 스캐너 재초기화 추가
  Future<void> resumeCamera({String? newWidgetId}) async {
    final widgetId = newWidgetId ?? DateTime.now().millisecondsSinceEpoch.toString();
    print('▶️ 카메라 + 메모리 완전 재시작 (새 위젯: $widgetId)');
    
    try {
      // 1. 모든 상태 완전 초기화
      _isNavigatingAway = false;
      _isWidgetActive = false; // 아직 비활성 상태
      _currentWidgetId = widgetId;
      _lastNavigationTime = null;
      _lastDetectedBarcode = null;
      _lastBarcodeSuccessTime = null;
      _lastPillDetectionTime = null;
      _lastBarcodeDetectionTime = null;
      _isPillDetectionRunning = false;
      _isBarcodeDetectionRunning = false;
      _isImageStreamActive = false;
      
      // 2. ML Kit 완전 재초기화 (중요!)
      try {
        _barcodeScanner?.close();
        _barcodeScanner = null;
      } catch (e) {
        print('⚠️ 기존 바코드 스캐너 정리 오류: $e');
      }
      
      await Future.delayed(Duration(milliseconds: 500)); // ML Kit 정리 대기
      _initializeBarcodeScanner();
      
      // 3. 카메라 완전 재초기화
      await _initializeCamera();
      
      // 4. 메모리 안정화 대기
      await Future.delayed(Duration(milliseconds: 2000));
      
      // 5. 위젯 활성화 (이제 준비됨)
      _isWidgetActive = true;
      
      print('✅ 카메라 + 메모리 완전 재시작 완료 - 새 위젯 활성화: $widgetId');
      
    } catch (e) {
      print('⚠️ 카메라 재시작 오류: $e');
      throw e;
    }
  }

  /// 강제 초기화 (문제 발생 시 사용)
  void forceReset() {
    print('🔄 강제 초기화');
    _isNavigatingAway = false;
    _lastNavigationTime = null;
    _lastDetectedBarcode = null;
    _lastBarcodeSuccessTime = null;
    _lastPillDetectionTime = null;
    _lastBarcodeDetectionTime = null;
    _isPillDetectionRunning = false;
    _isBarcodeDetectionRunning = false;
    print('✅ 모든 상태 강제 초기화 완료');
  }

  /// 플래시 토글
  void toggleFlash() {
    try {
      if (_cameraController != null) {
        print('💡 플래시 토글');
        final currentFlashMode = _cameraController!.value.flashMode;
        final newFlashMode = currentFlashMode == FlashMode.off 
          ? FlashMode.torch 
          : FlashMode.off;
        _cameraController!.setFlashMode(newFlashMode);
      }
    } catch (e) {
      print('❌ 플래시 토글 오류: $e');
    }
  }

  /// 정리
  Future<void> dispose() async {
    print('🗑️ 카메라 정리');
    
    stopDetection();
    
    try {
      _barcodeScanner?.close();
      _barcodeScanner = null;
    } catch (e) {
      print('⚠️ 바코드 스캐너 정리 오류: $e');
    }
    
    try {
      if (_cameraController?.value.isStreamingImages == true) {
        await _cameraController!.stopImageStream();
      }
      await _cameraController?.dispose();
      _cameraController = null;
    } catch (e) {
      print('⚠️ 카메라 정리 오류: $e');
    }
    
    try {
      _pillModel?.close();
    } catch (e) {
      print('⚠️ TensorFlow Lite 모델 정리 오류: $e');
    }
    
    _pillModel = null;
    _labels = null;
    _modelInfo = null;
    _onBarcodeDetected = null;
    _onPillDetected = null;
    
    // 중복 방지 데이터 정리
    _lastDetectedBarcode = null;
    _lastBarcodeSuccessTime = null;
    
    // 화면 전환 상태 정리
    _isNavigatingAway = false;
    _lastNavigationTime = null;
    
    // 위젯 상태 정리
    _isWidgetActive = false;
    _currentWidgetId = null;
  }
}

/// 알약 분류 결과
class PillClassificationResult {
  final String className;
  final double confidence;
  final int classIndex;
  
  PillClassificationResult({
    required this.className,
    required this.confidence,
    required this.classIndex,
  });
  
  @override
  String toString() => '$className (${(confidence * 100).toStringAsFixed(1)}%)';
}

/// 카메라 초기화 결과
class CameraInitResult {
  final bool isSuccess;
  final bool isPermissionDenied;
  final String? errorMessage;

  CameraInitResult._({
    required this.isSuccess,
    required this.isPermissionDenied,
    this.errorMessage,
  });

  factory CameraInitResult.success() => CameraInitResult._(
        isSuccess: true,
        isPermissionDenied: false,
      );

  factory CameraInitResult.permissionDenied() => CameraInitResult._(
        isSuccess: false,
        isPermissionDenied: true,
        errorMessage: '카메라 권한이 필요합니다.',
      );

  factory CameraInitResult.error(String message) => CameraInitResult._(
        isSuccess: false,
        isPermissionDenied: false,
        errorMessage: message,
      );

  String getUserMessage() {
    if (isSuccess) return '카메라가 준비되었습니다';
    return errorMessage ?? '카메라 초기화에 실패했습니다';
  }
}

// Float32List reshape 확장 메서드
extension Float32ListReshape on Float32List {
  List<List<List<List<double>>>> reshape(List<int> shape) {
    if (shape.length != 4) {
      throw ArgumentError('Shape must have 4 dimensions for NHWC format');
    }
    
    final int n = shape[0]; // batch
    final int h = shape[1]; // height  
    final int w = shape[2]; // width
    final int c = shape[3]; // channels
    
    final result = List.generate(n, (batch) =>
      List.generate(h, (height) =>
        List.generate(w, (width) =>
          List.generate(c, (channel) {
            final index = batch * h * w * c + height * w * c + width * c + channel;
            return index < length ? this[index].toDouble() : 0.0;
          })
        )
      )
    );
    
    return result;
  }
}