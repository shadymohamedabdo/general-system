import '../database_helper.dart';

class UsersRepository {
  final dbHelper = DatabaseHelper.instance;

  // 1️⃣ تعديل جلب الموظفين: لعرض المستخدمين النشطين فقط وإخفاء الحسابات المحذوفة
  Future<List<Map<String, dynamic>>> getAllEmployees() async {
    final db = await dbHelper.database;
    // بنجيب الموظفين اللي الـ role بتاعهم مش 'archived' مرتبين أبجدياً
    return await db.query(
      'users',
      where: 'role != ?',
      whereArgs: ['archived'],
      orderBy: 'name ASC',
    );
  }

  Future<void> addUser({
    required String name,
    required String username,
    required String password,
    required String role,
  }) async {
    final db = await dbHelper.database;
    await db.insert('users', {
      'name': name,
      'username': username,
      'password': password,
      'role': role,
    });
  }

  // 2️⃣ تعديل دالة الحذف: لتصفير يوزر وباسورد الموظف بدل مسحه نهائياً لتفادي كراش الحسابات
  Future<List<Map<String, dynamic>>> deleteUser(int id) async {
    final db = await dbHelper.database;

    // ✅ الحل: نضع قيم فريدة لكل مستخدم محذوف لتجنب الـ UNIQUE constraint failed
    await db.update(
      'users',
      {
        'name': 'موظف محذوف',
        'username': 'deleted_$id', // 🔥 هيتخزن كـ deleted_7 ومستحيل يتكرر!
        'password': '',
        'role': 'archived',
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    // إرجاع القائمة الجديدة بعد التحديث (الموظفين النشطين فقط)
    return await getAllEmployees();
  }
  Future<Map<String, dynamic>?> login(String username, String password) async {
    final db = await dbHelper.database;

    // 💡 تأمين إضافي: لو اليوزر باصى مسافات أو بيانات فاضية بالخطأ، نمنع تسجيل الدخول
    if (username.trim().isEmpty || password.trim().isEmpty) return null;

    final result = await db.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
      limit: 1,
    );
    return result.isNotEmpty ? result.first : null;
  }
}