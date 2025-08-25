import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/medication_record.dart';

class MedicationDatabaseHelper {
  static final MedicationDatabaseHelper _instance = MedicationDatabaseHelper._internal();
  factory MedicationDatabaseHelper() => _instance;
  MedicationDatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    
    // 기본 데이터가 없으면 추가
    await _ensureDefaultDataExists();
    
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'medication_records.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  // 기본 데이터 존재 확인 및 추가
  Future<void> _ensureDefaultDataExists() async {
    final db = await _database!;
    final result = await db.query(
      'medication_records',
      where: 'medication_name = ?',
      whereArgs: ['메토트렉세이트'],
    );
    
    // 기본 데이터가 없으면 추가
    if (result.isEmpty) {
      await _insertDefaultData(db);
    }
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medication_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medication_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        date TEXT NOT NULL,
        time TEXT NOT NULL,
        notes TEXT DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');
    
    // 기본 데이터 삽입
    await _insertDefaultData(db);
  }

  // 기본 데이터 삽입 함수
  Future<void> _insertDefaultData(Database db) async {
    final defaultRecord = {
      'medication_name': '메토트렉세이트',
      'quantity': 1,
      'date': '2025-08-24',
      'time': '17:26',
      'notes': '',
      'created_at': DateTime(2025, 8, 24, 17, 26).toIso8601String(),
    };
    
    await db.insert('medication_records', defaultRecord);
  }

  // 복약 기록 추가
  Future<int> insertMedicationRecord(MedicationRecord record) async {
    final db = await database;
    return await db.insert('medication_records', record.toMap());
  }

  // 모든 복약 기록 조회 (최신순)
  Future<List<MedicationRecord>> getAllMedicationRecords() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'medication_records',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) {
      return MedicationRecord.fromMap(maps[i]);
    });
  }

  // 특정 날짜의 복약 기록 조회
  Future<List<MedicationRecord>> getMedicationRecordsByDate(DateTime date) async {
    final db = await database;
    final String dateString = date.toIso8601String().split('T')[0];
    final List<Map<String, dynamic>> maps = await db.query(
      'medication_records',
      where: 'date = ?',
      whereArgs: [dateString],
      orderBy: 'time ASC',
    );
    return List.generate(maps.length, (i) {
      return MedicationRecord.fromMap(maps[i]);
    });
  }

  // 특정 약물의 복약 기록 조회
  Future<List<MedicationRecord>> getMedicationRecordsByName(String medicationName) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'medication_records',
      where: 'medication_name LIKE ?',
      whereArgs: ['%$medicationName%'],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) {
      return MedicationRecord.fromMap(maps[i]);
    });
  }

  // 복약 기록 수정
  Future<int> updateMedicationRecord(MedicationRecord record) async {
    final db = await database;
    return await db.update(
      'medication_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  // 복약 기록 삭제
  Future<int> deleteMedicationRecord(int id) async {
    final db = await database;
    return await db.delete(
      'medication_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 전체 레코드 수 조회
  Future<int> getTotalRecordCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM medication_records');
    return result.first['count'] as int;
  }

  // 데이터베이스 닫기
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}