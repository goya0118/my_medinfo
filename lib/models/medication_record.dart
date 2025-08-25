class MedicationRecord {
  final int? id;
  final String medicationName;
  final int quantity;
  final DateTime date;
  final String time;
  final String? notes;
  final DateTime createdAt;

  MedicationRecord({
    this.id,
    required this.medicationName,
    required this.quantity,
    required this.date,
    required this.time,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medication_name': medicationName,
      'quantity': quantity,
      'date': date.toIso8601String().split('T')[0], // YYYY-MM-DD 형식
      'time': time,
      'notes': notes ?? '',
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory MedicationRecord.fromMap(Map<String, dynamic> map) {
    return MedicationRecord(
      id: map['id']?.toInt(),
      medicationName: map['medication_name'] ?? '',
      quantity: map['quantity']?.toInt() ?? 0,
      date: DateTime.parse(map['date']),
      time: map['time'] ?? '',
      notes: map['notes'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  MedicationRecord copyWith({
    int? id,
    String? medicationName,
    int? quantity,
    DateTime? date,
    String? time,
    String? notes,
    DateTime? createdAt,
  }) {
    return MedicationRecord(
      id: id ?? this.id,
      medicationName: medicationName ?? this.medicationName,
      quantity: quantity ?? this.quantity,
      date: date ?? this.date,
      time: time ?? this.time,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}