// lib/config/env_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  // 앱 시작 시 환경 변수 로드
  static Future<void> load() async {
    await dotenv.load(fileName: '.env');
  }
  
  // API 설정
  static String get serviceKey => dotenv.env['DRUG_API_SERVICE_KEY'] ?? '';
  static String get baseUrl => dotenv.env['DRUG_API_BASE_URL'] ?? '';
  
  // 바코드 스캐너 설정
  static int get scannerTimeout => int.tryParse(dotenv.env['SCANNER_DETECTION_TIMEOUT'] ?? '5000') ?? 5000;
  static List<String> get scannerFormats => 
      (dotenv.env['SCANNER_FORMATS'] ?? 'CODE_128,EAN_13').split(',');
  
  // 기타 설정
  static int get apiTimeout => int.tryParse(dotenv.env['API_TIMEOUT'] ?? '15') ?? 15;
  static String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
  
  // 환경 변수 유효성 검사
  static bool get isConfigValid {
    return serviceKey.isNotEmpty && baseUrl.isNotEmpty;
  }
}