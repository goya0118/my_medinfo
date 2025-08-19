import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/drug_info.dart';
import '../config/env_config.dart';

class DrugApiService {
  // 환경 변수에서 설정 가져오기
  static String get _serviceKey => EnvConfig.serviceKey;
  static String get _baseUrl => EnvConfig.baseUrl;
  static int get _timeoutSeconds => EnvConfig.apiTimeout;

  static Future<DrugInfo?> getDrugInfo(String barcode) async {
    try {
      print('API 호출 시작 - 원본 바코드: $barcode');
      
      // 바코드 정리
      final cleanBarcode = barcode.replaceAll('\x1d', '').trim();
      print('정리된 바코드: $cleanBarcode');
      
      // GS1 GTIN 변환
      final convertedBarcode = _convertGtinToEan13(cleanBarcode);
      print('변환된 바코드: $convertedBarcode');
      
      // 실제 작동하는 API 메소드만 사용
      final methods = [
        {
          'endpoint': '/getDrugPrdtPrmsnDtlInq05',
          'param': 'bar_code',
          'description': '바코드 검색'
        },
        // 500 오류 발생하는 엔드포인트들은 제거하고 대안 추가
        {
          'endpoint': '/getDrugPrdtPrmsnDtlInq05',
          'param': 'item_name', 
          'description': '바코드를 제품명으로 검색'
        },
      ];
      
      // 변환된 바코드로 먼저 시도
      if (convertedBarcode != cleanBarcode) {
        print('변환된 바코드로 시도 중...');
        for (final method in methods) {
          final result = await _tryApiCall(
            method['endpoint']!, 
            method['param']!, 
            convertedBarcode,
            method['description']!
          );
          if (result != null) {
            print('변환된 바코드로 성공: ${method['description']}');
            return result;
          }
        }
      }
      
      // 원본 바코드로 시도
      print('원본 바코드로 시도 중...');
      for (final method in methods) {
        final result = await _tryApiCall(
          method['endpoint']!, 
          method['param']!, 
          cleanBarcode,
          method['description']!
        );
        if (result != null) {
          print('원본 바코드로 성공: ${method['description']}');
          return result;
        }
      }
      
      // 마지막 시도: 다른 형식의 바코드로 변환
      final alternativeFormats = _generateAlternativeFormats(cleanBarcode);
      for (final altBarcode in alternativeFormats) {
        print('대안 바코드로 시도: $altBarcode');
        for (final method in methods) {
          final result = await _tryApiCall(
            method['endpoint']!, 
            method['param']!, 
            altBarcode,
            '${method['description']} (대안형식)'
          );
          if (result != null) {
            print('대안 바코드로 성공: $altBarcode');
            return result;
          }
        }
      }
      
      print('모든 API 호출 실패 - 해당 바코드의 의약품 정보가 데이터베이스에 없을 수 있습니다.');
      return null;
      
    } catch (e) {
      print('API 호출 전체 오류: $e');
      return null;
    }
  }
  static Future<Map<String, dynamic>?> getDrugDetailJson(String barcode) async {
    print("상세 정보 API 호출 시작 (가상): $barcode");

    // 2초간의 가상 네트워크 지연 시간
    await Future.delayed(const Duration(seconds: 2));

    // UI 테스트를 위한 가짜 JSON 데이터를 반환합니다.
    // TODO: 향후 실제 API가 준비되면 이 부분을 실제 네트워크 요청 코드로 교체해야 합니다.
    final mockJsonData = {
      "summary": {
        "efficacy": "이 약은 두통, 치통, 생리통 등 다양한 통증 완화에 효과가 있습니다. 또한 감기로 인한 발열 증상을 완화하는 데 사용됩니다.",
        "dosage": "성인 기준 1회 1~2정, 1일 3~4회 복용할 수 있습니다. 복용 간격은 최소 4시간 이상으로 유지해야 합니다.",
        "contraindications": {
          "who_should_not_take": "이 약의 성분에 과민반응이 있는 환자, 소화성 궤양 환자, 심한 혈액 이상 환자는 복용해서는 안 됩니다.",
          "medications_to_avoid": "다른 비스테로이드성 소염진통제(NSAIDs)와 함께 복용하지 마세요. 와파린 등 항응고제를 복용 중인 경우 의사와 상담이 필요합니다."
        }
      }
    };
    
    print("상세 정보 API 응답 (가상)");
    return mockJsonData;
  }
  
  static Future<DrugInfo?> _tryApiCall(
    String endpoint, 
    String paramName, 
    String barcode,
    String description
  ) async {
    try {
      print('API 호출: $description ($endpoint), 바코드: $barcode');
      
      final params = <String, String>{
        'serviceKey': _serviceKey,
        'pageNo': '1',
        'numOfRows': '100', // 더 많은 결과 요청
        'type': 'json',
        paramName: barcode,
      };
      
      final uri = Uri.parse('$_baseUrl$endpoint').replace(queryParameters: params);
      print('요청 URL: $uri');
      
      final response = await http.get(uri).timeout(
        Duration(seconds: _timeoutSeconds),
      );
      
      print('응답 상태 코드: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('HTTP 오류: ${response.statusCode}');
        if (response.statusCode == 500) {
          print('서버 내부 오류 - 이 엔드포인트는 현재 사용할 수 없습니다');
        }
        return null;
      }
      
      // XML 오류 응답 확인
      if (response.body.trim().startsWith('<')) {
        print('XML 응답 감지 (오류 응답)');
        return null;
      }
      
      print('응답 본문 길이: ${response.body.length}');
      print('응답 본문: ${response.body}');
      
      // JSON 파싱 안전하게 처리
      dynamic data;
      try {
        data = json.decode(response.body);
      } catch (e) {
        print('JSON 파싱 오류: $e');
        return null;
      }
      
      // 응답 상태 확인
      if (data is Map<String, dynamic>) {
        final header = data['header'];
        if (header != null) {
          final resultCode = header['resultCode'];
          final resultMsg = header['resultMsg'];
          print('API 결과 코드: $resultCode, 메시지: $resultMsg');
          
          if (resultCode != '00') {
            print('API 오류 응답: $resultMsg');
            return null;
          }
        }
        
        final body = data['body'];
        if (body != null) {
          final totalCount = body['totalCount'] ?? 0;
          print('검색 결과 수: $totalCount');
          
          if (totalCount == 0) {
            print('검색 결과 없음');
            return null;
          }
        }
      }
      
      final items = _extractItemsFromResponse(data);
      
      if (items != null && items.isNotEmpty) {
        print('아이템 발견: ${items.length}개');
        print('첫 번째 아이템: ${items.first}');
        
        // DrugInfo 생성 시 안전하게 처리
        try {
          final drugInfo = _createDrugInfoFromItem(items.first, barcode);
          return drugInfo;
        } catch (e) {
          print('DrugInfo 생성 오류: $e');
          return null;
        }
      }
      
      print('아이템 없음');
      return null;
      
    } catch (e) {
      print('개별 API 호출 오류: $e');
      return null;
    }
  }

  // 대안 바코드 형식 생성
  static List<String> _generateAlternativeFormats(String barcode) {
    final alternatives = <String>[];
    
    try {
      // 13자리 바코드인 경우
      if (barcode.length == 13) {
        // 앞자리 0 제거 (12자리로)
        if (barcode.startsWith('0')) {
          alternatives.add(barcode.substring(1));
        }
        
        // 마지막 체크섬 자리 제거 (12자리로)
        alternatives.add(barcode.substring(0, 12));
        
        // 앞에 0 추가 (14자리로)
        alternatives.add('0$barcode');
      }
      
      // 12자리 바코드인 경우
      if (barcode.length == 12) {
        // 앞에 0 추가 (13자리로)
        alternatives.add('0$barcode');
        
        // 뒤에 체크섬 추가 (임시로 0)
        alternatives.add('${barcode}0');
      }
      
      // 14자리 바코드인 경우
      if (barcode.length == 14) {
        // 앞자리 제거 (13자리로)
        alternatives.add(barcode.substring(1));
        
        // 뒷자리 제거 (13자리로)
        alternatives.add(barcode.substring(0, 13));
      }
      
    } catch (e) {
      print('대안 형식 생성 오류: $e');
    }
    
    // 중복 제거
    return alternatives.toSet().toList();
  }

  // DrugInfo 생성을 위한 안전한 메소드
  static DrugInfo _createDrugInfoFromItem(Map<String, dynamic> item, String barcode) {
    // 모든 가능한 키 이름들을 확인
    final itemNameKeys = ['ITEM_NAME', 'itemName', 'item_name', 'name', 'productName'];
    final companyKeys = ['ENTP_NAME', 'entpName', 'entp_name', 'company', 'manufacturer'];
    final engNameKeys = ['ITEM_ENG_NAME', 'itemEngName', 'eng_name', 'englishName']; // ✅ 영문명 후보 키 추가
    final atcCodeKeys = ['ATC_CODE', 'atcCode', 'atc_code']; // ✅ ATC 코드 키 후보 추가

    String itemName = '알 수 없는 의약품';
    String company = '';
    String? atcCode; // nullable로 선언
    String? engName;
    
    // 아이템 이름 찾기
    for (final key in itemNameKeys) {
      if (item[key] != null && item[key].toString().trim().isNotEmpty) {
        itemName = item[key].toString().trim();
        break;
      }
    }
    
    // 회사명 찾기
    for (final key in companyKeys) {
      if (item[key] != null && item[key].toString().trim().isNotEmpty) {
        company = item[key].toString().trim();
        break;
      }
    }
    
    // ATC 코드 찾기
    for (final key in atcCodeKeys) {
      if (item[key] != null && item[key].toString().trim().isNotEmpty) {
        atcCode = item[key].toString().trim();
        break;
      }
    }

    // ✅ 영문명 찾기
    for (final key in engNameKeys) {
      if (item[key] != null && item[key].toString().trim().isNotEmpty) {
        engName = item[key].toString().trim();
        break;
      }
    }

    //print('생성된 DrugInfo - 이름: $itemName, 회사: $company');
    print('생성된 DrugInfo - 이름: $itemName, 회사: $company, ATC: $atcCode, 영문명: $engName');

    return DrugInfo(
      itemName: itemName,
      company: company,
      barcode: barcode,
      queriedAt: DateTime.now(),
      atcCode: atcCode, // ✅ 누락된 부분 추가
      engName: engName, // ✅ 추가
    );
  }

  static String _convertGtinToEan13(String gtinCode) {
    try {
      print('GTIN 변환 시작: $gtinCode');
      
      // 010으로 시작하는 GTIN-14에서 EAN-13 추출
      if (gtinCode.startsWith('010') && gtinCode.length >= 17) {
        final gtin14 = gtinCode.substring(3, 17);
        final ean13 = gtin14.substring(1);
        print('010 패턴 변환: $gtinCode -> $ean13');
        return ean13;
      }
      
      // 01로 시작하는 경우
      if (gtinCode.startsWith('01') && gtinCode.length >= 16) {
        final gtin14 = gtinCode.substring(2, 16);
        final ean13 = gtin14.substring(1);
        print('01 패턴 변환: $gtinCode -> $ean13');
        return ean13;
      }
      
      // 이미 13자리 숫자인 경우
      if (gtinCode.length == 13 && RegExp(r'^\d+$').hasMatch(gtinCode)) {
        print('이미 EAN-13 형식: $gtinCode');
        return gtinCode;
      }
      
      // 12자리 숫자인 경우 (UPC-A를 EAN-13으로)
      if (gtinCode.length == 12 && RegExp(r'^\d+$').hasMatch(gtinCode)) {
        final ean13 = '0$gtinCode';
        print('UPC-A를 EAN-13으로 변환: $gtinCode -> $ean13');
        return ean13;
      }
      
      print('변환 불필요: $gtinCode');
      return gtinCode;
    } catch (e) {
      print('GTIN 변환 오류: $e');
      return gtinCode;
    }
  }

  static List<Map<String, dynamic>>? _extractItemsFromResponse(dynamic data) {
    try {
      print('응답 데이터 구조 분석 시작');
      print('데이터 타입: ${data.runtimeType}');
      
      // data를 Map으로 캐스팅 시도
      if (data is Map<String, dynamic>) {
        print('Map 형태 데이터 처리');
        
        // 구조 1: body.items (식약처 API 표준 구조)
        if (data.containsKey('body') && data['body'] is Map) {
          final body = data['body'] as Map<String, dynamic>;
          print('body 키 발견');
          
          // items 키가 있는지 확인
          if (body.containsKey('items')) {
            final items = body['items'];
            print('items 키 발견, 타입: ${items.runtimeType}');
            
            // items가 List인 경우
            if (items is List && items.isNotEmpty) {
              final result = items.cast<Map<String, dynamic>>();
              print('body.items List: ${result.length}개');
              return result;
            }
            
            // items가 Map인 경우 (단일 아이템)
            if (items is Map<String, dynamic>) {
              print('body.items 단일 Map');
              return [items];
            }
          }
          
          // 직접 데이터가 body에 있는 경우도 확인
          print('body 내용: ${body.keys.toList()}');
        }
        
        print('알 수 없는 구조, 최상위 키들: ${data.keys.toList()}');
      }
      
      print('아이템 추출 실패');
      return null;
    } catch (e) {
      print('데이터 추출 오류: $e');
      return null;
    }
  }
}