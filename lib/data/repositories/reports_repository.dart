import '../database_helper.dart';

class ReportsRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<List<Map<String, dynamic>>> getMonthlyReport(int month, int year) async {
    final db = await DatabaseHelper.instance.database;
    final monthStr = month.toString().padLeft(2, '0');
    final result = await db.rawQuery('''
      SELECT 
        p.name AS product_name,
        p.unit AS unit,
        SUM(s.quantity) AS total_quantity,
        SUM(s.total_amount) AS total_amount
      FROM sales s
      JOIN products p ON s.product_id = p.id
      WHERE strftime('%m', s.created_at) = ?
        AND strftime('%Y', s.created_at) = ?
        AND s.status = 'active'
      GROUP BY s.product_id
    ''', [monthStr, year.toString()]);
    return result;
  }

  // تجميع المبيعات لكل منتج (اسم المنتج -> الكمية المباعة)
  Future<Map<String, double>> getMonthlySalesGroupedByProduct(int month, int year) async {
    final db = await dbHelper.database;
    final monthStr = month.toString().padLeft(2, '0');
    final result = await db.rawQuery('''
      SELECT p.name, SUM(s.quantity) as sold
      FROM sales s
      JOIN products p ON s.product_id = p.id
      WHERE strftime('%m', s.created_at) = ? AND strftime('%Y', s.created_at) = ?
      GROUP BY p.id
    ''', [monthStr, year.toString()]);
    return {for (var row in result) row['name'] as String: (row['sold'] as num).toDouble()};
  }
  

  // 👑 تم التعديل: توحيد المسميات ديناميكياً لتقرأ الشاشة الكاشير والوحدة الحقيقية بالملي
  Future<List<Map<String, dynamic>>> getShiftReportPaginated(
      int shiftId, {
        int limit = 20,
        int offset = 0,
      }) async {
    final db = await dbHelper.database;
    final result = await db.rawQuery('''
      SELECT 
        s.id,
        p.name AS product_name,
        s.quantity,
        p.unit AS unit_type,                       -- 👈 تم التعديل إلى unit_type ليطابق كود الشاشة فوراً
        (s.quantity * s.unit_price) AS total_amount,
        u.name AS cashier_name,                     -- 👈 تم التعديل إلى cashier_name عشان يقرأ (سيد) وميثبتش شادي
        s.status,
        s.created_at
      FROM sales s
      INNER JOIN products p ON s.product_id = p.id  -- استخدمنا INNER JOIN لضمان جلب الداتا المرتبطة كاملة
      LEFT JOIN users u ON s.user_id = u.id
      WHERE s.shift_id = ? AND s.status != 'deleted'
      ORDER BY s.id DESC                            -- ترتيب تنازلي بناءً على المعرف لسرعة تتبع العمليات الأخيرة
      LIMIT ? OFFSET ?
    ''', [shiftId, limit, offset]);
    return result;
  }

  Future<List<Map<String, dynamic>>> getShiftReport(int shiftId) async {
    final db = await dbHelper.database;
    return await db.rawQuery('''
      SELECT 
        s.id,
        u.name AS cashier_name,                     -- 👈 توحيد الاسم هنا أيضاً لراحة البال
        p.name AS product_name,
        p.unit AS unit_type,                       -- 👈 توحيد حقل الوحدة هنا أيضاً
        s.quantity AS quantity,
        s.unit_price,
        s.total_amount,
        s.status,
        s.created_at
      FROM sales s
      JOIN users u ON s.user_id = u.id
      JOIN products p ON s.product_id = p.id
      WHERE s.shift_id = ? 
      ORDER BY s.id DESC
    ''', [shiftId]);
  }

  Future<void> updateSaleStatus(int saleId, String newStatus) async {
    final db = await dbHelper.database;
    await db.update('sales', {'status': newStatus}, where: 'id = ?', whereArgs: [saleId]);
  }

  Future<double> getTodayTotalSales() async {
    final db = await dbHelper.database;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final result = await db.rawQuery('''
      SELECT SUM(total_amount) as total 
      FROM sales 
      WHERE date(created_at) = date(?) AND status = 'active'
    ''', [today]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
  Future<Map<String, dynamic>> getShiftTotalStats(int shiftId) async {
    final db = await DatabaseHelper.instance.database;

    // جلب المجاميع بناءً على الوردية والحالة
    final result = await db.rawQuery('''
    SELECT 
      SUM(CASE WHEN status = 'active' THEN total_amount ELSE 0 END) as active_sum,
      COUNT(CASE WHEN status = 'active' THEN 1 END) as active_count,
      SUM(CASE WHEN status = 'cancelled' THEN total_amount ELSE 0 END) as cancelled_sum
    FROM sales
    WHERE shift_id = ?
  ''', [shiftId]);

    // إرجاع النتيجة كـ Map
    if (result.isNotEmpty) {
      return result.first;
    }
    return {'active_sum': 0.0, 'active_count': 0, 'cancelled_sum': 0.0};
  }

}