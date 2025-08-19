import 'package:flutter/material.dart';
import '../models/drug_info.dart';
import '../services/drug_api_service.dart';
import 'ai_chat_screen.dart'; // ✅ AI 채팅 화면을 불러오기 위해 추가

class DrugDetailScreen extends StatefulWidget {
  final DrugInfo drugInfo;
  final String barcode;

  const DrugDetailScreen({
    super.key,
    required this.drugInfo,
    required this.barcode,
  });

  @override
  State<DrugDetailScreen> createState() => _DrugDetailScreenState();
}

class _DrugDetailScreenState extends State<DrugDetailScreen> {
  late Future<Map<String, dynamic>?> _drugDetailFuture;

  @override
  void initState() {
    super.initState();
    _drugDetailFuture = DrugApiService.getDrugDetailJson(widget.barcode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💊 의약품 상세 정보'),
        backgroundColor: Colors.blue.shade100,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _drugDetailFuture,
          builder: (context, snapshot) {
            // 로딩 중일 때
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text('상세 정보를 불러오는 중입니다...'),
                  ],
                ),
              );
            }

            // 에러가 발생했거나 데이터가 없을 때
            if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('상세 정보를 불러오는 데 실패했습니다.\n\n오류: ${snapshot.error}'),
                ),
              );
            }

            // 데이터 로딩 성공 시
            final jsonData = snapshot.data!;
            
            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 기본 정보 (약품명, 영문명)
                            Text(
                              widget.drugInfo.itemName,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            if (widget.drugInfo.engName?.isNotEmpty ?? false) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.drugInfo.engName!,
                                style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.black54),
                              ),
                            ],
                            const Divider(height: 30),

                            // 상세 정보 (효능, 용법 등)
                            _buildDetailSection('효능', jsonData['summary']?['efficacy']),
                            _buildDetailSection('용법/용량', jsonData['summary']?['dosage']),
                            _buildDetailSection('복용 금기 대상', jsonData['summary']?['contraindications']?['who_should_not_take']),
                            _buildDetailSection('함께 복용하면 안되는 약', jsonData['summary']?['contraindications']?['medications_to_avoid']),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('다시 스캔'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  // ✅ 이 부분을 수정했습니다.
                  onPressed: () {
                    // AiChatScreen으로 이동하도록 변경
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AiChatScreen(drugInfo: widget.drugInfo),
                      ),
                    );
                  },
                  icon: const Icon(Icons.smart_toy_outlined),
                  label: const Text('AI에게 질문'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 상세 정보 섹션을 만드는 헬퍼 위젯
  Widget _buildDetailSection(String title, String? content) {
    if (content == null || content.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '- $title',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepPurple),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.5),
          ),
        ],
      ),
    );
  }
  
  // ✅ _showAiChatDialog 함수는 이제 필요 없으므로 삭제했습니다.
}