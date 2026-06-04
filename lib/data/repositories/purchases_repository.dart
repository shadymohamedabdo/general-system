import '../database_helper.dart';
import '../models/purchase_model.dart';

class PurchasesRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<void> addPurchase(PurchaseItem purchase) async {
    final db = await dbHelper.database;
    await db.insert('purchases', purchase.toMap());
    // ❌ لا نعرض Snackbar هنا
  }

  Future<List<PurchaseItem>> getPurchasesForMonthWithPagination(
      int month,
      int year, {
        int limit = 20,
        int offset = 0,
      }) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'purchases',
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
      orderBy: 'id DESC',
      limit: limit,
      offset: offset,
    );
    return result.map((e) => PurchaseItem.fromMap(e)).toList();
  }

  Future<List<PurchaseItem>> getAllPurchases() async {
    final db = await dbHelper.database;
    final result = await db.query('purchases', orderBy: 'id DESC');
    return result.map((e) => PurchaseItem.fromMap(e)).toList();
  }

  Future<List<PurchaseItem>> getPurchasesForMonth(int month, int year) async {
    final db = await dbHelper.database;
    final result = await db.query(
      'purchases',
      where: 'month = ? AND year = ?',
      whereArgs: [month, year],
    );
    return result.map((e) => PurchaseItem.fromMap(e)).toList();
  }

  Future<bool> deletePurchase(int id) async {
    final db = await dbHelper.database;
    final result = await db.delete('purchases', where: 'id = ?', whereArgs: [id]);
    return result > 0;
  }
}