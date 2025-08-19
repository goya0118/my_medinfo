import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraViewWidget extends StatelessWidget {
  final CameraController? controller;
  final bool cameraInitialized;
  final bool permissionDenied;
  final bool isLoading;
  final bool isScanning;
  final String? errorMessage;
  final VoidCallback onRestartCamera;

  const CameraViewWidget({
    super.key,
    required this.controller,
    required this.cameraInitialized,
    required this.permissionDenied,
    required this.isLoading,
    required this.isScanning,
    required this.errorMessage,
    required this.onRestartCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            // 카메라 뷰 (올바른 비율로)
            if (controller != null && cameraInitialized && controller!.value.isInitialized)
              _buildCameraPreview()
            else
              _buildPlaceholderView(),
            
            // 스캔 가이드 (선택적으로 표시)
            if (cameraInitialized) _buildScanGuide(),
            
            // 로딩 오버레이
            if (isLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: FittedBox(
        fit: BoxFit.cover, // 전체 영역을 채우도록
        child: SizedBox(
          width: controller!.value.previewSize!.height,
          height: controller!.value.previewSize!.width,
          child: CameraPreview(controller!),
        ),
      ),
    );
  }

  Widget _buildPlaceholderView() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (permissionDenied) ...[
              const Icon(
                Icons.camera_alt_outlined,
                color: Colors.white54,
                size: 64,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  errorMessage ?? '카메라 권한이 필요합니다',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => openAppSettings(),
                icon: const Icon(Icons.settings),
                label: const Text('설정에서 권한 허용'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ] else if (errorMessage != null) ...[
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onRestartCamera,
                child: const Text('다시 시도'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ] else ...[
              const SpinKitFadingCircle(
                color: Colors.white,
                size: 50.0,
              ),
              const SizedBox(height: 16),
              const Text(
                '카메라를 준비하는 중...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScanGuide() {
    // 시각장애인용 앱이므로 스캔 가이드는 간단하게 또는 제거
    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(
            color: isScanning ? Colors.green : Colors.orange,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '바코드 또는 알약',
            style: TextStyle(
              color: isScanning ? Colors.green : Colors.orange,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
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
    );
  }
}