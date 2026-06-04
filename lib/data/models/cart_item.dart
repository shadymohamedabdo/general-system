class CartItem {
  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double total;
  final String category;
  CartItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.category,
  });
}
