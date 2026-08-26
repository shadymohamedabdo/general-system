import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// كلاس مسؤول عن إدارة قاعدة البيانات بالكامل مع دعم الأنشطة الديناميكية والأمان ونظام الترابيزات المفتوحة
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _db;

  DatabaseHelper._init();

  static final _salesStreamController = StreamController<void>.broadcast();
  static final _shiftsStreamController = StreamController<void>.broadcast();
  static final _tablesStreamController = StreamController<void>.broadcast();

  static Stream<void> get salesStream => _salesStreamController.stream;
  static Stream<void> get shiftsStream => _shiftsStreamController.stream;
  static Stream<void> get tablesStream => _tablesStreamController.stream;

  static void notifySalesChanged() => _salesStreamController.add(null);
  static void notifyShiftsChanged() => _shiftsStreamController.add(null);
  static void notifyTablesChanged() => _tablesStreamController.add(null);

  static void disposeStreams() {
    _salesStreamController.close();
    _shiftsStreamController.close();
    _tablesStreamController.close();
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
        version: 17, // 🛠️ تم الرفع إلى 17 لدعم جداول الترابيزات والجلسات المفتوحة
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
    // 1️⃣ جدول المستخدمين
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

    // 2️⃣ جدول الأقسام الديناميكية (Categories)
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    // 3️⃣ جدول الوحدات الديناميكية (Units)
    await db.execute('''
      CREATE TABLE units (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    // 4️⃣ جدول المنتجات المطور
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

    // 5️⃣ جدول الشيفتات
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

    // 6️⃣ جدول المبيعات
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

    // 7️⃣ جدول المشتريات
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

    // 8️⃣ جدول المصروفات
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

    // 9️⃣ جدول الأمان المحدث لربط الهاردوير
    await db.execute('''
      CREATE TABLE app_security (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trial_start TEXT,
        last_opened TEXT,
        is_activated INTEGER,
        device_serial TEXT DEFAULT ''
      )
    ''');

    // 🔟 جدول الترابيزات (1 لـ 30)
    await db.execute('''
      CREATE TABLE tables (
        table_number INTEGER PRIMARY KEY,
        is_open INTEGER DEFAULT 0,
        opened_at TEXT
      )
    ''');

    // 1️⃣1️⃣ جدول طلبات الترابيزات المفتوحة (تظل متجمعة لحين الحساب النهائي)
    await db.execute('''
      CREATE TABLE table_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_number INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        is_sent_to_kitchen INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (table_number) REFERENCES tables(table_number) ON DELETE CASCADE
      )
    ''');

    // إضافة الفهارس لتحسين الأداء
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_expenses_shift_id ON expenses(shift_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_shift_id ON sales(shift_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_shifts_is_open ON shifts(is_open)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_table_orders_table_num ON table_orders(table_number)');

    await _createDefaultAdmin(db);
    await _initSecurityTable(db);
    await _insertDefaultCategoriesAndUnits(db);
    await _initDefaultTables(db);
  }

  /// إنشاء الترابيزات الـ 30 تلقائياً لأول مرة
  Future<void> _initDefaultTables(Database db) async {
    for (int i = 1; i <= 30; i++) {
      await db.insert(
        'tables',
        {'table_number': i, 'is_open': 0, 'opened_at': null},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> _insertDefaultCategoriesAndUnits(Database db) async {
    List<String> defaultCategories = ['بن', 'مشروب', 'أكل سريع / أخرى'];
    for (var cat in defaultCategories) {
      await db.insert('categories', {'name': cat}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    List<String> defaultUnits = ['كيلو', 'كوب', 'قطعة', 'علبة', 'شريط'];
    for (var unit in defaultUnits) {
      await db.insert('units', {'name': unit}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> clearAllTransactionsData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sales');
      await txn.delete('purchases');
      await txn.delete('expenses');
      await txn.delete('shifts');
      await txn.delete('products');
      await txn.delete('table_orders');
      await txn.update('tables', {'is_open': 0, 'opened_at': null});
    });
    notifySalesChanged();
    notifyShiftsChanged();
    notifyTablesChanged();
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
      } catch (e) {}
    }
    if (oldVersion < 15) {
      try {
        await db.execute("ALTER TABLE app_security ADD COLUMN device_serial TEXT DEFAULT ''");
      } catch (e) {}
    }
    if (oldVersion < 16) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS units (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE
          )
        ''');
        await _insertDefaultCategoriesAndUnits(db);
      } catch (e) {}
    }
    if (oldVersion < 17) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS tables (
            table_number INTEGER PRIMARY KEY,
            is_open INTEGER DEFAULT 0,
            opened_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS table_orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            table_number INTEGER NOT NULL,
            product_id INTEGER,
            product_name TEXT NOT NULL,
            quantity REAL NOT NULL,
            unit_price REAL NOT NULL,
            total_price REAL NOT NULL,
            is_sent_to_kitchen INTEGER DEFAULT 0,
            created_at TEXT NOT NULL,
            FOREIGN KEY (table_number) REFERENCES tables(table_number) ON DELETE CASCADE
          )
        ''');

        await db.execute('CREATE INDEX IF NOT EXISTS idx_table_orders_table_num ON table_orders(table_number)');
        await _initDefaultTables(db);
      } catch (e) {}
    }
  }

  // ==========================================
  // 🍽️ دوال التعامل مع الترابيزات المفتوحة
  // ==========================================

  /// جلب كافة طلبات ترابيزة معينة
  Future<List<Map<String, dynamic>>> getTableOrders(int tableNumber) async {
    final db = await database;
    return await db.query(
      'table_orders',
      where: 'table_number = ?',
      whereArgs: [tableNumber],
      orderBy: 'id ASC',
    );
  }

  /// إدخال عنصر جديد لطلب ترابيزة مفتوحة
  Future<void> addOrUpdateTableOrderItem({
    required int tableNumber,
    required int? productId,
    required String productName,
    required double quantity,
    required double unitPrice,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 1. فتح الترابيزة لو كانت مقفولة
      await txn.rawUpdate(
        '''UPDATE tables SET is_open = 1, opened_at = COALESCE(opened_at, ?) WHERE table_number = ?''',
        [now, tableNumber],
      );

      // 2. فحص إذا كان المنتج غير مطبوع بعد للمطبخ لدمج الكمية
      final existing = await txn.query(
        'table_orders',
        where: 'table_number = ? AND product_name = ? AND is_sent_to_kitchen = 0',
        whereArgs: [tableNumber, productName],
      );

      if (existing.isNotEmpty) {
        double currentQty = (existing.first['quantity'] as num).toDouble();
        double newQty = currentQty + quantity;
        double newTotal = newQty * unitPrice;

        await txn.update(
          'table_orders',
          {'quantity': newQty, 'total_price': newTotal},
          where: 'id = ?',
          whereArgs: [existing.first['id']],
        );
      } else {
        await txn.insert('table_orders', {
          'table_number': tableNumber,
          'product_id': productId,
          'product_name': productName,
          'quantity': quantity,
          'unit_price': unitPrice,
          'total_price': quantity * unitPrice,
          'is_sent_to_kitchen': 0,
          'created_at': now,
        });
      }
    });

    notifyTablesChanged();
  }

  /// تعليم طلبات المطبخ الجديدة بأنها أُرسلت وطُبعت
  Future<void> markOrdersAsSentToKitchen(int tableNumber) async {
    final db = await database;
    await db.update(
      'table_orders',
      {'is_sent_to_kitchen': 1},
      where: 'table_number = ? AND is_sent_to_kitchen = 0',
      whereArgs: [tableNumber],
    );
    notifyTablesChanged();
  }

  /// إغلاق حساب الترابيزة وتفريغ الطلبات (عند دفع الفاتورة ومغادرة الزبون)
  Future<void> clearTableSession(int tableNumber) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('table_orders', where: 'table_number = ?', whereArgs: [tableNumber]);
      await txn.update('tables', {'is_open': 0, 'opened_at': null}, where: 'table_number = ?', whereArgs: [tableNumber]);
    });
    notifyTablesChanged();
  }

  /// جلب كافة الترابيزات الـ 30 مع حالة كل منها والإجمالي
  Future<List<Map<String, dynamic>>> getAllTablesWithTotals() async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT 
        t.table_number,
        t.is_open,
        t.opened_at,
        COALESCE(SUM(o.total_price), 0.0) AS total_amount,
        COUNT(o.id) AS items_count
      FROM tables t
      LEFT JOIN table_orders o ON t.table_number = o.table_number
      GROUP BY t.table_number
      ORDER BY t.table_number ASC
    ''');
    return res;
  }

  // ==========================================
  // 🔐 الأمان والمستخدمين والشيفتات
  // ==========================================

  Future<void> _createDefaultAdmin(Database db) async {
    final result = await db.query('users', where: 'username = ?', whereArgs: ['shady']);
    if (result.isEmpty) {
      await db.insert('users', {
        'name': 'شادي',
        'role': 'admin',
        'username': 'shady',
        'password': '1234',
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _initSecurityTable(Database db) async {
    final result = await db.query('app_security');
    if (result.isEmpty) {
      String nowStr = DateTime.now().toIso8601String();
      String currentSerial = await getWindowsSerial();
      await db.insert('app_security', {
        'trial_start': nowStr,
        'last_opened': nowStr,
        'is_activated': 0,
        'device_serial': currentSerial,
      });
    }
  }

  /// 🛠️ دالة جلب السيريال الفريد للـ Motherboard وجهاز الويندوز برمجياً
  Future<String> getWindowsSerial() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final windowsInfo = await deviceInfo.windowsInfo;
      String serial = windowsInfo.deviceId.replaceAll('{', '').replaceAll('}', '').trim();
      return serial.isNotEmpty ? serial : "WINDOWS-UNKNOWN-PC";
    } catch (e) {
      return "WINDOWS-GENERIC-PC";
    }
  }

  /// 🧠 فحص حالة الأمان وإدارة الأسبوع التجريبي (7 أيام) ومنع التلاعب بالتاريخ
  Future<String> checkSystemSecurityStatus() async {
    final db = await database;
    String currentWindowsSerial = await getWindowsSerial();

    final List<Map<String, dynamic>> res = await db.query('app_security', limit: 1);
    if (res.isEmpty) {
      await _initSecurityTable(db);
      return "TRIAL_ACTIVE";
    }

    final securityData = res.first;
    String savedSerial = securityData['device_serial'] ?? '';
    int isActivated = securityData['is_activated'] ?? 0;
    String lastOpenedStr = securityData['last_opened'] ?? '';

    // 🎯 كشف النقل (لو أخد الداتابيز من جهاز قديم وحطها على جهاز جديد)
    if (savedSerial.isNotEmpty && savedSerial != currentWindowsSerial) {
      String nowStr = DateTime.now().toIso8601String();

      // تصفير التفعيل فوراً وبدء أسبوع تجريبي جديد خاص بالبوردة الجديدة!
      await db.update('app_security', {
        'trial_start': nowStr,
        'last_opened': nowStr,
        'is_activated': 0,
        'device_serial': currentWindowsSerial,
      }, where: 'id = ?', whereArgs: [1]);

      return "TRIAL_ACTIVE";
    }

    // 🔒 كشف التلاعب بالساعة
    DateTime now = DateTime.now();
    if (lastOpenedStr.isNotEmpty) {
      DateTime lastOpened = DateTime.parse(lastOpenedStr);
      if (now.isBefore(lastOpened)) {
        return "TIME_TAMPERED";
      }
    }

    // لو النسخة متفعلة رسمي مدى الحياة.. يفتح فوراً
    if (isActivated == 1) {
      await updateLastOpenedTime(now.toIso8601String());
      return "ACTIVATED_FULL";
    }

    // حساب فترة الـ 7 أيام التجريبية
    DateTime trialStart = DateTime.parse(securityData['trial_start']);
    int daysPassed = now.difference(trialStart).inDays;

    if (daysPassed >= 7 || daysPassed < 0) {
      return "EXPIRED";
    } else {
      await updateLastOpenedTime(now.toIso8601String());
      return "TRIAL_ACTIVE";
    }
  }

  /// دالة مركزية للتحقق من كود التفعيل اليومي بالتاريخ الكامل
  bool verifyDailyActivationCode(String inputCode) {
    String cleanedInput = inputCode.trim().replaceAll(' ', '').toLowerCase();

    final now = DateTime.now();
    final String dayStr = now.day.toString().padLeft(2, '0');
    final String monthStr = now.month.toString().padLeft(2, '0');
    final String yearStr = now.year.toString();

    final String dynamicDailyPassword = "shady112001$dayStr$monthStr$yearStr";

    return cleanedInput.isNotEmpty && cleanedInput == dynamicDailyPassword;
  }

  // 🛑 درع حماية الأدمن الرئيسي: يمنع تماماً حذف حساب شادي
  Future<int> deleteUser(int userId, String username) async {
    if (username.trim().toLowerCase() == 'shady') {
      print("🚨 محاولة محظورة لحذف الأدمن الرئيسي المالك للنظام!");
      return 0;
    }

    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<Map<String, dynamic>> getSecurityData() async {
    final db = await database;
    final res = await db.query('app_security', limit: 1);
    return res.isNotEmpty ? res.first : {};
  }

  Future<void> updateLastOpenedTime(String nowStr) async {
    final db = await database;
    await db.update('app_security', {'last_opened': nowStr}, where: 'id = ?', whereArgs: [1]);
  }

  Future<void> activateSystemFull(String currentSerial) async {
    final db = await database;
    await db.update(
        'app_security',
        {
          'is_activated': 1,
          'device_serial': currentSerial
        },
        where: 'id = ?',
        whereArgs: [1]
    );
  }
}