import 'package:flutter/material.dart';
import '../../models/drug_info.dart';

class DrugInfoWidget extends StatelessWidget {
  final DrugInfo drugInfo;
  final String? lastScannedBarcode;

  const DrugInfoWidget({
    super.key,
    required this.drugInfo,
    this.lastScannedBarcode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            '📋 바코드: ${lastScannedBarcode ?? ""}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            drugInfo.itemName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          // --- 여기를 수정했습니다 ---
          if (drugInfo.engName?.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Text(
              // engName이 null일 경우 빈 문자열('')을 표시하도록 변경
              drugInfo.engName ?? '',
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.black87,
              ),
            ),
          ],
          // --- 수정 끝 ---
          
          if (drugInfo.company.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '제조사: ${drugInfo.company}',
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
    );
  }
}

class StatusMessageWidget extends StatelessWidget {
  final bool permissionDenied;
  final bool isScanning;
  final bool isLoading;
  final bool cameraInitialized;
  final String? errorMessage;

  const StatusMessageWidget({
    super.key,
    required this.permissionDenied,
    required this.isScanning,
    required this.isLoading,
    required this.cameraInitialized,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _getStatusMessage(),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _getTextColor(),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (permissionDenied) return Colors.red.shade100;
    if (isScanning) return Colors.green.shade100;
    return Colors.orange.shade100;
  }

  Color _getTextColor() {
    if (permissionDenied) return Colors.red.shade700;
    if (errorMessage != null) return Colors.red.shade700;
    if (isScanning) return Colors.green.shade700;
    return Colors.orange.shade700;
  }

  String _getStatusMessage() {
    if (permissionDenied) {
      return '📷 카메라 권한을 허용해주세요';
    }
    
    if (errorMessage != null) {
      return '❌ $errorMessage';
    }
    
    if (!cameraInitialized) {
      return '📷 카메라를 준비하는 중입니다...';
    }
    
    if (isScanning) {
      return '🔍 바코드를 스캔 영역에 맞춰주세요';
    }
    
    if (isLoading) {
      return '⏳ 의약품 정보를 조회하는 중...';
    }
    
    return '✅ 스캔 완료! 3초 후 다시 스캔됩니다';
  }
}

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
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
    );
  }
}