class ShiftModel {
  final int? id;
  final String type;
  final String userName;
  final String date;
  final int isOpen;
  final String? startTime;
  final String? endTime;

  ShiftModel({
    this.id,
    required this.type,
    required this.userName,
    required this.date,
    required this.isOpen,
    this.startTime,
    this.endTime,
  });

  // تحويل من Map (قاعدة البيانات) إلى Model
  factory ShiftModel.fromMap(Map<String, dynamic> map) {
    return ShiftModel(
      id: map['id'],
      type: map['type'] ?? '',
      userName: map['user_name'] ?? 'غير معروف',
      date: map['date'] ?? '',
      isOpen: map['is_open'] ?? 0,
      startTime: map['start_time'],
      endTime: map['end_time'],
    );
  }

  // تحويل من Model إلى Map (للحفظ في قاعدة البيانات)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'user_name': userName,
      'date': date,
      'is_open': isOpen,
      'start_time': startTime,
      'end_time': endTime,
    };
  }
}