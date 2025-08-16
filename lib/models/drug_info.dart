class DrugInfo {
  final String itemName;
  final String company;
  final String barcode;
  final DateTime queriedAt;

  DrugInfo({
    required this.itemName,
    this.company = '',
    required this.barcode,
    required this.queriedAt,
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

    return DrugInfo(
      itemName: itemName.isNotEmpty ? itemName : '상품명 정보 없음',
      company: company,
      barcode: barcode,
      queriedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemName': itemName,
      'company': company,
      'barcode': barcode,
      'queriedAt': queriedAt.toIso8601String(),
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