class CartItem {
  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double total;
  final String category;
  final String? notes; // 👈 حقل الملاحظات والنكهة

  CartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.category,
    this.notes,
  });
}