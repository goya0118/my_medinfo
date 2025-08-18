import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

class CameraManager {
  MobileScannerController? _controller;
  
  bool get isInitialized => _controller != null;
  MobileScannerController? get controller => _controller;

  /// 카메라 직접 초기화 (권한 처리 간소화)
  Future<CameraInitResult> initializeCamera() async {
    try {
      print('🔍 카메라 초기화 시작');
      
      // 기존 컨트롤러 정리
      await dispose();
      
      // MobileScanner가 내부적으로 권한을 처리하도록 함
      print('🆕 MobileScannerController 생성');
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
      
      print('🎥 카메라 시작');
      await _controller!.start();
      
      // 짧은 대기로 안정화
      await Future.delayed(const Duration(milliseconds: 500));
      
      print('✅ 카메라 초기화 완료');
      return CameraInitResult.success();
      
    } catch (e) {
      print('❌ 카메라 시작 실패: $e');
      await dispose();
      
      final errorMessage = e.toString().toLowerCase();
      
      // 권한 관련 에러인지 확인
      if (_isPermissionError(errorMessage)) {
        print('🚫 권한 문제 감지');
        
        // permission_handler로 실제 권한 상태 확인
        final permissionStatus = await Permission.camera.status;
        print('📋 실제 권한 상태: $permissionStatus');
        
        if (permissionStatus.isPermanentlyDenied) {
          return CameraInitResult.permanentlyDenied();
        } else {
          return CameraInitResult.permissionDenied();
        }
      } else {
        return CameraInitResult.error('카메라를 사용할 수 없습니다: $e');
      }
    }
  }

  /// 권한 요청 (간소화)
  Future<bool> requestPermission() async {
    try {
      print('📝 카메라 권한 요청');
      final status = await Permission.camera.request();
      print('📋 권한 요청 결과: $status');
      return status.isGranted || status.isLimited;
    } catch (e) {
      print('❌ 권한 요청 실패: $e');
      return false;
    }
  }

  /// 권한 상태만 확인 (요청하지 않음)
  Future<PermissionStatus> checkPermissionStatus() async {
    try {
      return await Permission.camera.status;
    } catch (e) {
      print('❌ 권한 상태 확인 실패: $e');
      return PermissionStatus.denied;
    }
  }

  /// 에러 메시지가 권한 관련인지 확인
  bool _isPermissionError(String errorMessage) {
    final permissionKeywords = [
      'permission',
      'denied',
      'authorized',
      'access',
      'camera',
      'not permitted',
      'unauthorized',
      'not available'
    ];
    
    return permissionKeywords.any((keyword) => errorMessage.contains(keyword));
  }

  /// 시스템 설정으로 이동
  Future<bool> openAppSettings() async {
    try {
      print('⚙️ 앱 설정으로 이동');
      return await openAppSettings();
    } catch (e) {
      print('❌ 설정 이동 실패: $e');
      return false;
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
        print('⚠️ 컨트롤러 정리 중 오류: $e');
      } finally {
        _controller = null;
      }
    }
  }
}

/// 카메라 초기화 결과 클래스 (간소화)
class CameraInitResult {
  final bool isSuccess;
  final bool isPermissionDenied;
  final bool isPermanentlyDenied;
  final String? errorMessage;

  CameraInitResult._({
    required this.isSuccess,
    required this.isPermissionDenied,
    required this.isPermanentlyDenied,
    this.errorMessage,
  });

  factory CameraInitResult.success() => CameraInitResult._(
        isSuccess: true,
        isPermissionDenied: false,
        isPermanentlyDenied: false,
      );

  factory CameraInitResult.permissionDenied() => CameraInitResult._(
        isSuccess: false,
        isPermissionDenied: true,
        isPermanentlyDenied: false,
        errorMessage: '카메라 권한이 필요합니다',
      );

  factory CameraInitResult.permanentlyDenied() => CameraInitResult._(
        isSuccess: false,
        isPermissionDenied: true,
        isPermanentlyDenied: true,
        errorMessage: '설정에서 카메라 권한을 허용해주세요',
      );

  factory CameraInitResult.error(String message) => CameraInitResult._(
        isSuccess: false,
        isPermissionDenied: false,
        isPermanentlyDenied: false,
        errorMessage: message,
      );

  /// 사용자에게 보여줄 메시지
  String getUserMessage() {
    if (isSuccess) return '카메라가 준비되었습니다';
    return errorMessage ?? '카메라 초기화에 실패했습니다';
  }

  /// 설정으로 이동할지 여부
  bool get shouldOpenSettings => isPermanentlyDenied;
  
  /// 권한 재요청할지 여부  
  bool get canRetryPermission => isPermissionDenied && !isPermanentlyDenied;
}