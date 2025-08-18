// 복약 기록 저장/조회 서비스 (간단 버전)
// 약 이름, 복용 시간, 수량만 다뤄요
import 'package:isar/isar.dart';
import '../models/medication_log.dart';
import 'isar_service.dart';

class MedicationLogService {
	// 새 복약 기록 저장
	// 입력: 약 이름(String), 복용 시간(DateTime), 수량(int)
	// 반환: 성공 여부(bool)
	static Future<bool> saveMedicationLog({
		required String drugName,
		required DateTime takenAt,
		int quantity = 1,
	}) async {
		try {
			if (!IsarService.isInitialized) return false;
			final log = MedicationLog(
				drugName: drugName,
				takenAt: takenAt,
				quantity: quantity,
			);
			await IsarService.instance.writeTxn(() async {
				await IsarService.instance.medicationLogs.put(log);
			});
			return true;
		} catch (_) {
			return false;
		}
	}

	// 전체 기록 조회 (최신순)
	// 입력: 없음
	// 반환: 기록 목록(List<MedicationLog>)
	static Future<List<MedicationLog>> getAllMedicationLogs() async {
		if (!IsarService.isInitialized) return [];
		return IsarService.instance.medicationLogs.where().sortByTakenAtDesc().findAll();
	}

	// 날짜별 기록 조회 (해당 날짜 0시~24시)
	// 입력: 날짜(DateTime)
	// 반환: 기록 목록(List<MedicationLog>)
	static Future<List<MedicationLog>> getMedicationLogsByDate(DateTime date) async {
		if (!IsarService.isInitialized) return [];
		final start = DateTime(date.year, date.month, date.day);
		final end = start.add(const Duration(days: 1));
		return IsarService.instance.medicationLogs
			.where()
			.takenAtBetween(start, end)
			.sortByTakenAtDesc()
			.findAll();
	}

	// 약 이름으로 기록 조회
	// 입력: 약 이름(String)
	// 반환: 기록 목록(List<MedicationLog>)
	static Future<List<MedicationLog>> getMedicationLogsByDrug(String drugName) async {
		if (!IsarService.isInitialized) return [];
		return IsarService.instance.medicationLogs
			.where()
			.drugNameEqualTo(drugName)
			.sortByTakenAtDesc()
			.findAll();
	}

	// 기록 삭제
	// 입력: 기록 ID(int)
	// 반환: 성공 여부(bool)
	static Future<bool> deleteMedicationLog(int id) async {
		if (!IsarService.isInitialized) return false;
		try {
			await IsarService.instance.writeTxn(() async {
				await IsarService.instance.medicationLogs.delete(id);
			});
			return true;
		} catch (_) {
			return false;
		}
	}

	// 기록 수정 (전체 교체)
	// 입력: 기록 객체(MedicationLog)
	// 반환: 성공 여부(bool)
	static Future<bool> updateMedicationLog(MedicationLog log) async {
		if (!IsarService.isInitialized) return false;
		try {
			await IsarService.instance.writeTxn(() async {
				await IsarService.instance.medicationLogs.put(log);
			});
			return true;
		} catch (_) {
			return false;
		}
	}
} 