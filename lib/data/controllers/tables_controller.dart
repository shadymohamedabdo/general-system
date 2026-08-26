// controllers/tables_controller.dart
import 'package:get/get.dart';
import '../database_helper.dart';
import '../models/table_session_model.dart';

class TablesController extends GetxController {
  final dbHelper = DatabaseHelper.instance;

  var tables = <TableSession>[].obs;
  var selectedTable = RxnInt();
  var currentOrders = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadTables();
    DatabaseHelper.tablesStream.listen((_) => loadTables());
  }

  Future<void> loadTables() async {
    isLoading(true);
    final data = await dbHelper.getAllTablesWithTotals();
    tables.assignAll(data.map((e) => TableSession.fromMap(e)).toList());
    isLoading(false);
  }

  void selectTable(int tableNum) async {
    selectedTable.value = tableNum;
    await loadCurrentOrders(tableNum);
  }

  Future<void> loadCurrentOrders(int tableNum) async {
    final orders = await dbHelper.getTableOrders(tableNum);
    currentOrders.assignAll(orders);
  }

  // إرسال للبار / المطبخ (طباعة KOT)
  Future<void> sendToKitchen() async {
    if (selectedTable.value == null) return;
    await dbHelper.markOrdersAsSentToKitchen(selectedTable.value!);
    await loadCurrentOrders(selectedTable.value!);
    Get.snackbar("نجاح", "تم إرسال الطلبات للبار/المطبخ");
  }

  // إغلاق الحساب ودفع الفاتورة
  Future<void> checkoutTable(int userId) async {
    if (selectedTable.value == null) return;
    int tableNum = selectedTable.value!;

    // 1. تحويل كافة طلبات الترابيزة لجدول المبيعات النهائي sales
    final orders = await dbHelper.getTableOrders(tableNum);
    int? shiftId = await dbHelper.getOpenShiftId();

    if (shiftId != null) {
      final db = await dbHelper.database;
      for (var item in orders) {
        await db.insert('sales', {
          'product_id': item['product_id'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'total_amount': item['total_price'],
          'user_id': userId,
          'shift_id': shiftId,
          'status': 'active',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }

    // 2. تفريغ الترابيزة وإغلاق الجلسة
    await dbHelper.clearTableSession(tableNum);
    selectedTable.value = null;
    currentOrders.clear();
    DatabaseHelper.notifySalesChanged();
    Get.snackbar("تم الحساب", "تم تسوية حساب ترابيزة $tableNum وبدء شيفت جديد لها");
  }
}