// lib/data/repositories/shifts_repository.dart

import '../database_helper.dart';

class ShiftsRepository {
  final dbHelper = DatabaseHelper.instance;

  // تحديث هذه الميثود لاستقبال الـ limit والـ offset
  Future<List<Map<String, dynamic>>> getAllShifts({int limit = 20, int offset = 0}) async {
    final db = await dbHelper.database;

    // تمرير الـ limit والـ offset للاستعلام
    return await db.query(
      'shifts',
      orderBy: 'id DESC', // ترتيب من الأحدث للأقدم
      limit: limit,
      offset: offset,
    );
  }

  Future<Map<String, dynamic>?> getOpenShift() async {
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'shifts',
      where: 'is_open = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<void> openShift(String type, String userName) async {
    final db = await dbHelper.database;
    await db.insert('shifts', {
      'type': type,
      'user_name': userName,
      'date': DateTime.now().toIso8601String(),
      'is_open': 1,
      'start_time': DateTime.now().toIso8601String(),
    });
    DatabaseHelper.notifyShiftsChanged();
  }

  Future<void> closeShift(int id) async {
    final db = await dbHelper.database;
    await db.update(
      'shifts',
      {
        'is_open': 0,
        'end_time': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    DatabaseHelper.notifyShiftsChanged();
  }
}