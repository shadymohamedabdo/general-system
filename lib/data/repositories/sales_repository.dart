import '../database_helper.dart';

class SalesRepository {
  final dbHelper = DatabaseHelper.instance;

  // =========================================
  // 🔴 إضافة عملية بيع جديدة داخل قاعدة البيانات
  // =========================================
  Future<void> addSale({
    required int shiftId,
    required int userId,
    required int productId,
    required double quantity,
    required double unitPrice,
    required double totalAmount, // إجمالي قيمة البيع (quantity * unitPrice)
    String status = 'active', // حالة البيع (active / cancelled)
    String? createdAt,
  }) async {
    final db = await dbHelper.database;

    await db.insert('sales', {
      'shift_id': shiftId,
      'user_id': userId,
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_amount': totalAmount,
      'status': status,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    });

    // تنبيه باقي أجزاء التطبيق إن فيه تغيير في المبيعات
    DatabaseHelper.notifySalesChanged();
  }

  // =========================================
  // 🔵 تحديث حالة عملية بيع (active / cancelled)
  // =========================================
  Future<void> updateSaleStatus(int saleId, String newStatus) async {
    final db = await dbHelper.database;

    await db.update(
      'sales',
      {'status': newStatus},
      where: 'id = ?',
      whereArgs: [saleId],
    );

    // تنبيه التغيير
    DatabaseHelper.notifySalesChanged();
  }

  // =========================================
  // 🟢 جلب مبيعات شيفت معين + اسم المنتج
  // =========================================
  Future<List<Map<String, dynamic>>> getSalesByShift(int shiftId) async {
    final db = await dbHelper.database;

    return await db.rawQuery('''
      SELECT 
        sales.*,
        products.name as product_name
      FROM sales
      LEFT JOIN products ON products.id = sales.product_id
      WHERE sales.shift_id = ?
      ORDER BY sales.id DESC
    ''', [shiftId]);
  }

  // =========================================
  // 🟡 جلب كل المبيعات في النظام
  // =========================================
  Future<List<Map<String, dynamic>>> getAllSales() async {
    final db = await dbHelper.database;

    return await db.rawQuery('''
      SELECT 
        sales.*,
        products.name as product_name
      FROM sales
      LEFT JOIN products ON products.id = sales.product_id
      ORDER BY sales.id DESC
    ''');
  }
}