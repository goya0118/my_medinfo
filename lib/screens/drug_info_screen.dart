import 'package:flutter/material.dart';
import '../models/drug_info.dart';

class DrugInfoScreen extends StatelessWidget {
  final DrugInfo drugInfo;
  final String barcode;

  const DrugInfoScreen({
    super.key,
    required this.drugInfo,
    required this.barcode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💊 의약품 정보'),
        backgroundColor: Colors.blue.shade100,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: 공유 기능 추가
            },
          ),
        ],
      ),
      // body에는 스크롤 가능한 정보 카드만 넣음
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 메인 정보 카드
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      icon: Icons.medication,
                      iconColor: Colors.blue.shade600,
                      iconBackgroundColor: Colors.blue.shade50,
                      label: '의약품명',
                      value: drugInfo.itemName,
                      englishValue: drugInfo.engName,
                    ),
                    if (drugInfo.company.isNotEmpty) ...[
                      const Divider(height: 30),
                      _buildInfoRow(
                        icon: Icons.business,
                        iconColor: Colors.green.shade600,
                        iconBackgroundColor: Colors.green.shade50,
                        label: '제조사',
                        value: drugInfo.company,
                      ),
                    ],
                    if (drugInfo.atcCode?.isNotEmpty ?? false) ...[
                      const Divider(height: 30),
                      _buildInfoRow(
                        icon: Icons.category,
                        iconColor: Colors.purple.shade600,
                        iconBackgroundColor: Colors.purple.shade50,
                        label: 'ATC 코드',
                        value: drugInfo.atcCode!,
                        isMonospace: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 스캔 정보 카드
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.qr_code,
                          color: Colors.grey.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '스캔 정보',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildScanDetailRow(label: '바코드: ', value: barcode),
                    const SizedBox(height: 8),
                    _buildScanDetailRow(
                      label: '스캔 시간: ',
                      value: DateTime.now().toString().substring(0, 19),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 100), // 버튼 영역과 겹치지 않도록 여유 공간
          ],
        ),
      ),
      // 하단 버튼 영역: 항상 화면에 고정
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // 다시 스캔하기 버튼
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('다시 스캔'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // AI에게 질문하기 버튼
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAiChatDialog(context),
                  icon: const Icon(Icons.smart_toy_outlined),
                  label: const Text('AI에게 질문'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 메인 정보 행 생성
  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBackgroundColor,
    required String label,
    required String value,
    String? englishValue,
    bool isMonospace = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: (englishValue != null) ? 20 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: isMonospace ? 'monospace' : null,
                ),
              ),
              if (englishValue != null && englishValue.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  englishValue,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // 스캔 정보 행 생성
  Widget _buildScanDetailRow({required String label, required String value}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: label == '바코드: ' ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }

  // AI 질문 기능 임시 다이얼로그
  void _showAiChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🤖 AI에게 질문하기'),
        content: Text(
            '${drugInfo.itemName}에 대해 궁금한 점을 질문해보세요.\n\n(향후 AI 챗봇 기능 연동 예정)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }
}
