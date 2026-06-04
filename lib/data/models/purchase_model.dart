class PurchaseItem {
  final int? id;
  final String productName;
  final double quantity;
  final String unit; // كيلو، كوب، قطعة
  final double costPerUnit; // سعر الشراء للوحدة
  final int month;
  final int year;

  PurchaseItem({
    this.id,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.costPerUnit,
    required this.month,
    required this.year,
  });

  double get totalCost => quantity * costPerUnit;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_name': productName,
      'quantity': quantity,
      'unit': unit,
      'cost_per_unit': costPerUnit,
      'month': month,
      'year': year,
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'],
      productName: map['product_name'],
      quantity: map['quantity'],
      unit: map['unit'],
      costPerUnit: map['cost_per_unit'],
      month: map['month'],
      year: map['year'],
    );
  }
}