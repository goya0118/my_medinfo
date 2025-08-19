import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// ATC 코드와 영문명으로 JSON 파일을 불러오는 함수
Future<Map<String, dynamic>?> loadDrugJson(String atcCode, String engName) async {
  try {
    // 영문명에서 첫 번째 단어만 추출 (공백 기준)
    final safeEngName = engName.split(' ').first;

    // 파일명 규칙: ATC코드_영문명첫단어.json
    final fileName = 'lib/widgets/drug_info_jsonfiles/${atcCode}_${safeEngName}.json';

    // JSON 파일 읽기
    final jsonString = await rootBundle.loadString(fileName);

    // JSON 디코딩 후 반환
    return json.decode(jsonString);
  } catch (e) {
    print("❌ JSON 로딩 실패: $e");
    return null;
  }
}
