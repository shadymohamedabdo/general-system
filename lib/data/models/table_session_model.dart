// models/table_session_model.dart
class TableSession {
  final int tableNumber;
  bool isOpen;
  double totalAmount;
  int itemsCount;

  TableSession({
    required this.tableNumber,
    this.isOpen = false,
    this.totalAmount = 0.0,
    this.itemsCount = 0,
  });

  factory TableSession.fromMap(Map<String, dynamic> map) {
    return TableSession(
      tableNumber: map['table_number'],
      isOpen: (map['is_open'] as int? ?? 0) == 1,
      totalAmount: (map['total_amount'] as num? ?? 0.0).toDouble(),
      itemsCount: map['items_count'] as int? ?? 0,
    );
  }
}