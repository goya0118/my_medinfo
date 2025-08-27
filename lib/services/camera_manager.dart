import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'dart:collection';
import 'dart:async';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/services.dart';

// ================================================================================
// 데이터 클래스들 (먼저 정의)
// ================================================================================

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

/// YOLO 탐지 결과
class YOLODetection {
  final BoundingBox bbox;
  final String className;
  final double confidence;
  final int classId;
  
  YOLODetection({
    required this.bbox,
    required this.className,
    required this.confidence,
    required this.classId,
  });
  
  @override
  String toString() => '$className (${(confidence * 100).toStringAsFixed(1)}%)';
}

/// 바운딩 박스
class BoundingBox {
  final double x;
  final double y;
  final double width;
  final double height;
  
  BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
  
  double get centerX => x + width / 2;
  double get centerY => y + height / 2;
  double get right => x + width;
  double get bottom => y + height;
}

/// 바코드 처리용 데이터
class BarcodeProcessData {
  final CameraImage cameraImage;
  final CameraDescription cameraDescription;
  final bool isNavigatingAway;
  final bool isWidgetActive;
  final String? currentWidgetId;
  final String? lastDetectedBarcode;
  final DateTime? lastBarcodeSuccessTime;
  final DateTime? lastNavigationTime;
  final int barcodeSkipDuration;
  final int navigationCooldown;

  BarcodeProcessData({
    required this.cameraImage,
    required this.cameraDescription,
    required this.isNavigatingAway,
    required this.isWidgetActive,
    required this.currentWidgetId,
    this.lastDetectedBarcode,
    this.lastBarcodeSuccessTime,
    this.lastNavigationTime,
    required this.barcodeSkipDuration,
    required this.navigationCooldown,
  });
}

/// 바코드 처리 결과
class BarcodeProcessResult {
  final bool isSuccess;
  final String? barcodeValue;
  final String? errorMessage;

  BarcodeProcessResult({
    required this.isSuccess,
    this.barcodeValue,
    this.errorMessage,
  });

  factory BarcodeProcessResult.success(String barcodeValue) =>
      BarcodeProcessResult(isSuccess: true, barcodeValue: barcodeValue);

  factory BarcodeProcessResult.failure([String? error]) =>
      BarcodeProcessResult(isSuccess: false, errorMessage: error);
}

/// YOLO 전처리용 데이터
class YOLOPreprocessData {
  final CameraImage cameraImage;
  final int inputSize;

  YOLOPreprocessData({
    required this.cameraImage,
    required this.inputSize,
  });
}

/// YOLO 전처리 결과
class YOLOPreprocessResult {
  final Float32List inputTensor;
  final int originalWidth;
  final int originalHeight;

  YOLOPreprocessResult({
    required this.inputTensor,
    required this.originalWidth,
    required this.originalHeight,
  });
}

// ================================================================================
// 메인 CameraManager 클래스
// ================================================================================

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
  
  // TensorFlow Lite YOLO 모델 (TensorFlow Lite 타입 직접 사용)
  Interpreter? _yoloInterpreter;
  List<String>? _classNames;
  
  // TensorFlow Lite 설정
  late List<int> _inputShape;
  late List<int> _outputShape;
  late TensorType _inputType;
  late TensorType _outputType;
  
  // 인식 상태
  bool _isYOLODetectionActive = false;
  bool _isBarcodeDetectionActive = false;
  bool _isYOLODetectionRunning = false;
  bool _isBarcodeDetectionRunning = false;
  bool _isImageStreamActive = false;
  
  // 콜백
  Function(String)? _onBarcodeDetected;
  Function(List<YOLODetection>)? _onYOLODetected;
  
  // 독립적인 프레임 큐 시스템 (메모리 최적화)
  final Queue<CameraImage> _frameQueue = Queue<CameraImage>();
  Timer? _yoloProcessingTimer;
  Timer? _barcodeProcessingTimer;
  static const int _maxQueueSize = 1; // 1개 프레임만 유지 (메모리 절약)
  
  // 마지막 처리 시간 (호환성 유지)
  DateTime? _lastYOLODetectionTime;
  DateTime? _lastBarcodeDetectionTime;
  
  // 중복 인식 방지
  String? _lastDetectedBarcode;
  DateTime? _lastBarcodeSuccessTime;
  
  // 화면 전환 추적
  bool _isNavigatingAway = false;
  DateTime? _lastNavigationTime;
  bool _isWidgetActive = false;
  String? _currentWidgetId;
  
  // 성능 최적화 설정 - 저사양 기기 대응
  static const int _barcodeDetectionInterval = 300;  // 0.8초
  static const int _yoloDetectionInterval = 2000;    // 3초 (성능 고려)
  static const int _barcodeSkipDuration = 5000;      // 5초간 같은 바코드 스킵
  static const int _navigationCooldown = 3000;       // 화면 전환 후 3초 쿨다운
  
  // YOLO 설정 - 모델 학습 크기 유지 (필수!)
  static const double _confidenceThreshold = 0.75;    // 임계값 
  static const double _iouThreshold = 0.4;           // NMS IoU 임계값
  static const int _inputSize = 768;                 // 모델 학습 크기 그대로 유지
  
  bool get isInitialized => _cameraController?.value.isInitialized == true;
  CameraController? get cameraController => _cameraController;

  /// 통합 카메라 초기화 (YOLO + 바코드)
  Future<CameraInitResult> initializeCamera() async {
    try {
      print('🔍 TensorFlow Lite YOLO + 바코드 통합 카메라 초기화 시작');
      
      // 기존 정리
      await dispose();
      
      // 1. YOLO TensorFlow Lite 모델 로드
      await _loadYOLOModel();
      
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

  /// Camera 초기화 (성능 최적화)
  Future<void> _initializeCamera() async {
    print('📷 Camera 초기화 (성능 최적화 모드)');
    
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw Exception('사용 가능한 카메라가 없습니다');
    }
    
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    
    // 성능 최적화된 카메라 설정
    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.high,  // medium 
      enableAudio: false,
      imageFormatGroup: Platform.isIOS ? null : ImageFormatGroup.nv21, 
    );
    
    await _cameraController!.initialize();
    
    // 카메라 기능 최적화 (불필요한 기능 비활성화)
    try {
      await _cameraController!.setExposureMode(ExposureMode.locked); // 자동 노출 비활성화
      print('✅ 카메라 기능 최적화 완료');
    } catch (e) {
      print('⚠️ 카메라 기능 최적화 실패 (무시): $e');
    }
    
    // 초기화 후 대기 시간 단축
    await Future.delayed(Duration(milliseconds: 200)); // 500ms → 200ms
    
    print('✅ Camera 초기화 완료 (해상도: ${_cameraController!.value.previewSize})');
  }

  /// YOLO v8 TensorFlow Lite 모델 로드 (성능 최적화)
  Future<void> _loadYOLOModel() async {
    try {
      
      final interpreterOptions = InterpreterOptions()
    ..threads = 1; 
      print('🔄 CPU 단일 스레드 모드로 실행');
      
      // TensorFlow Lite 모델 파일 로드
      _yoloInterpreter = await Interpreter.fromAsset(
        'assets/models/best.tflite',
        options: interpreterOptions,
      );
      
      print('✅ TensorFlow Lite 모델 로드 완료');
      
      // 모델 정보 확인
      _inputShape = _yoloInterpreter!.getInputTensor(0).shape;
      _outputShape = _yoloInterpreter!.getOutputTensor(0).shape;
      _inputType = _yoloInterpreter!.getInputTensor(0).type;
      _outputType = _yoloInterpreter!.getOutputTensor(0).type;
      
      print('📊 모델 정보 (성능 최적화):');
      print('  - 입력 형태: $_inputShape (타입: $_inputType)');
      print('  - 출력 형태: $_outputShape (타입: $_outputType)');
      print('  - 처리 크기: ${_inputSize}x${_inputSize} (축소됨)');
      
      // 클래스 이름 로드 (오류 처리 강화)
      try {
        final classNamesString = await rootBundle.loadString('assets/models/class_names.txt');
        _classNames = classNamesString.trim().split('\n').where((name) => name.isNotEmpty).toList();
        print('✅ 클래스 이름 로드 완료: ${_classNames!.length}개 클래스');
        print('📋 클래스 목록: $_classNames');
      } catch (e) {
        print('⚠️ 클래스 이름 파일 로드 실패: $e');
        print('🔄 기본 클래스 이름 사용');
        _classNames = ['pill_type_1', 'pill_type_2']; // 기본값
      }
      
    } catch (e) {
      print('❌ YOLO 모델 로드 실패: $e');
      throw e;
    }
  }
  

  /// 통합 인식 시작 (바코드 + YOLO)
  void startDetection({
    Function(String)? onBarcodeDetected,
    Function(List<YOLODetection>)? onYOLODetected,
    bool enableVibration = true,
    bool clearPreviousResults = true,
    String? widgetId,
  }) {
    _onBarcodeDetected = onBarcodeDetected;
    _onYOLODetected = onYOLODetected;
    
    // 위젯 활성화 및 식별자 설정
    _isWidgetActive = true;
    _currentWidgetId = widgetId ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('⚠️ 카메라가 초기화되지 않음');
      return;
    }

    print('🔄 통합 인식 시작 (바코드: ${onBarcodeDetected != null}, YOLO: ${onYOLODetected != null})');
    print('🆔 위젯 ID: $_currentWidgetId');
    
    _isBarcodeDetectionActive = onBarcodeDetected != null;
    _isYOLODetectionActive = onYOLODetected != null;
    _lastYOLODetectionTime = null;
    _lastBarcodeDetectionTime = null;
    _lastYOLODetectionTime = null;
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

  /// 이미지 스트림 시작 (완전 분리형)
  void _startImageStream() {
    if (_isImageStreamActive) return;

    print('📸 이미지 스트림 시작 (완전 분리형 처리)');
    _isImageStreamActive = true;

    Future.delayed(Duration(milliseconds: 800), () {
      if (!_isImageStreamActive) return;

      print('📸 실제 이미지 스트림 시작');
      _cameraController!.startImageStream((CameraImage image) async {
        if (!_isImageStreamActive || _isNavigatingAway) return;

        // 단순히 프레임만 큐에 추가 (처리는 별도 타이머에서)
        _processImageInBackground(image);
      });
      
      // 독립적인 처리 타이머들 시작
      _startBarcodeProcessingTimer();
      _startYOLOProcessingTimer();
    });
  }

  /// 백그라운드 이미지 처리 (메모리 최적화)
  void _processImageInBackground(CameraImage cameraImage) {
    try {
      // 화면 전환 중이면 모든 처리 중단
      if (_isNavigatingAway) {
        return;
      }
      
      // 큐가 가득 찬 경우 오래된 프레임 즉시 정리
      if (_frameQueue.length >= _maxQueueSize) {
        while (_frameQueue.isNotEmpty) {
          _frameQueue.removeFirst();
        }
      }
      
      // 새 프레임 추가
      _frameQueue.add(cameraImage);
      
    } catch (e) {
      print('❌ 프레임 큐잉 오류: $e');
      // 오류 발생 시 큐 완전 정리
      _frameQueue.clear();
    }
  }

  /// 독립적인 바코드 처리 타이머 시작
  void _startBarcodeProcessingTimer() {
    _barcodeProcessingTimer?.cancel();
    
    if (!_isBarcodeDetectionActive) return;
    
    _barcodeProcessingTimer = Timer.periodic(Duration(milliseconds: _barcodeDetectionInterval), (timer) async {
      if (_isNavigatingAway || !_isWidgetActive) {
        return;
      }
      
      if (_isBarcodeDetectionRunning) {
        return; // 로그 스팸 방지
      }
      
      // 큐가 비어있으면 스킵
      if (_frameQueue.isEmpty) {
        return;
      }
      
      // 최신 프레임으로 바코드 처리 (프레임 즉시 소비)
      final frame = _frameQueue.removeLast();
      await _processBarcodeFromQueue(frame);
    });
    
    print('✅ 독립적인 바코드 처리 타이머 시작 (${_barcodeDetectionInterval}ms)');
  }

  /// 독립적인 YOLO 처리 타이머 시작
  void _startYOLOProcessingTimer() {
    _yoloProcessingTimer?.cancel();
    
    if (!_isYOLODetectionActive) return;
    
    _yoloProcessingTimer = Timer.periodic(Duration(milliseconds: _yoloDetectionInterval), (timer) async {
      if (_isNavigatingAway || !_isWidgetActive) {
        return;
      }
      
      if (_isYOLODetectionRunning) {
        return; // 로그 스팸 방지
      }
      
      // 큐가 비어있으면 스킵
      if (_frameQueue.isEmpty) {
        return;
      }
      
      // 최신 프레임으로 YOLO 처리 (프레임 즉시 소비)
      final frame = _frameQueue.removeLast();
      await _processYOLOFromQueue(frame);
    });
    
    print('✅ 독립적인 YOLO 처리 타이머 시작 (${_yoloDetectionInterval}ms)');
  }

  /// 큐에서 바코드 처리 (완전 독립적)
  Future<void> _processBarcodeFromQueue(CameraImage cameraImage) async {
    if (_isBarcodeDetectionRunning || _isNavigatingAway) return;
    
    _isBarcodeDetectionRunning = true;
    
    try {
      // 상태 체크
      if (_isNavigatingAway || !_isWidgetActive) {
        return;
      }
      
      final now = DateTime.now();
      
      // 네비게이션 쿨다운 체크
      if (_lastNavigationTime != null) {
        final timeSinceNavigation = now.difference(_lastNavigationTime!).inMilliseconds;
        if (timeSinceNavigation < _navigationCooldown) {
          return;
        }
      }
      
      // 중복 바코드 스킵 체크
      if (_lastDetectedBarcode != null && _lastBarcodeSuccessTime != null) {
        final timeSinceLastDetection = now.difference(_lastBarcodeSuccessTime!).inMilliseconds;
        if (timeSinceLastDetection < _barcodeSkipDuration) {
          return;
        }
      }
      
      // 바코드 스캐너 null 체크
      if (_barcodeScanner == null) {
        _initializeBarcodeScanner();
        if (_barcodeScanner == null) return;
      }
      
      // InputImage 생성
      final inputImage = _createOptimizedInputImageSafe(cameraImage);
      if (inputImage == null) return;
      
      // ML Kit 바코드 스캔
      final barcodes = await _barcodeScanner!.processImage(inputImage);
      
      // 처리 후 상태 재확인
      if (_isNavigatingAway || !_isWidgetActive) return;
      
      if (barcodes.isNotEmpty && _onBarcodeDetected != null) {
        final barcode = barcodes.first;
        if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
          // 중복 체크
          if (_lastDetectedBarcode == barcode.rawValue) {
            final timeSinceLastSuccess = now.difference(_lastBarcodeSuccessTime ?? DateTime(2000)).inMilliseconds;
            if (timeSinceLastSuccess < _barcodeSkipDuration) {
              return;
            }
          }
          
          // 최종 상태 체크
          if (_isNavigatingAway || !_isWidgetActive) return;
          
          print('📦 독립적 바코드 감지: ${barcode.rawValue}');
          
          // 즉시 모든 인식 차단
          _emergencyStopAllDetection();
          
          // 성공 정보 저장
          _lastDetectedBarcode = barcode.rawValue;
          _lastBarcodeSuccessTime = now;
          
          // 성공 진동 실행
          await _vibrateSuccess();
          
          _onBarcodeDetected!(barcode.rawValue!);
        }
      }
      
    } catch (e) {
      print('❌ 독립적 바코드 인식 오류: $e');
      if (!_isNavigatingAway) {
        _initializeBarcodeScanner();
      }
    } finally {
      _isBarcodeDetectionRunning = false;
    }
  }

  /// 큐에서 YOLO 처리 (완전 독립적)
  Future<void> _processYOLOFromQueue(CameraImage cameraImage) async {
    if (_isYOLODetectionRunning || _isNavigatingAway) return;
    
    _isYOLODetectionRunning = true;
    
    try {
      // Step 1: 백그라운드에서 이미지 전처리
      final preprocessedData = await compute(_preprocessYOLOInIsolate, YOLOPreprocessData(
        cameraImage: cameraImage,
        inputSize: _inputSize,
      ));
      
      if (preprocessedData == null || _isNavigatingAway || !_isWidgetActive) {
        return;
      }
      
      // Step 2: 메인 스레드에서 TensorFlow Lite 추론
      await _performYOLOInferenceOptimized(preprocessedData);
      
    } catch (e) {
      print('❌ 독립적 YOLO 처리 오류: $e');
    } finally {
      _isYOLODetectionRunning = false;
    }
  }

  /// 백그라운드 바코드 인식 (메인 스레드 비동기 처리로 변경)
  void _detectBarcodeInBackground(CameraImage cameraImage) {
    if (_isBarcodeDetectionRunning || _isNavigatingAway) return;
    
    _isBarcodeDetectionRunning = true;
    
    // ML Kit은 Isolate에서 사용할 수 없으므로 메인 스레드에서 비동기 처리
    Future.microtask(() async {
      try {
        // 상태 체크
        if (_isNavigatingAway || !_isWidgetActive) {
          print('🚫 위젯 비활성 상태, 바코드 처리 중단');
          return;
        }
        
        final now = DateTime.now();
        
        // 네비게이션 쿨다운 체크
        if (_lastNavigationTime != null) {
          final timeSinceNavigation = now.difference(_lastNavigationTime!).inMilliseconds;
          if (timeSinceNavigation < _navigationCooldown) {
            print('🚫 네비게이션 쿨다운 중 (${timeSinceNavigation}ms/${_navigationCooldown}ms)');
            return;
          }
        }
        
        // 중복 바코드 스킵 체크
        if (_lastDetectedBarcode != null && _lastBarcodeSuccessTime != null) {
          final timeSinceLastDetection = now.difference(_lastBarcodeSuccessTime!).inMilliseconds;
          if (timeSinceLastDetection < _barcodeSkipDuration) {
            print('🚫 중복 바코드 스킵 (${timeSinceLastDetection}ms/${_barcodeSkipDuration}ms)');
            return;
          }
        }
        
        // 바코드 스캐너 null 체크
        if (_barcodeScanner == null) {
          print('❌ 바코드 스캐너가 null입니다. 재초기화 시도...');
          _initializeBarcodeScanner();
          if (_barcodeScanner == null) {
            print('❌ 바코드 스캐너 재초기화 실패');
            return;
          }
        }
        
        // InputImage 생성
        final inputImage = _createOptimizedInputImageSafe(cameraImage);
        if (inputImage == null) {
          print('❌ 최적화된 InputImage 생성 실패');
          return;
        }
        
        // 상태 재체크
        if (_isNavigatingAway || !_isWidgetActive) {
          print('🚫 InputImage 생성 후 상태 변경 감지, 중단');
          return;
        }
        
        print('📷 비동기 바코드 스캔 실행 중... (위젯: $_currentWidgetId)');
        
        // ML Kit 바코드 스캔
        List<Barcode>? barcodes;
        try {
          barcodes = await _barcodeScanner!.processImage(inputImage);
        } catch (e) {
          print('❌ ML Kit 바코드 처리 오류: $e');
          _initializeBarcodeScanner();
          return;
        }
        
        // 처리 후 상태 재확인
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
            // 중복 체크
            if (_lastDetectedBarcode == barcode.rawValue) {
              final timeSinceLastSuccess = now.difference(_lastBarcodeSuccessTime ?? DateTime(2000)).inMilliseconds;
              if (timeSinceLastSuccess < _barcodeSkipDuration) {
                print('🔄 동일한 바코드 감지, 스킵: ${barcode.rawValue} (${timeSinceLastSuccess}ms 전 인식)');
                return;
              }
            }
            
            // 최종 상태 체크
            if (_isNavigatingAway || !_isWidgetActive) {
              print('🚫 콜백 호출 직전 상태 변경 감지, 무시');
              return;
            }
            
            print('📦 새로운 바코드 감지: ${barcode.rawValue} (위젯: $_currentWidgetId)');
            
            // 즉시 모든 인식 차단
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
        print('❌ 비동기 바코드 인식 오류: $e');
        if (_isNavigatingAway) {
          print('🚫 화면 전환 중 바코드 오류 발생, 무시');
          return;
        }
        
        // 바코드 스캐너 재초기화 시도
        print('🔄 오류 복구를 위한 바코드 스캐너 재초기화...');
        _initializeBarcodeScanner();
        
      } finally {
        _isBarcodeDetectionRunning = false;
      }
    });
  }

  /// 안전한 최적화된 InputImage 생성 (null 체크 강화)
  InputImage? _createOptimizedInputImageSafe(CameraImage cameraImage) {
    try {
      if (_cameraController == null) {
        print('❌ 카메라 컨트롤러가 null');
        return null;
      }
      
      final camera = _cameraController!.description;
      
      // 회전값 설정
      InputImageRotation rotation = InputImageRotation.rotation0deg;
      switch (camera.sensorOrientation) {
        case 90:
          rotation = InputImageRotation.rotation90deg;
          break;
        case 180:
          rotation = InputImageRotation.rotation180deg;
          break;
        case 270:
          rotation = InputImageRotation.rotation270deg;
          break;
      }
      
      // 간단한 방법으로 InputImage 생성 (첫 번째 plane만 사용)
      if (Platform.isIOS) {
        // iOS: YUV420 포맷 처리
        return InputImage.fromBytes(
          bytes: _concatenateYUVPlanes(cameraImage.planes),
          metadata: InputImageMetadata(
            size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.bgra8888, // iOS 기본
            bytesPerRow: cameraImage.planes[0].bytesPerRow,
          ),
        );
      } else {
        // Android: NV21 포맷 처리
        if (cameraImage.planes.isNotEmpty) {
          return InputImage.fromBytes(
            bytes: cameraImage.planes[0].bytes,
            metadata: InputImageMetadata(
              size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
              rotation: rotation,
              format: InputImageFormat.nv21,
              bytesPerRow: cameraImage.planes[0].bytesPerRow,
            ),
          );
        }
      }
    
      
      print('❌ CameraImage planes가 비어있음');
      return null;
      
    } catch (e) {
      print('❌ InputImage 생성 실패: $e');
      return null;
      try {
        return InputImage.fromBytes(
          bytes: cameraImage.planes.first.bytes,
          metadata: InputImageMetadata(
            size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
            rotation: InputImageRotation.rotation0deg,
            format: Platform.isIOS ? InputImageFormat.bgra8888 : InputImageFormat.nv21,
            bytesPerRow: cameraImage.planes.first.bytesPerRow,
          ),
        );
      } catch (e2) {
        print('❌ 폴백 InputImage 생성도 실패: $e2');
        return null;
      }
    }
  }
  Uint8List _concatenateYUVPlanes(List<Plane> planes) {
    final writeBuffer = WriteBuffer();
    for (final plane in planes) {
      writeBuffer.putUint8List(plane.bytes);
    }
    return writeBuffer.done().buffer.asUint8List();
  }

  /// 비동기 YOLO 인식 (전처리 + 추론 분리)
  void _detectYOLOAsync(CameraImage cameraImage) {
    if (_isYOLODetectionRunning || _isNavigatingAway) return;
    
    _isYOLODetectionRunning = true;
    
    // Step 1: 백그라운드에서 이미지 전처리
    compute(_preprocessYOLOInIsolate, YOLOPreprocessData(
      cameraImage: cameraImage,
      inputSize: _inputSize,
    )).then((preprocessedData) {
      if (preprocessedData == null || _isNavigatingAway || !_isWidgetActive) {
        _isYOLODetectionRunning = false;
        return;
      }
      
      // Step 2: 메인 스레드에서 TensorFlow Lite 추론 (프레임 스킵)
      _performYOLOInferenceOptimized(preprocessedData);
      
    }).catchError((error) {
      print('❌ YOLO 전처리 오류: $error');
      _isYOLODetectionRunning = false;
    });
  }

  /// 최적화된 YOLO 추론 (메인 스레드, 프레임 스킵)
  Future<void> _performYOLOInferenceOptimized(YOLOPreprocessResult preprocessedData) async {
    try {
      if (_yoloInterpreter == null || _isNavigatingAway || !_isWidgetActive) {
        return;
      }
      
      print('🤖 YOLO 추론 실행 중... (크기: ${preprocessedData.inputTensor.length})');
      
      // TensorFlow Lite 추론 실행
      final outputs = await _runYOLOInference(preprocessedData.inputTensor);
      if (outputs == null || _isNavigatingAway) {
        return;
      }
      
      // 후처리 (NMS, 좌표 변환)
      final detections = _postProcessYOLOOutput(
        outputs, 
        preprocessedData.originalWidth, 
        preprocessedData.originalHeight
      );
      
      // 결과 콜백
      if (!_isNavigatingAway && _isWidgetActive && _onYOLODetected != null) {
        if (detections.isNotEmpty) {
          print('🎯 YOLO 탐지 성공: ${detections.length}개 객체');
          _onYOLODetected!(detections);
        }
      }
      
    } catch (e) {
      print('❌ YOLO 추론 오류: $e');
    } finally {
      _isYOLODetectionRunning = false;
    }
  }

  /// TensorFlow Lite YOLO 추론 실행
  Future<List<List<double>>?> _runYOLOInference(Float32List inputTensor) async {
    try {
      // 입력 텐서 준비 (NHWC 형식: [1, 768, 768, 3])
      final input = _reshapeInput(inputTensor, [1, _inputSize, _inputSize, 3]);
      
      // 출력 텐서 준비
      final outputTensor = _yoloInterpreter!.getOutputTensor(0);
      final outputShape = outputTensor.shape;
      
      // 동적 출력 텐서 생성
      late List output;
      
      if (outputShape.length == 3) {
        output = List.generate(outputShape[0], (_) => 
          List.generate(outputShape[1], (_) => 
            List.filled(outputShape[2], 0.0)
          )
        );
      } else {
        throw Exception('지원하지 않는 출력 텐서 차원: ${outputShape.length}');
      }
      
      // 추론 실행
      _yoloInterpreter!.run(input, output);
      
      // 출력 변환: [1, Features, Detections] → [Detections, Features]
      List<List<double>> formattedOutput = [];
      
      if (outputShape.length == 3) {
        final numFeatures = outputShape[1];
        final numDetections = outputShape[2];
        
        for (int i = 0; i < numDetections; i++) {
          List<double> detection = [];
          for (int j = 0; j < numFeatures; j++) {
            detection.add((output[0][j][i] as num).toDouble());
          }
          formattedOutput.add(detection);
        }
      }
      
      return formattedOutput;
      
    } catch (e) {
      print('❌ TensorFlow Lite 추론 실행 실패: $e');
      return null;
    }
  }

  /// 입력 텐서 재구성
  List _reshapeInput(Float32List input, List<int> shape) {
    List<List<List<List<double>>>> reshaped = [];
    
    int index = 0;
    for (int n = 0; n < shape[0]; n++) {
      List<List<List<double>>> batch = [];
      for (int h = 0; h < shape[1]; h++) {
        List<List<double>> row = [];
        for (int w = 0; w < shape[2]; w++) {
          List<double> pixel = [];
          for (int c = 0; c < shape[3]; c++) {
            pixel.add(input[index++]);
          }
          row.add(pixel);
        }
        batch.add(row);
      }
      reshaped.add(batch);
    }
    
    return reshaped;
  }

  /// YOLO 출력 후처리
  List<YOLODetection> _postProcessYOLOOutput(
    List<List<double>> outputs, 
    int originalWidth, 
    int originalHeight
  ) {
    try {
      List<YOLODetection> detections = [];
      
      if (outputs.isEmpty) return detections;
      
      final int numFeatures = outputs[0].length;
      final int numClasses = numFeatures - 4;
      
      if (numClasses <= 0) return detections;
      
      final int actualNumClasses = math.min(numClasses, _classNames?.length ?? numClasses);
      
      for (final detection in outputs) {
        if (detection.length < 4 + actualNumClasses) continue;
        
        final double centerX = detection[0];
        final double centerY = detection[1];
        final double width = detection[2];
        final double height = detection[3];
        
        // 최대 신뢰도 클래스 찾기
        double maxConfidence = 0.0;
        int bestClassId = 0;
        
        for (int i = 0; i < actualNumClasses; i++) {
          if (detection[4 + i] > maxConfidence) {
            maxConfidence = detection[4 + i];
            bestClassId = i;
          }
        }
        
        // 신뢰도 임계값 체크
        if (maxConfidence >= _confidenceThreshold) {
          String className = 'unknown';
          if (_classNames != null && bestClassId < _classNames!.length) {
            className = _classNames![bestClassId];
          } else {
            className = 'pill_type_${bestClassId + 1}';
          }
          
          // 좌표 변환
          final double scaledX = (centerX / _inputSize) * originalWidth;
          final double scaledY = (centerY / _inputSize) * originalHeight;
          final double scaledWidth = (width / _inputSize) * originalWidth;
          final double scaledHeight = (height / _inputSize) * originalHeight;
          
          detections.add(YOLODetection(
            bbox: BoundingBox(
              x: scaledX - scaledWidth / 2,
              y: scaledY - scaledHeight / 2,
              width: scaledWidth,
              height: scaledHeight,
            ),
            className: className,
            confidence: maxConfidence,
            classId: bestClassId,
          ));
        }
      }
      
      // NMS 적용
      detections = _applyNMS(detections, _iouThreshold);
      
      return detections;
      
    } catch (e) {
      print('❌ YOLO 후처리 실패: $e');
      return [];
    }
  }

  /// NMS 적용
  List<YOLODetection> _applyNMS(List<YOLODetection> detections, double iouThreshold) {
    if (detections.isEmpty) return [];
    
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    List<YOLODetection> nmsResults = [];
    List<bool> suppressed = List.filled(detections.length, false);
    
    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      
      nmsResults.add(detections[i]);
      
      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        
        final double iou = _calculateIoU(detections[i].bbox, detections[j].bbox);
        if (iou > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }
    
    return nmsResults;
  }

  /// IoU 계산
  double _calculateIoU(BoundingBox box1, BoundingBox box2) {
    final double intersectionX = math.max(box1.x, box2.x);
    final double intersectionY = math.max(box1.y, box2.y);
    final double intersectionWidth = math.max(0, math.min(box1.x + box1.width, box2.x + box2.width) - intersectionX);
    final double intersectionHeight = math.max(0, math.min(box1.y + box1.height, box2.y + box2.height) - intersectionY);
    
    final double intersectionArea = intersectionWidth * intersectionHeight;
    final double box1Area = box1.width * box1.height;
    final double box2Area = box2.width * box2.height;
    final double unionArea = box1Area + box2Area - intersectionArea;
    
    return unionArea > 0 ? intersectionArea / unionArea : 0.0;
  }

  /// 바코드 결과 처리 (메인 스레드) - 단순화
  void _handleBarcodeResult(String barcodeValue) async {
    final now = DateTime.now();
    
    // 최종 상태 체크
    if (_isNavigatingAway || !_isWidgetActive) {
      print('🚫 바코드 결과 처리 시 상태 변경 감지, 무시');
      return;
    }
    
    print('📦 바코드 감지 완료: $barcodeValue (위젯: $_currentWidgetId)');
    
    // 즉시 모든 인식 차단
    _emergencyStopAllDetection();
    
    // 성공 정보 저장
    _lastDetectedBarcode = barcodeValue;
    _lastBarcodeSuccessTime = now;
    
    // 성공 진동 실행
    await _vibrateSuccess();
    
    print('🚀 바코드 콜백 호출: $barcodeValue');
    _onBarcodeDetected?.call(barcodeValue);
  }

  /// 긴급 모든 인식 중단 (바코드 인식 성공 시 즉시 호출)
  void _emergencyStopAllDetection() {
    print('🚨 긴급 모든 인식 및 추론 중단 (위젯: $_currentWidgetId)');
    
    // 즉시 모든 상태 차단
    _isNavigatingAway = true;
    _isWidgetActive = false; // 위젯도 비활성화
    _lastNavigationTime = DateTime.now();
    _isYOLODetectionActive = false;
    _isBarcodeDetectionActive = false;
    _isYOLODetectionRunning = false;
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

  /// 인식 중지 (타이머 정리 추가)
  void stopDetection() {
    print('🛑 모든 인식 중지 (타이머 정리 포함)');
    
    // 타이머들 정리
    _barcodeProcessingTimer?.cancel();
    _yoloProcessingTimer?.cancel();
    _barcodeProcessingTimer = null;
    _yoloProcessingTimer = null;
    
    _isYOLODetectionActive = false;
    _isBarcodeDetectionActive = false;
    _isYOLODetectionRunning = false;
    _isBarcodeDetectionRunning = false;
    
    // 프레임 큐 정리
    _frameQueue.clear();
    
    // 화면 전환 상태로 설정
    _isNavigatingAway = true;
    _lastNavigationTime = DateTime.now();
    
    // 중복 방지 데이터 초기화
    _lastDetectedBarcode = null;
    _lastBarcodeSuccessTime = null;
    _lastYOLODetectionTime = null;
    _lastBarcodeDetectionTime = null;
    _lastYOLODetectionTime = null;
    _lastBarcodeDetectionTime = null;
    
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
      _lastYOLODetectionTime = null;
      _lastBarcodeDetectionTime = null;
      _isYOLODetectionRunning = false;
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
    _lastYOLODetectionTime = null;
    _lastBarcodeDetectionTime = null;
    _isYOLODetectionRunning = false;
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
      _yoloInterpreter?.close();
    } catch (e) {
      print('⚠️ TensorFlow Lite 인터프리터 정리 오류: $e');
    }
    
    _yoloInterpreter = null;
    _classNames = null;
    _onBarcodeDetected = null;
    _onYOLODetected = null;
    
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

// ================================================================================
// Isolate 함수들 (YOLO 전처리용)
// ================================================================================

/// YOLO 전처리 (Isolate에서 실행)
Future<YOLOPreprocessResult?> _preprocessYOLOInIsolate(YOLOPreprocessData data) async {
  try {
    print('🔄 [Isolate] YOLO 전처리 시작');
    
    // CameraImage → RGB 변환
    final rgbImage = _convertCameraImageToRGBInIsolate(data.cameraImage);
    if (rgbImage == null) {
      print('❌ [Isolate] RGB 변환 실패');
      return null;
    }
    
    // 리사이즈
    final resizedImage = img.copyResize(
      rgbImage,
      width: data.inputSize,
      height: data.inputSize,
      interpolation: img.Interpolation.linear,
    );
    
    // Float32List 변환
    final inputTensor = _imageToTensorInIsolate(resizedImage);
    
    print('✅ [Isolate] YOLO 전처리 완료');
    
    return YOLOPreprocessResult(
      inputTensor: inputTensor,
      originalWidth: data.cameraImage.width,
      originalHeight: data.cameraImage.height,
    );
    
  } catch (e) {
    print('❌ [Isolate] YOLO 전처리 오류: $e');
    return null;
  }
}

/// Isolate에서 이미지를 텐서로 변환
Float32List _imageToTensorInIsolate(img.Image image) {
  final int width = image.width;
  final int height = image.height;
  final Float32List tensor = Float32List(height * width * 3);
  
  int index = 0;
  
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final pixel = image.getPixel(x, y);
      tensor[index++] = pixel.r / 255.0; // R
      tensor[index++] = pixel.g / 255.0; // G
      tensor[index++] = pixel.b / 255.0; // B
    }
  }
  
  return tensor;
}

/// Isolate에서 CameraImage → RGB 변환
img.Image? _convertCameraImageToRGBInIsolate(CameraImage cameraImage) {
  try {
    if (cameraImage.format.group == ImageFormatGroup.nv21) {
      return _convertNV21ToRGBInIsolate(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      return _convertYUV420ToRGBInIsolate(cameraImage);
    } else {
      return _convertCameraImageFallbackInIsolate(cameraImage);
    }
  } catch (e) {
    print('❌ [Isolate] RGB 변환 실패: $e');
    return _convertCameraImageFallbackInIsolate(cameraImage);
  }
}

/// Isolate에서 NV21 → RGB 변환
img.Image? _convertNV21ToRGBInIsolate(CameraImage cameraImage) {
  try {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    
    if (cameraImage.planes.isEmpty) return null;
    
    final Uint8List allBytes = cameraImage.planes[0].bytes;
    final int yRowStride = cameraImage.planes[0].bytesPerRow;
    final int ySize = width * height;
    
    if (allBytes.length < ySize) {
      return _convertCameraImageFallbackInIsolate(cameraImage);
    }
    
    final img.Image rgbImage = img.Image(width: width, height: height);
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yRowStride + x;
        if (yIndex >= allBytes.length) continue;
        
        final int yValue = allBytes[yIndex];
        
        // UV 값 읽기
        final int uvRow = y ~/ 2;
        final int uvCol = x ~/ 2;
        final int uvIndex = ySize + uvRow * width + uvCol * 2;
        
        int uValue = 128;
        int vValue = 128;
        
        if (uvIndex + 1 < allBytes.length) {
          vValue = allBytes[uvIndex];
          uValue = allBytes[uvIndex + 1];
        } else if (uvIndex < allBytes.length) {
          vValue = allBytes[uvIndex];
        }
        
        // YUV → RGB 변환
        final double yNorm = yValue.toDouble();
        final double uNorm = uValue.toDouble() - 128.0;
        final double vNorm = vValue.toDouble() - 128.0;
        
        final int r = _clampRGBInIsolate((yNorm + 1.402 * vNorm).round());
        final int g = _clampRGBInIsolate((yNorm - 0.344 * uNorm - 0.714 * vNorm).round());
        final int b = _clampRGBInIsolate((yNorm + 1.772 * uNorm).round());
        
        rgbImage.setPixelRgb(x, y, r, g, b);
      }
    }
    
    return rgbImage;
  } catch (e) {
    print('❌ [Isolate] NV21 변환 실패: $e');
    return _convertCameraImageFallbackInIsolate(cameraImage);
  }
}

/// Isolate에서 YUV420 → RGB 변환
img.Image? _convertYUV420ToRGBInIsolate(CameraImage cameraImage) {
  try {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    
    if (cameraImage.planes.length < 3) return null;
    
    final Uint8List yBytes = cameraImage.planes[0].bytes;
    final Uint8List uBytes = cameraImage.planes[1].bytes;
    final Uint8List vBytes = cameraImage.planes[2].bytes;
    
    final int yStride = cameraImage.planes[0].bytesPerRow;
    final int uStride = cameraImage.planes[1].bytesPerRow;
    final int vStride = cameraImage.planes[2].bytesPerRow;
    
    final img.Image rgbImage = img.Image(width: width, height: height);
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yStride + x;
        final int uvRow = y ~/ 2;
        final int uvCol = x ~/ 2;
        final int uIndex = uvRow * uStride + uvCol;
        final int vIndex = uvRow * vStride + uvCol;
        
        if (yIndex < yBytes.length && uIndex < uBytes.length && vIndex < vBytes.length) {
          final int yValue = yBytes[yIndex];
          final int uValue = uBytes[uIndex];
          final int vValue = vBytes[vIndex];
          
          // YUV → RGB 변환
          final double yNorm = yValue.toDouble();
          final double uNorm = uValue.toDouble() - 128.0;
          final double vNorm = vValue.toDouble() - 128.0;
          
          final int r = _clampRGBInIsolate((yNorm + 1.402 * vNorm).round());
          final int g = _clampRGBInIsolate((yNorm - 0.344 * uNorm - 0.714 * vNorm).round());
          final int b = _clampRGBInIsolate((yNorm + 1.772 * uNorm).round());
          
          rgbImage.setPixelRgb(x, y, r, g, b);
        }
      }
    }
    
    return rgbImage;
  } catch (e) {
    print('❌ [Isolate] YUV420 변환 실패: $e');
    return null;
  }
}

/// Isolate에서 폴백 변환
img.Image? _convertCameraImageFallbackInIsolate(CameraImage cameraImage) {
  try {
    if (cameraImage.planes.isEmpty) return null;
    
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final Uint8List yBytes = cameraImage.planes[0].bytes;
    final int yStride = cameraImage.planes[0].bytesPerRow;
    
    final img.Image rgbImage = img.Image(width: width, height: height);
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * yStride + x;
        if (yIndex < yBytes.length) {
          final int yValue = yBytes[yIndex];
          rgbImage.setPixelRgb(x, y, yValue, yValue, yValue);
        } else {
          rgbImage.setPixelRgb(x, y, 0, 0, 0);
        }
      }
    }
    
    return rgbImage;
  } catch (e) {
    print('❌ [Isolate] 폴백 변환 실패: $e');
    return null;
  }
}

/// Isolate에서 RGB 클램프
int _clampRGBInIsolate(int value) {
  return math.max(0, math.min(255, value));
}

/// 백그라운드에서 바코드 처리 (현재 사용하지 않음 - ML Kit Isolate 제한)
Future<BarcodeProcessResult?> _processBarcodeInIsolate(BarcodeProcessData data) async {
  // ML Kit은 Isolate에서 사용할 수 없으므로 더미 함수
  return BarcodeProcessResult.failure('Isolate에서 ML Kit 사용 불가');
}

/// Isolate에서 InputImage 생성 (현재 사용하지 않음)
InputImage? _createInputImageInIsolate(CameraImage cameraImage, CameraDescription cameraDescription) {
  // 더미 함수
  return null;
}