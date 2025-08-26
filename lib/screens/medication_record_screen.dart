import 'package:flutter/material.dart';
import '../models/medication_record.dart';
import '../services/medication_database_helper.dart';
import 'add_medication_record_screen.dart';
import 'package:medinfo/screens/home_screen.dart';

class MedicationRecordScreen extends StatefulWidget {
  const MedicationRecordScreen({super.key});

  @override
  State<MedicationRecordScreen> createState() => _MedicationRecordScreenState();
}

class _MedicationRecordScreenState extends State<MedicationRecordScreen> {
  final MedicationDatabaseHelper _dbHelper = MedicationDatabaseHelper();
  List<MedicationRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final records = await _dbHelper.getAllMedicationRecords();
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('데이터 로드 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: TitleHeader(
        title: Text(
          '내꺼약',
          style: TextStyle(
            color: Color(0xFF5B32F4),
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xff5B32F4)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.add),
        //     onPressed: _navigateToAddRecord,
        //   ),
        // ],
        // backgroundColor: Colors.orange.shade100,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? _buildEmptyState()
              : _buildRecordsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '복약 기록이 없습니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '+ 버튼을 눌러 첫 번째 기록을 추가해보세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          HomeScreen.buildButton(
            context,
            label: '복약 기록 추가',
            icon: const Icon(Icons.add, color: Colors.white, size: 32),
            backgroundColor: const Color(0xFF5B32F4),
            textColor: Colors.white,
            strokeColor: const Color(0xFF5B32F4),
            onPressed: _navigateToAddRecord,
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _records.length + 1,
      itemBuilder: (context, index) {
        if (index < _records.length) {
          final record = _records[index];
          return _buildRecordCard(record);
        } else {
          // 마지막에 버튼 추가
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: HomeScreen.buildButton(
              context,
              label: '복약 기록 추가',
              icon: const Icon(Icons.add, color: Colors.white, size: 32),
              backgroundColor: const Color(0xFF5B32F4),
              textColor: Colors.white,
              strokeColor: const Color(0xFF5B32F4),
              onPressed: _navigateToAddRecord,
            ),
          );
        }
      },
    );
  }

  Widget _buildRecordCard(MedicationRecord record) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: const Color(0xFFF6F6FA), // 연보라색 배경 예시
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단: 의약품명과 개수, 삭제 버튼
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.medicationName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Pretendard',
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xfff0e7ff),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${record.quantity}개',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.deepPurpleAccent.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 삭제 버튼
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                  onPressed: () => _showDeleteConfirmDialog(record),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // 중간: 날짜와 시간
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  () {
                    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
                    final weekday = weekdays[record.date.weekday - 1];
                    return '${record.date.year}년 ${record.date.month}월 ${record.date.day}일 ($weekday)';
                  }(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  record.time,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            
            // 하단: 메모 (있는 경우만)
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.note_alt,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        record.notes!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToAddRecord() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddMedicationRecordScreen(),
      ),
    );
    
    // 새 기록이 추가되었으면 목록 새로고침
    if (result == true) {
      _loadRecords();
    }
  }

  // 삭제 확인 다이얼로그
  void _showDeleteConfirmDialog(MedicationRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('복약 기록 삭제'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('다음 복약 기록을 삭제하시겠습니까?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.medicationName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    () {
                      const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
                      final weekday = weekdays[record.date.weekday - 1];
                      return '${record.date.year}년 ${record.date.month}월 ${record.date.day}일 ($weekday) ${record.time}';
                    }(),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '삭제된 기록은 복구할 수 없습니다.',
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => _deleteRecord(record),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  // 복약 기록 삭제
  Future<void> _deleteRecord(MedicationRecord record) async {
    try {
      await _dbHelper.deleteMedicationRecord(record.id!);
      Navigator.pop(context); // 다이얼로그 닫기
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('복약 기록이 삭제되었습니다'),
          backgroundColor: Colors.green,
        ),
      );
      
      _loadRecords(); // 목록 새로고침
    } catch (e) {
      Navigator.pop(context); // 다이얼로그 닫기
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('삭제 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}