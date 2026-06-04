class DailySale {
  final int day;
  final double total;
  DailySale({required this.day, required this.total});
}

class ProductSale {
  final String productName;
  final String category;
  final String unit;
  final double totalQuantity;
  final double totalAmount;

  ProductSale({
    required this.productName,
    required this.category,
    required this.unit,
    required this.totalQuantity,
    required this.totalAmount,
  });

  String get unitType {
    if (unit.isNotEmpty) {
      if (unit == 'كيلو' || unit == 'kg' || unit == 'كجم') return 'كيلو';
      if (unit == 'كوب' || unit == 'cup') return 'كوب';
      if (unit == 'قطعة' || unit == 'piece') return 'قطعة';
    }
    final cat = category.toLowerCase();
    if (cat.contains('bean') || cat.contains('coffee') || cat == 'بن') return 'كيلو';
    if (cat.contains('drink') || cat.contains('مشروب')) return 'كوب';
    return 'قطعة';
  }
}