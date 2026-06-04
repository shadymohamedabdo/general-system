import '../database_helper.dart';

class ShiftReportRepository {
  final dbHelper = DatabaseHelper.instance;

  // 📌 جلب تقرير شيفت مع إضافة unit و category
  Future<List<Map<String, dynamic>>> getShiftReport(int shiftId) async {
    final db = await dbHelper.database;

    return await db.rawQuery('''
      SELECT s.id,
             u.name as employee_name,
             p.name as product_name,
             p.category as product_category,   -- 🔥 نضيف الفئة لتحديد الوحدة
             p.unit as product_unit,           -- 🔥 نضيف الوحدة المخزنة (احتياطي)
             s.quantity as total_quantity,
             s.unit_price,
             s.quantity * s.unit_price as total_amount,
             s.status
      FROM sales s
      JOIN users u ON s.user_id = u.id
      JOIN products p ON s.product_id = p.id
      WHERE s.shift_id = ? AND s.status = 'active'
    ''', [shiftId]);
  }

  // 📌 إلغاء عملية بيع (نفس الكود)
  Future<void> cancelSale(int saleId) async {
    final db = await dbHelper.database;
    await db.update(
      'sales',
      {'status': 'cancelled'},
      where: 'id = ?',
      whereArgs: [saleId],
    );
  }
}