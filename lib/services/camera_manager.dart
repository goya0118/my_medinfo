import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart'; // HapticFeedback용
import 'dart:typed_data';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

class CameraManager {
  // Camera 컨트롤러
  CameraController? _cameraController;
  
  // ML Kit 바코드 스캐너
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  
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
  
  // 각각 독립적인 마지막 처리 시간 (1초 간격 처리)
  DateTime? _lastPillDetectionTime;
  DateTime? _lastBarcodeDetectionTime;
  
  // 진동 관련
  Timer? _vibrationTimer;
  bool _isVibrationEnabled = true;
  
  bool get isInitialized => _cameraController?.value.isInitialized == true;
  CameraController? get cameraController => _cameraController;

  /// 통합 카메라 초기화
  Future<CameraInitResult> initializeCamera() async {
    try {
      print('🔍 Camera + ML Kit + TensorFlow Lite 통합 카메라 초기화 시작');
      
      // 기존 정리
      await dispose();
      
      // 1. TensorFlow Lite 모델 로드 (알약 인식용)
      await _loadTensorFlowLiteModel();
      
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
    
    // Android에서 ML Kit 호환성을 위해 NV21 포맷 사용
    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21, // YUV420 대신 NV21 사용
    );
    
    await _cameraController!.initialize();
    
    // 초기화 후 잠깐 대기
    await Future.delayed(Duration(milliseconds: 500));
    
    print('✅ Camera 초기화 완료 (해상도: ${_cameraController!.value.previewSize})');
    print('📱 이미지 포맷: ${_cameraController!.value.description}');
  }

  /// TensorFlow Lite 모델 로드
  Future<void> _loadTensorFlowLiteModel() async {
    try {
      print('🤖 TensorFlow Lite 모델 로딩');
      
      // 모델 정보 먼저 로드
      final modelInfoString = await rootBundle.loadString('assets/models/model_info.json');
      _modelInfo = json.decode(modelInfoString);
      print('✅ 모델 정보 로드 완료');
      
      final labelsString = await rootBundle.loadString('assets/models/labels.txt');
      _labels = labelsString.trim().split('\n');
      print('✅ 라벨 로드 완료: ${_labels!.length}개 클래스');
      
      // TensorFlow Lite 모델 로드
      _pillModel = await Interpreter.fromAsset('assets/models/pill_classifier_mobile.tflite');
      
      // 모델 입출력 정보 확인
      final inputTensors = _pillModel!.getInputTensors();
      final outputTensors = _pillModel!.getOutputTensors();
      
      print('✅ TensorFlow Lite 모델 로드 완료');
      print('📊 입력 텐서: ${inputTensors.first.shape}');
      print('📊 출력 텐서: ${outputTensors.first.shape}');
      
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
  }) {
    _onBarcodeDetected = onBarcodeDetected;
    _onPillDetected = onPillDetected;
    _isVibrationEnabled = enableVibration;
    
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('⚠️ 카메라가 초기화되지 않음');
      return;
    }

    print('🔄 통합 인식 시작 (바코드: ${onBarcodeDetected != null}, 알약: ${onPillDetected != null})');
    _isBarcodeDetectionActive = onBarcodeDetected != null;
    _isPillDetectionActive = onPillDetected != null;
    
    // 각각 독립적인 타이머 초기화
    _lastPillDetectionTime = null;
    _lastBarcodeDetectionTime = null;
    
    // 이미지 스트림 시작
    _startImageStream();
    
    // 인식 중 진동 시작 (1초마다)
    if (_isVibrationEnabled) {
      _startRecognitionVibration();
    }
  }

  /// 인식 중 진동 (1초마다 짧은 진동)
  void _startRecognitionVibration() {
    _stopRecognitionVibration(); // 기존 타이머 정리
    
    _vibrationTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_isPillDetectionActive || _isBarcodeDetectionActive) {
        _vibrateLightly(); // 짧은 진동
      } else {
        timer.cancel();
      }
    });
  }

  /// 인식 중 진동 중지
  void _stopRecognitionVibration() {
    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }

  /// 짧은 진동 (인식 중) - HapticFeedback 사용
  Future<void> _vibrateLightly() async {
    try {
      await HapticFeedback.lightImpact(); // 가벼운 진동
    } catch (e) {
      print('⚠️ 진동 실행 오류: $e');
    }
  }

  /// 강한 진동 (인식 완료) - 2번 연속
  Future<void> _vibrateSuccess() async {
    try {
      await HapticFeedback.heavyImpact(); // 강한 진동
      await Future.delayed(Duration(milliseconds: 200)); // 200ms 간격
      await HapticFeedback.heavyImpact(); // 강한 진동
    } catch (e) {
      print('⚠️ 성공 진동 실행 오류: $e');
    }
  }

  /// 이미지 스트림 시작 (최적화된 처리 간격)
  void _startImageStream() {
    if (_isImageStreamActive) return;
    
    print('📸 이미지 스트림 시작');
    _isImageStreamActive = true;
    
    _cameraController!.startImageStream((CameraImage image) async {
      if (!_isImageStreamActive) return;
      
      // 백그라운드에서 처리 (UI 블로킹 방지)
      Future.microtask(() async {
        await _processImage(image);
      });
    });
  }

  /// 이미지 처리 (바코드 + 알약) - 각각 독립적인 1초 간격
  Future<void> _processImage(CameraImage cameraImage) async {
    try {
      final now = DateTime.now();
      
      // 1. 바코드 인식 (독립적인 1초 간격)
      if (_isBarcodeDetectionActive && !_isBarcodeDetectionRunning) {
        if (_lastBarcodeDetectionTime == null || 
            now.difference(_lastBarcodeDetectionTime!).inMilliseconds >= 1000) {
          _lastBarcodeDetectionTime = now;
          await _detectBarcode(cameraImage);
        }
      }
      
      // 2. 알약 인식 (독립적인 1초 간격)
      if (_isPillDetectionActive && !_isPillDetectionRunning) {
        if (_lastPillDetectionTime == null || 
            now.difference(_lastPillDetectionTime!).inMilliseconds >= 1000) {
          _lastPillDetectionTime = now;
          await _detectPill(cameraImage);
        }
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
          
          // 성공 진동 실행
          if (_isVibrationEnabled) {
            await _vibrateSuccess();
          }
          
          _onBarcodeDetected!(barcode.rawValue!);
        }
      }
      
    } catch (e) {
      print('❌ 바코드 인식 오류: $e');
    } finally {
      _isBarcodeDetectionRunning = false;
    }
  }

  /// TensorFlow Lite 알약 인식
  Future<void> _detectPill(CameraImage cameraImage) async {
    if (_isPillDetectionRunning || _pillModel == null) return;
    
    _isPillDetectionRunning = true;
    
    try {
      print('🔍 알약 인식 시작');
      
      // CameraImage를 Float32List로 변환 (TensorFlow Lite용)
      final inputData = await _preprocessImageForTFLite(cameraImage);
      
      if (inputData != null) {
        print('✅ 이미지 전처리 완료, TensorFlow Lite 추론 시작');
        
        try {
          // TensorFlow Lite 추론
          final outputData = await _runTFLiteInference(inputData);
          
          if (outputData != null && _onPillDetected != null) {
            final result = _processTFLiteOutput(outputData);
            
            if (result != null) {
              // 엄격한 임계값 적용 (90% 이상)
              if (result.confidence > 0.9) {
                print('🎯 알약 인식 성공: ${result.className} (${(result.confidence * 100).toStringAsFixed(1)}%)');
                
                // 성공 진동 실행
                if (_isVibrationEnabled) {
                  await _vibrateSuccess();
                }
                
                _onPillDetected!(result);
              } else {
                print('📉 신뢰도 부족: ${(result.confidence * 100).toStringAsFixed(1)}%');
              }
            } else {
              print('❌ 결과 처리 실패');
            }
          } else {
            print('❌ TensorFlow Lite 추론 결과가 null');
          }
          
        } catch (tfliteError) {
          print('❌ TensorFlow Lite 추론 오류: $tfliteError');
        }
        
      } else {
        print('❌ 이미지 전처리 실패');
      }
      
    } catch (e) {
      print('❌ 알약 인식 전체 오류: $e');
    } finally {
      _isPillDetectionRunning = false;
    }
  }

  /// 이미지 전처리 (TensorFlow Lite용)
  Future<Float32List?> _preprocessImageForTFLite(CameraImage cameraImage) async {
    try {
      // 모델 정보에서 입력 크기 가져오기
      final targetWidth = _modelInfo!['input_width'] as int? ?? 224;
      final targetHeight = _modelInfo!['input_height'] as int? ?? 224;
      final mean = (_modelInfo!['mean'] as List?)?.cast<double>() ?? [0.485, 0.456, 0.406];
      final std = (_modelInfo!['std'] as List?)?.cast<double>() ?? [0.229, 0.224, 0.225];
      
      print('🔍 전처리 시작 - 타겟 크기: ${targetWidth}x${targetHeight}');
      
      // YUV420을 RGB로 변환
      final rgbBytes = await _convertYUV420ToRGBBytes(cameraImage);
      
      // RGB 데이터를 정규화된 Float32List로 변환
      final inputData = _normalizeAndResize(
        rgbBytes, 
        cameraImage.width, 
        cameraImage.height,
        targetWidth, 
        targetHeight,
        mean,
        std
      );
      
      print('✅ 전처리 완료 - 데이터 크기: ${inputData.length}');
      return inputData;
      
    } catch (e) {
      print('❌ 전처리 실패: $e');
      return null;
    }
  }

  /// RGB 데이터 정규화 및 리사이즈
  Float32List _normalizeAndResize(
    Uint8List rgbData,
    int originalWidth,
    int originalHeight,
    int targetWidth,
    int targetHeight,
    List<double> mean,
    List<double> std
  ) {
    final Float32List result = Float32List(targetHeight * targetWidth * 3);
    
    final double scaleX = originalWidth / targetWidth;
    final double scaleY = originalHeight / targetHeight;
    
    int resultIndex = 0;
    
    for (int y = 0; y < targetHeight; y++) {
      for (int x = 0; x < targetWidth; x++) {
        // 원본 좌표 계산
        final int sourceX = (x * scaleX).round().clamp(0, originalWidth - 1);
        final int sourceY = (y * scaleY).round().clamp(0, originalHeight - 1);
        final int sourceIndex = (sourceY * originalWidth + sourceX) * 3;
        
        // RGB 값 추출 및 정규화
        for (int c = 0; c < 3; c++) {
          if (sourceIndex + c < rgbData.length) {
            final double pixelValue = rgbData[sourceIndex + c] / 255.0;
            final double normalizedValue = (pixelValue - mean[c]) / std[c];
            result[resultIndex++] = normalizedValue;
          } else {
            result[resultIndex++] = (0.5 - mean[c]) / std[c]; // 기본값
          }
        }
      }
    }
    
    return result;
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
      
      // 출력 버퍼 준비 - 출력 텐서 모양에 맞게 2차원 배열로 준비
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
      
      // 대안: 1차원 출력으로 재시도
      try {
        print('🔄 1차원 출력으로 추론 재시도...');
        
        final inputTensor = _pillModel!.getInputTensors().first;
        final outputTensor = _pillModel!.getOutputTensors().first;
        
        // 입력을 4차원 배열로 직접 구성
        final inputShape = inputTensor.shape;
        final input = _createInputArray(inputData, inputShape);
        
        // 출력을 1차원 배열로 준비
        final outputShape = outputTensor.shape;
        final int totalOutputSize = outputShape.reduce((a, b) => a * b);
        final List<double> output = List.filled(totalOutputSize, 0.0);
        
        // 추론 실행
        _pillModel!.run(input, output);
        
        print('📊 1차원 출력 크기: ${output.length}');
        print('📊 1차원 출력 샘플: ${output.take(5).toList()}');
        
        return output;
        
      } catch (e2) {
        print('❌ 1차원 출력 방법도 실패: $e2');
        return null;
      }
    }
  }
  
  /// 입력 배열 생성 (4차원)
  List<List<List<List<double>>>> _createInputArray(Float32List data, List<int> shape) {
    final int batch = shape[0];
    final int height = shape[1]; 
    final int width = shape[2];
    final int channels = shape[3];
    
    final result = List.generate(batch, (b) =>
      List.generate(height, (h) =>
        List.generate(width, (w) =>
          List.generate(channels, (c) {
            final index = b * height * width * channels + 
                         h * width * channels + 
                         w * channels + c;
            return index < data.length ? data[index] : 0.0;
          })
        )
      )
    );
    
    return result;
  }

  /// TensorFlow Lite 출력 처리
  PillClassificationResult? _processTFLiteOutput(List<double> output) {
    try {
      if (output.isEmpty || _labels == null) {
        return null;
      }
      
      // Softmax 적용
      final probabilities = _applySoftmax(output);
      
      // 최고 확률의 클래스 찾기
      final maxIndex = _getMaxIndex(probabilities);
      final confidence = probabilities[maxIndex];
      
      print('📊 최고 신뢰도: ${(confidence * 100).toStringAsFixed(1)}% (인덱스: $maxIndex)');
      
      // 상위 2개 클래스 간 차이 확인
      final sortedProbs = [...probabilities]..sort((a, b) => b.compareTo(a));
      final confidenceDiff = sortedProbs[0] - sortedProbs[1];
      print('📊 1위-2위 차이: ${(confidenceDiff * 100).toStringAsFixed(1)}%');
      
      if (maxIndex < _labels!.length) {
        return PillClassificationResult(
          className: _labels![maxIndex],
          confidence: confidence,
          classIndex: maxIndex,
        );
      }
      
      return null;
      
    } catch (e) {
      print('❌ 출력 처리 실패: $e');
      return null;
    }
  }

  /// 카메라 포맷을 InputImageFormat으로 변환
  InputImageFormat _getInputImageFormat(int rawFormat) {
    switch (rawFormat) {
      case 35: // ImageFormat.YUV_420_888
        return InputImageFormat.yuv420;
      case 17: // ImageFormat.NV21
        return InputImageFormat.nv21;
      case 842094169: // ImageFormat.YUV_420_888 on some devices
        return InputImageFormat.yuv420;
      default:
        return InputImageFormat.nv21; // 기본값
    }
  }

  /// CameraImage를 InputImage로 변환 (ML Kit용) - 개선된 버전
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
      
      // 이미지 포맷 확인 및 설정
      final format = _getInputImageFormat(cameraImage.format.raw);
      print('📷 CameraImage 포맷: ${cameraImage.format.raw} -> $format');
      
      // 이미지 데이터 처리 방식 개선
      Uint8List imageBytes;
      
      if (cameraImage.format.group == ImageFormatGroup.nv21 || 
          cameraImage.format.raw == 17) {
        // NV21 포맷의 경우 첫 번째 plane만 사용
        imageBytes = cameraImage.planes[0].bytes;
        print('📷 NV21 포맷 사용 - bytes 크기: ${imageBytes.length}');
      } else {
        // 다른 포맷의 경우 모든 plane 합치기
        final allBytes = WriteBuffer();
        for (final plane in cameraImage.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        imageBytes = allBytes.done().buffer.asUint8List();
        print('📷 다른 포맷 사용 - 합친 bytes 크기: ${imageBytes.length}');
      }

      // InputImageMetadata 생성
      final inputImageData = InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: cameraImage.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(
        bytes: imageBytes,
        metadata: inputImageData,
      );
      
    } catch (e) {
      print('❌ InputImage 변환 실패: $e');
      
      // 대안: 더 간단한 방법으로 재시도
      try {
        print('🔄 단순 변환 방법으로 재시도...');
        
        // 가장 기본적인 방법으로 변환
        final bytes = cameraImage.planes[0].bytes;
        
        final inputImageData = InputImageMetadata(
          size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21, // 강제로 NV21 사용
          bytesPerRow: cameraImage.planes[0].bytesPerRow,
        );

        return InputImage.fromBytes(
          bytes: bytes,
          metadata: inputImageData,
        );
        
      } catch (e2) {
        print('❌ 단순 변환도 실패: $e2');
        return null;
      }
    }
  }

  /// YUV420을 RGB Uint8List로 변환 (플랫폼별 처리) - NV21 지원 추가
  Future<Uint8List> _convertYUV420ToRGBBytes(CameraImage cameraImage) async {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    
    final Uint8List yPlane = cameraImage.planes[0].bytes;
    
    // NV21 포맷 처리 (Android에서 주로 사용)
    if (cameraImage.format.group == ImageFormatGroup.nv21 || 
        cameraImage.format.raw == 17) {
      
      if (cameraImage.planes.length >= 2) {
        // NV21: Y plane + interleaved UV plane
        final Uint8List uvPlane = cameraImage.planes[1].bytes;
        return _convertNV21ToRGB(yPlane, uvPlane, width, height);
      } else {
        // Y plane만 있으면 그레이스케일로 처리
        return _convertGrayscaleToRGB(yPlane);
      }
    }
    
    // YUV420 포맷 처리
    if (cameraImage.planes.length < 3) {
      // Y 채널만 있다면 그레이스케일로 변환
      return _convertGrayscaleToRGB(yPlane);
    }
    
    final Uint8List uPlane = cameraImage.planes[1].bytes;
    final Uint8List vPlane = cameraImage.planes[2].bytes;
    
    // 플랫폼별 픽셀 스트라이드 처리
    int uvPixelStride = 1; // 기본값
    
    // Android: bytesPerPixel 사용 (pixelStride와 동일 개념)
    if (cameraImage.planes[1].bytesPerPixel != null) {
      uvPixelStride = cameraImage.planes[1].bytesPerPixel!;
      print('📱 Android 감지 - UV pixelStride: $uvPixelStride');
    } 
    // iOS: width/height 정보 활용
    else if (cameraImage.planes[1].width != null && cameraImage.planes[1].height != null) {
      uvPixelStride = 1; // iOS는 보통 연속적으로 저장
      print('🍎 iOS 감지 - UV 연속 저장 방식');
    }
    // 기타 플랫폼: bytesPerRow로 추정
    else {
      final int uvBytesPerRow = cameraImage.planes[1].bytesPerRow;
      uvPixelStride = uvBytesPerRow > (width ~/ 2) ? 2 : 1;
      print('🔧 기타 플랫폼 - UV pixelStride 추정: $uvPixelStride');
    }
    
    return _convertYUV420ToRGB(yPlane, uPlane, vPlane, width, height, uvPixelStride);
  }

  /// NV21을 RGB로 변환
  Uint8List _convertNV21ToRGB(Uint8List yPlane, Uint8List uvPlane, int width, int height) {
    final List<int> rgbBytes = [];
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * width + x;
        final int uvIndex = ((y ~/ 2) * (width ~/ 2) + (x ~/ 2)) * 2;
        
        // Y 값 (밝기)
        final int yValue = yIndex < yPlane.length ? yPlane[yIndex] : 128;
        
        // UV 값 (색차) - NV21은 V,U 순서로 interleaved
        int uValue = 128, vValue = 128; // 기본값
        
        if (uvIndex + 1 < uvPlane.length) {
          vValue = uvPlane[uvIndex];     // V (Cr)
          uValue = uvPlane[uvIndex + 1]; // U (Cb)
        }
        
        // YUV to RGB 변환
        final int r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
        final int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round().clamp(0, 255);
        final int b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);
        
        rgbBytes.addAll([r, g, b]);
      }
    }
    
    return Uint8List.fromList(rgbBytes);
  }

  /// YUV420을 RGB로 변환 (분리된 U, V plane)
  Uint8List _convertYUV420ToRGB(
    Uint8List yPlane, 
    Uint8List uPlane, 
    Uint8List vPlane, 
    int width, 
    int height, 
    int uvPixelStride
  ) {
    final List<int> rgbBytes = [];
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int yIndex = y * width + x;
        final int uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);
        
        // Y 값 (밝기)
        final int yValue = yIndex < yPlane.length ? yPlane[yIndex] : 128;
        
        // UV 값 (색차) - 플랫폼별 접근 방식
        int uValue = 128, vValue = 128; // 기본값 (중성 회색)
        
        final int uOffset = uvIndex * uvPixelStride;
        final int vOffset = uvIndex * uvPixelStride;
        
        if (uOffset < uPlane.length) {
          uValue = uPlane[uOffset];
        }
        if (vOffset < vPlane.length) {
          vValue = vPlane[vOffset];
        }
        
        // YUV to RGB 변환 (ITU-R BT.601 표준)
        final int r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
        final int g = (yValue - 0.344136 * (uValue - 128) - 0.714136 * (vValue - 128)).round().clamp(0, 255);
        final int b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);
        
        rgbBytes.addAll([r, g, b]);
      }
    }
    
    return Uint8List.fromList(rgbBytes);
  }

  /// 그레이스케일을 RGB로 변환 (Y 채널만 있을 때)
  Uint8List _convertGrayscaleToRGB(Uint8List yPlane) {
    final List<int> rgbBytes = [];
    
    for (int i = 0; i < yPlane.length; i++) {
      final int grayValue = yPlane[i];
      rgbBytes.addAll([grayValue, grayValue, grayValue]); // R=G=B
    }
    
    return Uint8List.fromList(rgbBytes);
  }

  /// Softmax 함수 (신뢰도 계산용)
  List<double> _applySoftmax(List<double> logits) {
    if (logits.isEmpty) return [];
    
    // 수치 안정성을 위해 최대값 빼기
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final expValues = logits.map((x) => math.exp(x - maxLogit)).toList();
    final sumExp = expValues.fold(0.0, (a, b) => a + b);
    
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
    
    // 진동 중지
    _stopRecognitionVibration();
    
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

  /// 진동 활성화/비활성화
  void setVibrationEnabled(bool enabled) {
    _isVibrationEnabled = enabled;
    if (!enabled) {
      _stopRecognitionVibration();
    } else if (_isPillDetectionActive || _isBarcodeDetectionActive) {
      _startRecognitionVibration();
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

// List reshape 확장 메서드  
extension ListReshape on List<double> {
  List<List<List<List<double>>>> reshape(List<int> shape) {
    if (shape.length != 4) {
      throw ArgumentError('Shape must have 4 dimensions');
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
            return index < length ? this[index] : 0.0;
          })
        )
      )
    );
    
    return result;
  }
}