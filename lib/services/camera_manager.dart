import 'package:mobile_scanner/mobile_scanner.dart';

class CameraManager {
  MobileScannerController? _controller;

  bool get isInitialized => _controller != null;
  MobileScannerController? get controller => _controller;

  /// 카메라 초기화 (MobileScanner만 사용, permission_handler 제거)
  Future<CameraInitResult> initializeCamera() async {
    try {
      print('🔍 카메라 초기화 시작');

      // 기존 컨트롤러 정리
      await dispose();

      print('🆕 MobileScannerController 생성');
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );

      print('🎥 카메라 시작');
      await _controller!.start();

      // 카메라 안정화 대기
      await Future.delayed(const Duration(milliseconds: 1000));

      print('✅ 카메라 초기화 완료');
      return CameraInitResult.success();

    } catch (e) {
      print('❌ 카메라 시작 실패: $e');
      await dispose();

      // 에러 메시지로 권한 문제 판단
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('permission') || 
          errorStr.contains('denied') ||
          errorStr.contains('access') ||
          errorStr.contains('authorized')) {
        print('🚫 권한 문제로 판단됨');
        return CameraInitResult.permissionDenied();
      }

      return CameraInitResult.error('카메라를 사용할 수 없습니다: $e');
    }
  }

  void toggleFlash() {
    try {
      if (_controller != null) {
        print('💡 플래시 토글');
        _controller!.toggleTorch();
      } else {
        print('⚠️ 카메라가 초기화되지 않음');
      }
    } catch (e) {
      print('❌ 플래시 토글 오류: $e');
    }
  }

  Future<void> dispose() async {
    if (_controller != null) {
      print('🗑️ 카메라 컨트롤러 정리');
      try {
        await _controller!.dispose();
      } catch (e) {
        print('⚠️ 컨트롤러 정리 오류: $e');
      } finally {
        _controller = null;
      }
    }
  }
}

/// 카메라 초기화 결과 클래스 (단순화)
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
        errorMessage: '카메라 권한이 필요합니다. 설정에서 권한을 허용해주세요.',
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