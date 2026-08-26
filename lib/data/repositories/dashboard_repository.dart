import '../database_helper.dart';
import '../models/dashboard_model.dart';

class DashboardRepository {
  /// جلب المبيعات اليومية لشهر وسنة معينة
  Future<List<DailySale>> getDailySales(int month, int year) async {
    final db = await DatabaseHelper.instance.database;
    final monthStr = month.toString().padLeft(2, '0');

    final result = await db.rawQuery('''
      SELECT 
        CAST(strftime('%d', created_at) AS INTEGER) as day, 
        COALESCE(SUM(total_amount), 0) as total
      FROM sales
      WHERE strftime('%m', created_at) = ?
        AND strftime('%Y', created_at) = ?
        AND status = 'active'
      GROUP BY day
      ORDER BY day
    ''', [monthStr, year.toString()]);

    return result.map((e) => DailySale(
      day: (e['day'] as int?) ?? 0,
      total: (e['total'] as num?)?.toDouble() ?? 0.0,
    )).toList();
  }

  /// أعلى 5 منتجات مبيعًا
  Future<List<ProductSale>> getTopProducts(int month, int year) async {
    final db = await DatabaseHelper.instance.database;
    final monthStr = month.toString().padLeft(2, '0');

    final result = await db.rawQuery('''
      SELECT 
        p.name AS product_name,
        p.category AS category,
        p.unit AS unit,
        COALESCE(SUM(s.quantity), 0) AS total_quantity,
        COALESCE(SUM(s.total_amount), 0) AS total_amount
      FROM sales s
      JOIN products p ON s.product_id = p.id
      WHERE strftime('%m', s.created_at) = ?
        AND strftime('%Y', s.created_at) = ?
        AND s.status = 'active'
      GROUP BY s.product_id
      ORDER BY total_amount DESC
      LIMIT 5
    ''', [monthStr, year.toString()]);

    return result.map((e) => ProductSale(
      productName: e['product_name'].toString(),
      category: e['category'].toString(),
      unit: e['unit']?.toString() ?? '',
      totalQuantity: (e['total_quantity'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (e['total_amount'] as num?)?.toDouble() ?? 0.0,
    )).toList();
  }

  /// جلب إجمالي المصروفات (المصروفات اليدوية + تكلفة خام المبيعات)
  Future<double> getMonthlyExpenses(int month, int year) async {
    final db = await DatabaseHelper.instance.database;
    final monthStr = month.toString().padLeft(2, '0');

    final result = await db.rawQuery('''
      SELECT (
        SELECT COALESCE(SUM(amount), 0) 
        FROM expenses 
        WHERE strftime('%m', date) = ? AND strftime('%Y', date) = ?
      ) + (
        SELECT COALESCE(SUM(s.quantity * p.cost_price), 0)
        FROM sales s
        JOIN products p ON s.product_id = p.id
        WHERE strftime('%m', s.created_at) = ? 
          AND strftime('%Y', s.created_at) = ?
          AND s.status = 'active'
      ) as total
    ''', [monthStr, year.toString(), monthStr, year.toString()]);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  /// جلب إجمالي المشتريات
  Future<double> getMonthlyPurchases(int month, int year) async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(quantity * cost_per_unit), 0) as total
      FROM purchases
      WHERE month = ? AND year = ?
    ''', [month, year]);

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}