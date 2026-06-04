class SaleItem {
  final int? productId; // أضفنا المعرف
  final String productName;
  final double totalAmount;
  final double totalQuantity;
  final String unit;

  SaleItem({
    this.productId,
    required this.productName,
    required this.totalAmount,
    required this.totalQuantity,
    required this.unit,
  });

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['product_id'], // تأكد أن الاستعلام يرجع هذا الحقل
      productName: map['product_name'] ?? 'منتج غير معروف',
      totalAmount: (map['total_amount'] as num? ?? 0.0).toDouble(),
      totalQuantity: (map['total_quantity'] as num? ?? 0.0).toDouble(),
      unit: map['unit'] ?? '',
    );
  }

  // دالة مفيدة لعرض الكمية مع الوحدة بشكل منسق
  String get formattedQuantity => '$totalQuantity $unit';
}