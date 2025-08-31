class DrugInfo {
  final String itemName;
  final String company;
  final String barcode;
  final DateTime queriedAt;
  final String? atcCode; // ✅ nullable 타입 유지
  final String? engName;   // ✅ 영문 이름 추가
  final Map<String, dynamic>? rawApiData; // ✅ API 응답 원본을 담을 필드 추가

  DrugInfo({
    required this.itemName,
    this.company = '',
    required this.barcode,
    required this.queriedAt,
    this.atcCode,
    this.engName,
    this.rawApiData, // ✅ 생성자에 추가

  });

  factory DrugInfo.fromJson(Map<String, dynamic> json) {
    // 다양한 키 패턴을 지원하는 안전한 파싱
    String getStringValue(List<String> possibleKeys) {
      for (final key in possibleKeys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return '';
    }

    final itemName = getStringValue([
      'ITEM_NAME', 'itemName', 'item_name', 'name', 'productName'
    ]);

    final company = getStringValue([
      'ENTP_NAME', 'entpName', 'entp_name', 'company', 'manufacturer'
    ]);

    final barcode = getStringValue([
      'barcode', 'bar_code', 'BAR_CODE', 'code'
    ]);

    // ✅ atcCode 값 가져오기
    final atcCode = getStringValue(['atcCode', 'ATC_CODE']);

    // ✅ engName 값 가져오기
    final engName = getStringValue(['ITEM_ENG_NAME', 'engName', 'eng_name']);

    return DrugInfo(
      itemName: itemName.isNotEmpty ? itemName : '상품명 정보 없음',
      company: company,
      barcode: barcode,
      queriedAt: DateTime.now(),
      // 2. 위에서 가져온 atcCode 변수를 사용하여 빈 문자열일 경우 null로 처리합니다.
      atcCode: atcCode.isNotEmpty ? atcCode : null,
      engName: engName.isNotEmpty ? engName : null, // ✅ 영문명 반영

    );
    // --- 수정 끝 ---
  }

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'company': company,
      'barcode': barcode,
      'queriedAt': queriedAt.toIso8601String(),
      if (atcCode != null) 'atcCode': atcCode,
      if (engName != null) 'engName': engName, // ✅ JSON 변환 시 포함
    };
  }

  @override
  String toString() {
    return 'DrugInfo(itemName: $itemName, company: $company, barcode: $barcode)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DrugInfo &&
        other.itemName == itemName &&
        other.company == company &&
        other.barcode == barcode;
  }

  @override
  int get hashCode {
    return itemName.hashCode ^ company.hashCode ^ barcode.hashCode;
  }
}