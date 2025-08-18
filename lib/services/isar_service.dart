// Isar 데이터베이스를 관리하는 서비스입니다
// 이 서비스는 복약 기록을 저장하고 불러오는 모든 데이터베이스 작업을 담당해요
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/medication_log.dart';

class IsarService {
  // Isar 데이터베이스 인스턴스예요
  static Isar? _isar;
  
  // 데이터베이스가 초기화되었는지 확인하는 변수예요
  static bool get isInitialized => _isar != null;
  
  // 데이터베이스를 초기화하는 함수예요
  // 앱이 시작될 때 한 번만 호출돼요
  static Future<void> initialize() async {
    try {
      // 앱의 문서 디렉토리 경로를 가져와요 (데이터를 저장할 곳이에요)
      final dir = await getApplicationDocumentsDirectory();
      
      // Isar 데이터베이스를 열어요
      // MedicationLog 모델을 포함해서 데이터베이스를 만들어요
      _isar = await Isar.open(
        [MedicationLogSchema], // MedicationLog 모델을 사용한다는 뜻이에요
        directory: dir.path,   // 데이터를 저장할 경로예요
      );
      
      print('✅ Isar 데이터베이스 초기화 완료');
    } catch (e) {
      print('❌ Isar 데이터베이스 초기화 실패: $e');
      rethrow;
    }
  }
  
  // 데이터베이스를 닫는 함수예요
  // 앱이 종료될 때 호출돼요
  static Future<void> close() async {
    await _isar?.close();
    _isar = null;
    print('🔒 Isar 데이터베이스 연결 종료');
  }
  
  // 데이터베이스 인스턴스를 가져오는 함수예요
  static Isar get instance {
    if (_isar == null) {
      throw Exception('Isar 데이터베이스가 초기화되지 않았습니다. initialize()를 먼저 호출해주세요.');
    }
    return _isar!;
  }
  
  // 데이터베이스가 열려있는지 확인하는 함수예요
  static bool get isOpen => _isar?.isOpen ?? false;
} 