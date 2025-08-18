// 복약 기록 모델이에요 (간단 버전)
// 언제, 어떤 약을, 얼마나 먹었는지 기록해요
import 'package:isar/isar.dart';

// Isar 자동 생성 코드 연결
part 'medication_log.g.dart';

@collection
class MedicationLog {
	// 고유번호 (자동 생성)
	Id id = Isar.autoIncrement;

	// 약 이름 (검색 빠르게 하려고 인덱스 붙여요)
	@Index()
	String drugName = '';

	// 복용 시간 (언제 먹었는지)
	@Index()
	DateTime takenAt = DateTime.now();

	// 복용 수량 (몇 정/캡슐)
	int quantity = 1;

	// 새 기록 만들 때 사용하는 생성자
	MedicationLog({
		required this.drugName,
		required this.takenAt,
		this.quantity = 1,
	});

	// JSON으로 바꾸기 (필요할 때 사용)
	Map<String, dynamic> toJson() => {
		'id': id,
		'drugName': drugName,
		'takenAt': takenAt.toIso8601String(),
		'quantity': quantity,
	};

	// JSON에서 객체 만들기 (필요할 때 사용)
	factory MedicationLog.fromJson(Map<String, dynamic> json) => MedicationLog(
		drugName: json['drugName'] ?? '',
		takenAt: DateTime.parse(json['takenAt']),
		quantity: json['quantity'] ?? 1,
	);
}