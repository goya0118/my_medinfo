import 'package:flutter/material.dart';
import '../models/medication_record.dart';
import '../services/medication_database_helper.dart';

class AddMedicationRecordScreen extends StatefulWidget {
  const AddMedicationRecordScreen({super.key});

  @override
  State<AddMedicationRecordScreen> createState() => _AddMedicationRecordScreenState();
}

class _AddMedicationRecordScreenState extends State<AddMedicationRecordScreen> {
  final MedicationDatabaseHelper _dbHelper = MedicationDatabaseHelper();
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  final TextEditingController _notesController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('복약 기록 추가'),
        backgroundColor: Colors.green.shade100,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveRecord,
            child: Text(
              '저장',
              style: TextStyle(
                color: _isLoading ? Colors.grey : Colors.green.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 의약품명 입력
                  _buildSectionTitle('의약품명'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _medicationController,
                    hintText: '예: 타이레놀, 아스피린',
                    icon: Icons.medication,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 복용 개수 입력
                  _buildSectionTitle('복용 개수'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _quantityController,
                    hintText: '예: 1, 2',
                    icon: Icons.numbers,
                    keyboardType: TextInputType.number,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 날짜 선택
                  _buildSectionTitle('복용 날짜'),
                  const SizedBox(height: 8),
                  _buildDateSelector(),
                  
                  const SizedBox(height: 24),
                  
                  // 시간 선택
                  _buildSectionTitle('복용 시간'),
                  const SizedBox(height: 8),
                  _buildTimeSelector(),
                  
                  const SizedBox(height: 24),
                  
                  // 메모 입력
                  _buildSectionTitle('메모 (선택사항)'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _notesController,
                    hintText: '식후 복용, 부작용 등',
                    icon: Icons.note_alt,
                    maxLines: 3,
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: Colors.grey.shade600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintStyle: TextStyle(color: Colors.grey.shade500),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    // 요일 배열
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[_selectedDate.weekday - 1];
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: Icon(Icons.calendar_today, color: Colors.grey.shade600),
        title: Text(
          '${_selectedDate.year}년 ${_selectedDate.month}월 ${_selectedDate.day}일 ($weekday)',
          style: const TextStyle(fontSize: 16),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _selectDate,
      ),
    );
  }

  Widget _buildTimeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: Icon(Icons.access_time, color: Colors.grey.shade600),
        title: Text(
          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 16),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _selectTime,
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveRecord() async {
    if (_medicationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('의약품명을 입력해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final int quantity = int.tryParse(_quantityController.text) ?? 1;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('복용 개수는 1개 이상이어야 합니다'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final record = MedicationRecord(
        medicationName: _medicationController.text.trim(),
        quantity: quantity,
        date: _selectedDate,
        time: '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
        notes: _notesController.text.trim(),
      );

      await _dbHelper.insertMedicationRecord(record);
      
      Navigator.pop(context, true); // true를 반환해서 목록 새로고침 신호
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('복약 기록이 저장되었습니다'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _medicationController.dispose();
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
