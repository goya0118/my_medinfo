import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:pytorch_mobile/pytorch_mobile.dart';
import 'package:pytorch_mobile/model.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:pytorch_mobile/enums/dtype.dart';

class CameraManager {
  // Camera 컨트롤러
  CameraController? _cameraController;
  
  // ML Kit 바코드 스캐너
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  
  // PyTorch Mobile 모델
  Model? _pillModel;
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
  
  bool get isInitialized => _cameraController?.value.isInitialized == true;
  CameraController? get cameraController => _cameraController;

  /// 통합 카메라 초기화
  Future<CameraInitResult> initializeCamera() async {
    try {
      print('🔍 Camera + ML Kit 통합 카메라 초기화 시작');
      
      // 기존 정리
      await dispose();
      
      // 1. PyTorch 모델 로드 (알약 인식용)
      await _loadPyTorchModel();
      
      // 2. Camera 초기화
      await _initializeCamera();
      
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
    
    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    
    await _cameraController!.initialize();
    
    // 초기화 후 잠깐 대기
    await Future.delayed(Duration(milliseconds: 500));
    
    print('✅ Camera 초기화 완료 (해상도: ${_cameraController!.value.previewSize})');
  }

  /// PyTorch Mobile 모델 로드
  Future<void> _loadPyTorchModel() async {
    try {
      print('🤖 PyTorch Mobile 모델 로딩');
      
      _pillModel = await PyTorchMobile.loadModel('assets/models/pill_classifier_mobile.pt');
      print('✅ PyTorch 모델 로드 완료');
      
      final modelInfoString = await rootBundle.loadString('assets/models/model_info.json');
      _modelInfo = json.decode(modelInfoString);
      print('✅ 모델 정보 로드 완료');
      
      final labelsString = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelsString.trim().split('\n');
      print('✅ 라벨 로드 완료: ${_labels!.length}개 클래스');
      
    } catch (e) {
      print('❌ PyTorch 모델 로드 실패: $e');
      throw e;
    }
  }

  /// 통합 인식 시작 (바코드 + 알약)
  void startDetection({
    Function(String)? onBarcodeDetected,
    Function(PillClassificationResult?)? onPillDetected,
  }) {
    _onBarcodeDetected = onBarcodeDetected;
    _onPillDetected = onPillDetected;
    
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('⚠️ 카메라가 초기화되지 않음');
      return;
    }

    print('🔄 통합 인식 시작 (바코드: ${onBarcodeDetected != null}, 알약: ${onPillDetected != null})');
    _isBarcodeDetectionActive = onBarcodeDetected != null;
    _isPillDetectionActive = onPillDetected != null;
    _lastPillDetectionTime = null;
    _lastBarcodeDetectionTime = null;
    
    // 이미지 스트림 시작
    _startImageStream();
  }

  /// 이미지 스트림 시작 (1초 간격으로 처리)
  void _startImageStream() {
    if (_isImageStreamActive) return;
    
    print('📸 이미지 스트림 시작');
    _isImageStreamActive = true;
    
    _cameraController!.startImageStream((CameraImage image) async {
      if (!_isImageStreamActive) return;
      
      final now = DateTime.now();
      
      // 1초 간격으로 처리 (성능 최적화)
      if (_lastPillDetectionTime != null && 
          now.difference(_lastPillDetectionTime!).inMilliseconds < 1000) {
        return;
      }
      
      _lastPillDetectionTime = now;
      
      // 백그라운드에서 처리 (UI 블로킹 방지)
      Future.microtask(() async {
        await _processImage(image);
      });
    });
  }

  /// 이미지 처리 (바코드 + 알약)
  Future<void> _processImage(CameraImage cameraImage) async {
    try {
      // 1. 바코드 인식 (ML Kit)
      if (_isBarcodeDetectionActive && !_isBarcodeDetectionRunning) {
        await _detectBarcode(cameraImage);
      }
      
      // 2. 알약 인식 (PyTorch)
      if (_isPillDetectionActive && !_isPillDetectionRunning) {
        await _detectPill(cameraImage);
      }
      
    } catch (e) {
      print('❌ 이미지 처리 오류: $e');
    }
  }

  /// ML Kit 바코드 인식
  Future<void> _detectBarcode(CameraImage cameraImage) async {
    if (_isBarcodeDetectionRunning) return;
    
    _isBarcodeDetectionRunning = true;
    
    try {
      // CameraImage를 InputImage로 변환
      final inputImage = _cameraImageToInputImage(cameraImage);
      if (inputImage == null) return;
      
      // ML Kit 바코드 스캔
      final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);
      
      if (barcodes.isNotEmpty && _onBarcodeDetected != null) {
        final barcode = barcodes.first;
        if (barcode.rawValue != null) {
          print('📦 바코드 감지: ${barcode.rawValue}');
          _onBarcodeDetected!(barcode.rawValue!);
        }
      }
      
    } catch (e) {
      print('❌ 바코드 인식 오류: $e');
    } finally {
      _isBarcodeDetectionRunning = false;
    }
  }

  /// PyTorch 알약 인식
  Future<void> _detectPill(CameraImage cameraImage) async {
    if (_isPillDetectionRunning || _pillModel == null) return;
    
    _isPillDetectionRunning = true;
    
    try {
      print('🔍 알약 인식 시작');
      
      // CameraImage를 List<double>로 변환
      final inputDoubleList = await _preprocessCameraImage(cameraImage);
      
      if (inputDoubleList != null) {
        print('✅ 전처리 완료, PyTorch 추론 시작');
        
        // PyTorch Mobile 0.2.2 추론 (List<double> 사용)
        try {
          print('📊 입력 데이터 타입: ${inputDoubleList.runtimeType}');
          print('📊 입력 데이터 크기: ${inputDoubleList.length}');
          
          final targetWidth = _modelInfo!['input_width'] as int;
          final targetHeight = _modelInfo!['input_height'] as int;
          
          // PyTorch 입력 형태: [배치크기, 채널, 높이, 너비]
          final shape = [1, 3, targetHeight, targetWidth]; // [1, 3, 224, 224] 등
          print('📊 입력 형태: $shape');
          
          final dynamic rawPrediction = await _pillModel!.getPrediction(
            inputDoubleList,
            shape,
            DType.float32,
          );
          
          print('📊 원본 예측 결과 타입: ${rawPrediction.runtimeType}');
          print('📊 원본 예측 결과: $rawPrediction');
          
          if (rawPrediction != null) {
            final result = _processPredictionSafe(rawPrediction);
            if (result != null && _onPillDetected != null) {
              print('🎯 알약 인식 성공: ${result.className} (${(result.confidence * 100).toStringAsFixed(1)}%)');
              _onPillDetected!(result);
            } else {
              print('📉 신뢰도 부족 또는 인식 실패');
            }
          } else {
            print('❌ PyTorch 예측 결과가 null');
          }
          
        } catch (pytorchError) {
          print('❌ PyTorch 추론 오류: $pytorchError');
          print('❌ PyTorch 오류 타입: ${pytorchError.runtimeType}');
        }
        
      } else {
        print('❌ 전처리 실패 - inputDoubleList가 null');
      }
      
    } catch (e) {
      print('❌ 알약 인식 전체 오류: $e');
      print('❌ 스택 트레이스: ${StackTrace.current}');
    } finally {
      _isPillDetectionRunning = false;
    }
  }

  /// 안전한 예측 결과 처리 (Softmax + 엄격한 임계값)
  PillClassificationResult? _processPredictionSafe(dynamic prediction) {
    try {
      print('🔍 예측 결과 처리 시작 - 타입: ${prediction.runtimeType}');
      
      List<double> logits = <double>[];
      
      // 다양한 타입에 대한 안전한 처리
      if (prediction is List<double>) {
        logits = prediction;
        print('✅ List<double> 타입 확인');
      } else if (prediction is List<num>) {
        logits = prediction.map<double>((e) => e.toDouble()).toList();
        print('✅ List<num> → List<double> 변환');
      } else if (prediction is List<int>) {
        logits = prediction.map<double>((e) => e.toDouble()).toList();
        print('✅ List<int> → List<double> 변환');
      } else if (prediction is List) {
        // List<dynamic> 또는 기타 List 타입
        logits = <double>[];
        for (var item in prediction) {
          if (item is num) {
            logits.add(item.toDouble());
          } else if (item is String) {
            final parsed = double.tryParse(item);
            logits.add(parsed ?? 0.0);
          } else {
            logits.add(0.0);
          }
        }
        print('✅ List<dynamic> → List<double> 변환 (${logits.length}개)');
      } else {
        print('❌ 지원하지 않는 예측 결과 타입: ${prediction.runtimeType}');
        return null;
      }
      
      print('📊 Raw logits: ${logits.take(5).toList()}...'); // 처음 5개만 출력
      
      if (logits.isNotEmpty) {
        // Softmax 적용하여 확률로 변환
        final probabilities = _applySoftmax(logits);
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
        print('❌ logits 배열이 비어있음');
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

  /// CameraImage를 InputImage로 변환 (ML Kit용)
  InputImage? _cameraImageToInputImage(CameraImage cameraImage) {
    try {
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
      
      // InputImageFormat 설정
      final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw);
      if (format == null) return null;
      
      // Plane 데이터 설정
      final planeData = cameraImage.planes.map((plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: cameraImage.height,
          width: cameraImage.width,
        );
      }).toList();
      
      // InputImageData 생성
      final inputImageData = InputImageData(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        imageRotation: rotation,
        inputImageFormat: format,
        planeData: planeData,
      );
      
      // 첫 번째 plane의 bytes 사용
      final allBytes = WriteBuffer();
      for (final plane in cameraImage.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();
      
      return InputImage.fromBytes(
        bytes: bytes,
        inputImageData: inputImageData,
      );
      
    } catch (e) {
      print('❌ InputImage 변환 실패: $e');
      return null;
    }
  }

  /// CameraImage 전처리 (List<double> 출력)
  Future<List<double>?> _preprocessCameraImage(CameraImage cameraImage) async {
    try {
      print('🔍 전처리 시작 - 이미지 크기: ${cameraImage.width}x${cameraImage.height}');
      
      final int width = cameraImage.width;
      final int height = cameraImage.height;
      
      // 모델 정보 확인
      final targetWidth = _modelInfo!['input_width'] as int;
      final targetHeight = _modelInfo!['input_height'] as int;
      
      print('🎯 타겟 크기: ${targetWidth}x${targetHeight}');
      
      // Y 채널(밝기)만 사용해서 List<double>로 변환
      final yBytes = cameraImage.planes[0].bytes;
      print('📊 Y 채널 크기: ${yBytes.length} bytes');
      
      // List<double> 생성 (0.0-1.0 범위)
      final doubleList = _convertToDoubleList(
        yBytes, 
        width, 
        height, 
        targetWidth, 
        targetHeight,
      );
      
      print('✅ 전처리 완료 - Double 리스트 크기: ${doubleList.length}');
      return doubleList;
      
    } catch (e) {
      print('❌ 전처리 실패: $e');
      print('❌ 스택 트레이스: ${StackTrace.current}');
      return null;
    }
  }

  /// Y 채널을 List<double>로 변환 (ImageNet 정규화 적용)
  List<double> _convertToDoubleList(
    Uint8List yData,
    int originalWidth,
    int originalHeight,
    int targetWidth,
    int targetHeight,
  ) {
    print('🔄 Double 리스트 변환 시작: ${originalWidth}x${originalHeight} → ${targetWidth}x${targetHeight}');
    
    // ImageNet 정규화 값 가져오기
    final mean = (_modelInfo!['mean'] as List).cast<double>();
    final std = (_modelInfo!['std'] as List).cast<double>();
    print('📊 ImageNet 정규화 - mean: $mean, std: $std');
    
    // Double 리스트 생성 (targetWidth * targetHeight * 3)
    final doubleList = <double>[];
    
    final scaleX = originalWidth / targetWidth;
    final scaleY = originalHeight / targetHeight;
    
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
          
          doubleList.add(normalizedValue);
        }
      }
    }
    
    print('✅ Double 리스트 변환 완료 - 크기: ${doubleList.length}');
    print('📊 정규화 샘플 값: ${doubleList.take(3).map((v) => v.toStringAsFixed(3)).toList()}');
    return doubleList;
  }

  /// YUV420 → RGB 변환
  Future<List<List<List<int>>>> _convertYUV420ToRGB(CameraImage cameraImage) async {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    
    final Uint8List yPlane = cameraImage.planes[0].bytes;
    final Uint8List uvPlane = cameraImage.planes[1].bytes;
    
    // 명시적 타입 지정으로 문제 해결
    List<List<List<int>>> rgbImage = List<List<List<int>>>.generate(
      height,
      (y) => List<List<int>>.generate(
        width,
        (x) => List<int>.filled(3, 0), // [0, 0, 0] 대신 filled 사용
      ),
    );
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * width + x;
        
        // 안전한 인덱스 체크
        if (yIndex >= yPlane.length) continue;
        
        final int yValue = yPlane[yIndex];
        
        final int uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);
        
        // UV 플레인 안전한 접근
        int uValue = 128, vValue = 128; // 기본값
        if (uvIndex * 2 + 1 < uvPlane.length) {
          uValue = uvPlane[uvIndex * 2];
          vValue = uvPlane[uvIndex * 2 + 1];
        }
        
        final int r = (yValue + 1.13983 * (vValue - 128)).round().clamp(0, 255);
        final int g = (yValue - 0.39465 * (uValue - 128) - 0.58060 * (vValue - 128)).round().clamp(0, 255);
        final int b = (yValue + 2.03211 * (uValue - 128)).round().clamp(0, 255);
        
        // 직접 인덱스 할당
        rgbImage[y][x][0] = r;
        rgbImage[y][x][1] = g;
        rgbImage[y][x][2] = b;
      }
    }
    
    return rgbImage;
  }

  /// 리사이즈 및 정규화
  Float32List _resizeAndNormalize(
    List<List<List<int>>> rgbImage,
    int originalWidth,
    int originalHeight,
    int targetWidth,
    int targetHeight,
    List<double> mean,
    List<double> std,
  ) {
    final List<double> processedData = [];
    
    final double scaleX = originalWidth / targetWidth;
    final double scaleY = originalHeight / targetHeight;
    
    for (int c = 0; c < 3; c++) {
      for (int y = 0; y < targetHeight; y++) {
        for (int x = 0; x < targetWidth; x++) {
          final int sourceX = (x * scaleX).round().clamp(0, originalWidth - 1);
          final int sourceY = (y * scaleY).round().clamp(0, originalHeight - 1);
          
          final int pixelValue = rgbImage[sourceY][sourceX][c];
          final double normalizedValue = (pixelValue / 255.0 - mean[c]) / std[c];
          
          processedData.add(normalizedValue);
        }
      }
    }
    
    return Float32List.fromList(processedData);
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
    
    if (_isImageStreamActive) {
      _isImageStreamActive = false;
      try {
        _cameraController?.stopImageStream();
      } catch (e) {
        print('⚠️ 이미지 스트림 중지 오류: $e');
      }
    }
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
      await _barcodeScanner.close();
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
    
    _pillModel = null;
    _labels = null;
    _modelInfo = null;
    _onBarcodeDetected = null;
    _onPillDetected = null;
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