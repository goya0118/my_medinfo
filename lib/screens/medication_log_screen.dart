// 복약 기록 화면 (간단 버전)
// 날짜를 고르고 목록을 바로 보여줘요
import 'package:flutter/material.dart';
import '../models/medication_log.dart';
import '../services/medication_log_service.dart';

class MedicationLogScreen extends StatefulWidget {
	const MedicationLogScreen({super.key});
	@override
	State<MedicationLogScreen> createState() => _MedicationLogScreenState();
}

class _MedicationLogScreenState extends State<MedicationLogScreen> {
	List<MedicationLog> _logs = [];
	bool _isLoading = false;
	DateTime _selectedDate = DateTime.now();

	@override
	void initState() {
		super.initState();
		_loadMedicationLogs();
	}

	Future<void> _loadMedicationLogs() async {
		setState(() => _isLoading = true);
		final logs = await MedicationLogService.getMedicationLogsByDate(_selectedDate);
		if (!mounted) return;
		setState(() {
			_logs = logs;
			_isLoading = false;
		});
	}

	Future<void> _selectDate() async {
		final picked = await showDatePicker(
			context: context,
			initialDate: _selectedDate,
			firstDate: DateTime(2020),
			lastDate: DateTime.now().add(const Duration(days: 1)),
		);
		if (picked != null && picked != _selectedDate) {
			setState(() => _selectedDate = picked);
			_loadMedicationLogs();
		}
	}

	Future<void> _deleteLog(MedicationLog log) async {
		final confirmed = await showDialog<bool>(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('기록 삭제'),
				content: Text('${log.drugName} 기록을 삭제할까요?'),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
					TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
				],
			),
		);
		if (confirmed == true) {
			final ok = await MedicationLogService.deleteMedicationLog(log.id);
			if (ok) _loadMedicationLogs();
		}
	}

	// 수동 추가 다이얼로그를 보여줘요
	// 입력: 없음
	// 반환: 없음
	void _showManualAddDialog() {
		// 약 이름을 입력받는 상자예요
		final nameController = TextEditingController();
		// 기본 수량은 1정이에요
		int quantity = 1;
		// 기본 시간은 지금이에요
		DateTime takenAt = DateTime.now();

		showDialog(
			context: context,
			builder: (context) => StatefulBuilder(
				builder: (context, setState) => AlertDialog(
					title: const Text('복용 기록 수동 추가'),
					content: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							const Text('약 이름'),
							const SizedBox(height: 8),
							TextField(
								controller: nameController,
								decoration: const InputDecoration(
									border: OutlineInputBorder(),
									hintText: '예) 타이레놀',
								),
							),
							const SizedBox(height: 16),
							const Text('복용 수량'),
							const SizedBox(height: 8),
							Row(
								mainAxisAlignment: MainAxisAlignment.center,
								children: [
									IconButton(
										onPressed: () {
											if (quantity > 1) setState(() => quantity--);
										},
										icon: const Icon(Icons.remove_circle_outline),
									),
									Container(
										padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
										decoration: BoxDecoration(
											color: Colors.blue.shade100,
											borderRadius: BorderRadius.circular(8),
										),
										child: Text('$quantity정', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
									),
									IconButton(
										onPressed: () => setState(() => quantity++),
										icon: const Icon(Icons.add_circle_outline),
									),
								],
							),
							const SizedBox(height: 16),
							Row(
								children: [
									Expanded(
										child: Text('시간: ${_fmtDateTime(takenAt)}'),
									),
									TextButton.icon(
										onPressed: () async {
											final d = await showDatePicker(
												context: context,
												initialDate: takenAt,
												firstDate: DateTime(2020),
												lastDate: DateTime.now().add(const Duration(days: 1)),
											);
											if (d == null) return;
											final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(takenAt));
											if (t == null) return;
											setState(() {
												takenAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
											});
										},
										icon: const Icon(Icons.edit_calendar),
										label: const Text('시간 변경'),
									),
								],
							),
						],
					),
					actions: [
						TextButton(
							onPressed: () => Navigator.pop(context),
							child: const Text('취소'),
						),
						ElevatedButton(
							onPressed: () async {
								final name = nameController.text.trim();
								if (name.isEmpty) return;
								final ok = await MedicationLogService.saveMedicationLog(
									drugName: name,
									takenAt: takenAt,
									quantity: quantity,
								);
								if (!mounted) return;
								Navigator.pop(context);
								if (ok) {
									_loadMedicationLogs();
									ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('기록이 추가되었습니다')));
								}
							},
							child: const Text('저장'),
						),
					],
				),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('복약 기록')),
			body: Column(
				children: [
					Container(
						padding: const EdgeInsets.all(16),
						color: Colors.blue.shade50,
						child: Row(
							children: [
								const Icon(Icons.calendar_today, color: Colors.blue),
								const SizedBox(width: 8),
								Expanded(
									child: Text(
										'${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일',
										style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
									),
								),
								TextButton.icon(
									onPressed: _selectDate,
									icon: const Icon(Icons.edit_calendar),
									label: const Text('날짜 변경'),
								),
							],
						),
					),
					Expanded(
						child: _isLoading
								? const Center(child: CircularProgressIndicator())
								: _logs.isEmpty
										? _buildEmpty()
										: ListView.builder(
											padding: const EdgeInsets.all(16),
											itemCount: _logs.length,
											itemBuilder: (context, i) => _buildItem(_logs[i]),
										),
					),
				],
			),
			floatingActionButton: FloatingActionButton.extended(
				onPressed: _showManualAddDialog,
				icon: const Icon(Icons.add),
				label: const Text('수동 추가'),
			),
		);
	}

	Widget _buildEmpty() => Center(
		child: Column(
			mainAxisAlignment: MainAxisAlignment.center,
			children: [
				Icon(Icons.medication, size: 80, color: Colors.grey.shade400),
				const SizedBox(height: 12),
				Text('복용 기록이 없습니다', style: TextStyle(color: Colors.grey.shade600)),
			],
		),
	);

	Widget _buildItem(MedicationLog log) => Card(
		margin: const EdgeInsets.only(bottom: 12),
		child: ListTile(
			leading: const Icon(Icons.medication),
			title: Text(log.drugName, style: const TextStyle(fontWeight: FontWeight.bold)),
			subtitle: Text(_format(log.takenAt)),
			trailing: Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					Text('${log.quantity}정'),
					IconButton(
						icon: const Icon(Icons.delete_outline, color: Colors.red),
						onPressed: () => _deleteLog(log),
					),
				],
			),
		),
	);

	String _format(DateTime t) {
		final hh = t.hour.toString().padLeft(2, '0');
		final mm = t.minute.toString().padLeft(2, '0');
		final today = DateTime.now();
		final isToday = t.year == today.year && t.month == today.month && t.day == today.day;
		return (isToday ? '오늘' : '${t.month}월 ${t.day}일') + ' $hh:$mm';
	}

	// 날짜와 시간을 보기 좋게 묶어서 보여줘요
	String _fmtDateTime(DateTime dt) {
		final hh = dt.hour.toString().padLeft(2, '0');
		final mm = dt.minute.toString().padLeft(2, '0');
		return '${dt.year}.${dt.month}.${dt.day} $hh:$mm';
	}
} 