class Product {
  final int? id; // خليه اختياري عشان الإضافة
  final String name;
  final String category;
  final String unit;
  final double price;
  final double initialStock; // 👈 الحقل الجديد لكمية المصنع المباشرة

  Product({
    this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.price,
    this.initialStock = 0.0, // القيمة الافتراضية صفر لو مفيش كمية مضافة
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int?,
      name: map['name'] as String? ?? 'بدون اسم',
      category: map['category'] as String? ?? 'أخرى',
      // 🔥 الحماية السحرية هنا: لو الـ unit نازلة null من السجلات القديمة هتاخد 'قطعة' تلقائي ومش هتضرب كراش
      unit: map['unit'] as String? ?? 'قطعة',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      // 👈 قراءة القيمة من الداتابيز وتحويلها لـ double بأمان
      initialStock: (map['initial_stock'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // ضيف دي عشان تسهل الإضافة والتعديل
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'unit': unit,
      'price': price,
      'initial_stock': initialStock, // 👈 حفظ القيمة في عمود الداتابيز الجديد
    };
  }
}