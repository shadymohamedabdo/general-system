import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:device_info_plus/device_info_plus.dart'; // 👈 إضافة حزمة الهاردوير الفريدة للويندوز

/// كلاس مسؤول عن إدارة قاعدة البيانات بالكامل مع الحماية الذكية ضد النقل
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _db;

  DatabaseHelper._init();

  static final _salesStreamController = StreamController<void>.broadcast();
  static final _shiftsStreamController = StreamController<void>.broadcast();

  static Stream<void> get salesStream => _salesStreamController.stream;
  static Stream<void> get shiftsStream => _shiftsStreamController.stream;
  static void notifySalesChanged() => _salesStreamController.add(null);
  static void notifyShiftsChanged() => _shiftsStreamController.add(null);
  static void disposeStreams() {
    _salesStreamController.close();
    _shiftsStreamController.close();
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB('coffee_pos.db');
    return _db!;
  }

  Future<Database> _initDB(String filePath) async {
    sqfliteFfiInit();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 15, // 🛠️ تم الرفع إلى 15 لدعم القفل الصخري وسيريال بوردة الجهاز الفريد
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
        onConfigure: _onConfigure,
      ),
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<int?> getOpenShiftId() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'shifts',
      where: 'is_open = ?',
      whereArgs: [1],
      orderBy: 'id DESC',
      limit: 1,
    );
    return maps.isNotEmpty ? maps.first['id'] as int : null;
  }

  Future<void> _createDB(Database db, int version) async {
    // جدول المستخدمين
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        role TEXT,
        username TEXT UNIQUE,
        password TEXT,
        created_at TEXT
      )
    ''');

    // جدول المنتجات المضاف إليه عمود initial_stock
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        category TEXT,
        unit TEXT,
        price REAL,
        cost_price REAL DEFAULT 0,
        initial_stock REAL DEFAULT 0.0
      )
    ''');

    // جدول الشيفتات
    await db.execute('''
      CREATE TABLE shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        user_name TEXT,
        date TEXT,
        is_open INTEGER,
        start_time TEXT,
        end_time TEXT
      )
    ''');

    // جدول المبيعات
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER,
        quantity REAL,
        unit_price REAL,
        total_amount REAL,
        user_id INTEGER,
        shift_id INTEGER,
        status TEXT DEFAULT 'active',
        created_at TEXT,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (user_id) REFERENCES users(id),
        FOREIGN KEY (shift_id) REFERENCES shifts(id)
      )
    ''');

    // جدول المشتريات
    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_name TEXT,
        quantity REAL,
        unit TEXT,
        cost_per_unit REAL,
        month INTEGER,
        year INTEGER
      )
    ''');

    // جدول المصروفات المطور
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        title TEXT NOT NULL,
        notes TEXT,
        date TEXT NOT NULL,
        shift_id INTEGER,
        user_id INTEGER,
        created_at TEXT,
        FOREIGN KEY (shift_id) REFERENCES shifts(id)
      )
    ''');

    // 🛠️ جدول الأمان المحدث المضاف إليه عمود device_serial لربط الهاردوير
    await db.execute('''
      CREATE TABLE app_security (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trial_start TEXT,
        last_opened TEXT,
        is_activated INTEGER,
        device_serial TEXT DEFAULT '' -- 👈 العمود الجديد لمنع سرقة ونقل البيانات لفرع تانى
      )
    ''');

    // إضافة الفهارس لتحسين الأداء
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_shift_id ON expenses(shift_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_shift_id ON sales(shift_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shifts_is_open ON shifts(is_open)');

    await _createDefaultAdmin(db);
    await _initSecurityTable(db);
  }

  // 🧹 دالة تصفير النظام بالكامل
  Future<void> clearAllTransactionsData() async {
    final db = await database;

    await db.transaction((txn) async {
      await txn.delete('sales');
      await txn.delete('purchases');
      await txn.delete('expenses');
      await txn.delete('shifts');
      await txn.delete('products');
    });

    notifySalesChanged();
    notifyShiftsChanged();
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 9) {
      await db.execute("ALTER TABLE shifts ADD COLUMN user_name TEXT");
      await db.execute("UPDATE shifts SET start_time = NULL WHERE start_time NOT LIKE '202%'");
      await db.execute("UPDATE shifts SET end_time = NULL WHERE end_time NOT LIKE '202%' AND is_open = 0");
    }

    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE purchases (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_name TEXT,
          quantity REAL,
          unit TEXT,
          cost_per_unit REAL,
          month INTEGER,
          year INTEGER
        )
      ''');
    }

    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE app_security (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          trial_start TEXT,
          last_opened TEXT,
          is_activated INTEGER
        )
      ''');
      await _initSecurityTable(db);
    }

    if (oldVersion < 13) {
      await db.execute('DROP TABLE IF EXISTS expenses');
      await db.execute('''
        CREATE TABLE expenses (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          amount REAL NOT NULL,
          title TEXT NOT NULL,
          notes TEXT,
          date TEXT NOT NULL,
          shift_id INTEGER,
          user_id INTEGER,
          created_at TEXT,
          FOREIGN KEY (shift_id) REFERENCES shifts(id)
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_shift_id ON expenses(shift_id)');
    }

    if (oldVersion < 14) {
      try {
        await db.execute("ALTER TABLE products ADD COLUMN initial_stock REAL DEFAULT 0.0");
      } catch (e) {
        // تفادي الكراش لو العمود موجود بالفعل
      }
    }

    // 🆕 التحديث الجديد للإصدار 15 لزرع عمود ربط السيريال في حالة الأجهزة الحالية المفعّلة
    if (oldVersion < 15) {
      try {
        await db.execute("ALTER TABLE app_security ADD COLUMN device_serial TEXT DEFAULT ''");
      } catch (e) {
        // تفادي الكراش لو العمود موجود بالفعل
      }
    }
  }

  Future<void> _createDefaultAdmin(Database db) async {
    final result = await db.query('users', where: 'username = ?', whereArgs: ['shady']);
    if (result.isEmpty) {
      await db.insert('users', {
        'name': 'شادي',
        'role': 'admin',
        'username': 'shady',
        'password': '01032607563',
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _initSecurityTable(Database db) async {
    final result = await db.query('app_security');
    if (result.isEmpty) {
      String nowStr = DateTime.now().toIso8601String();
      await db.insert('app_security', {
        'trial_start': nowStr,
        'last_opened': nowStr,
        'is_activated': 0,
        'device_serial': '', // يترك فارغًا حتى وقت التنشيط الفعلي بكود الماجيك
      });
    }
  }

  /// 🛠️ دالة جلب السيريال الفريد للـ Motherboard وجهاز الويندوز برمجياً
  Future<String> getWindowsSerial() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final windowsInfo = await deviceInfo.windowsInfo;
      // استخراج الـ deviceId الفريد للنسخة والمكونات وإزالة الأقواس لتنظيف النص
      String serial = windowsInfo.deviceId.replaceAll('{', '').replaceAll('}', '').trim();
      return serial.isNotEmpty ? serial : "WINDOWS-UNKNOWN-PC";
    } catch (e) {
      return "WINDOWS-GENERIC-PC";
    }
  }

  Future<Map<String, dynamic>?> getSecurityData() async {
    final db = await database;
    final res = await db.query('app_security', limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> updateLastOpenedTime(String nowStr) async {
    final db = await database;
    await db.update('app_security', {'last_opened': nowStr}, where: 'id = ?', whereArgs: [1]);
  }

  /// 🛠️ تحديث دالة التفعيل لتأخذ وتغلق نظام التفعيل على سيريال الماذر بورد الحالي فقط
  Future<void> activateSystemFull(String currentSerial) async {
    final db = await database;
    await db.update(
        'app_security',
        {
          'is_activated': 1,
          'device_serial': currentSerial // قفل قاعدة البيانات على البوردة دي رسميًا
        },
        where: 'id = ?',
        whereArgs: [1]
    );
  }
}