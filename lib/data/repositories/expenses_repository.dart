import '../database_helper.dart';

class ExpensesRepository {
  final dbHelper = DatabaseHelper.instance;

  // 1. إضافة مصروف
  Future<int> addCustomExpense({
    required int shiftId,
    required String title,
    required double amount,
    String? notes,
    int? userId,
  }) async {
    final db = await dbHelper.database;
    return await db.insert('expenses', {
      'shift_id': shiftId,
      'title': title,
      'amount': amount,
      'notes': notes,
      'user_id': userId ?? 1,
      'date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // 2. جلب المصروفات بـ Pagination (هذه الدالة التي كانت مفقودة)
  Future<List<Map<String, dynamic>>> getExpensesPaginated({
    required int month,
    required int year,
    required int limit,
    required int offset,
  }) async {
    final db = await dbHelper.database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 1).toIso8601String();

    return await db.rawQuery('''
      SELECT e.*, COALESCE(s.user_name, 'كاشير') as cashier_name 
      FROM expenses e
      LEFT JOIN shifts s ON e.shift_id = s.id
      WHERE e.date >= ? AND e.date < ?
      ORDER BY e.id DESC
      LIMIT ? OFFSET ?
    ''', [startDate, endDate, limit, offset]);
  }
// أضف هذه الدالة داخل كلاس ExpensesRepository
  Future<List<Map<String, dynamic>>> getExpensesRawForShift(int shiftId) async {
    final db = await dbHelper.database;
    return await db.query(
      'expenses',
      where: 'shift_id = ?',
      whereArgs: [shiftId],
      orderBy: 'id DESC',
    );
  }
  // 3. جلب إجمالي المصروفات لشهر معين
  Future<double> getTotalExpensesForMonth(int month, int year) async {
    final db = await dbHelper.database;
    final startDate = DateTime(year, month, 1).toIso8601String();
    final endDate = DateTime(year, month + 1, 1).toIso8601String();
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM expenses
      WHERE date >= ? AND date < ?
    ''', [startDate, endDate]);
    return (result.first['total'] as num).toDouble();
  }

  // 4. حذف مصروف
  Future<void> deleteExpense(int id) async {
    final db = await dbHelper.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // 5. جلب إجمالي المصروفات لوردية محددة
  Future<double> getTotalExpensesForShift(int shiftId) async {
    final db = await dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE shift_id = ?
    ''', [shiftId]);
    return (result.first['total'] as num).toDouble();
  }
}