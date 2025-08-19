import 'package:flutter/material.dart';

class DrugDetailCard extends StatelessWidget {
  final Map<String, dynamic> drugJson;

  const DrugDetailCard({super.key, required this.drugJson});

  @override
  Widget build(BuildContext context) {
    final productName = drugJson['product_name'] ?? '정보 없음';
    final efficacy = drugJson['summary']?['efficacy'] ?? '정보 없음';
    final dosage = drugJson['summary']?['dosage'] ?? '정보 없음';
    final contraindications = drugJson['summary']?['contraindications'] ?? {};

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              productName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 12),
            Text('💊 효능: $efficacy', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text('📌 복용법: $dosage', style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              '⚠️ 복용 금기: ${contraindications['who_should_not_take'] ?? '정보 없음'}',
              style: const TextStyle(fontSize: 14, color: Colors.redAccent),
            ),
            const SizedBox(height: 4),
            Text(
              '💡 주의 약물: ${contraindications['medications_to_avoid'] ?? '정보 없음'}',
              style: const TextStyle(fontSize: 14, color: Colors.orangeAccent),
            ),
          ],
        ),
      ),
    );
  }
}
