import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../database_helper.dart';
import '../repositories/expenses_repository.dart';

class ProfitController extends GetxController {
  final _expenseRepo = ExpensesRepository();

  var isLoading = false.obs;
  var isRefreshing = false.obs;
  var isLoadingMore = false.obs; // مؤشر تحميل العناصر الإضافية

  var totalSales = 0.0.obs;
  var totalPurchases = 0.0.obs;
  var grossProfit = 0.0.obs;
  var totalExpenses = 0.0.obs;
  var netProfit = 0.0.obs;

  var activeShiftExpenses = <Map<String, dynamic>>[].obs;

  // 🗓️ متغيرات الفلترة الذكية (الافتراضي: الشهر والسنة الحاليين)
  var selectedMonth = DateTime.now().month.obs;
  var selectedYear = DateTime.now().year.obs;

  // 📊 إعدادات الـ Pagination (50 عنصر لكل سحبة)
  var currentPage = 1.obs;
  var hasMoreData = true.obs;
  final int pageSize = 50;

  final ScrollController scrollController = ScrollController();
  final titleCtrl = TextEditingController();
  final amountCtrl = TextEditingController();

  // لستة الشهور والسنين الجاهزة للقوائم المنسدلة
  final List<int> monthsList = List.generate(12, (index) => index + 1);
  final List<int> yearsList = List.generate(10, (index) => DateTime.now().year - 5 + index);

  @override
  void onInit() {
    super.onInit();
    // مراقبة السكرول: لو قفل الـ 50 عنصر ونزل تحت، يسحب الـ 50 اللي بعدهم تلقائياً 🎯
    scrollController.addListener(() {
      if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
        loadMoreExpenses();
      }
    });
    refreshData(reset: true);
  }

  @override
  void onClose() {
    scrollController.dispose();
    titleCtrl.dispose();
    amountCtrl.dispose();
    super.onClose();
  }

  // تحديث البيانات بالكامل أو جلب صفحات إضافية
  Future<void> refreshData({bool reset = true}) async {
    try {
      if (reset) {
        isRefreshing(true);
        currentPage.value = 1;
        hasMoreData.value = true;
        activeShiftExpenses.clear();

        // حساب المجموع الكلي للشهر الحالي من الداتابيز مباشرة لضمان دقة الكارت العلوي
        totalExpenses.value = await _expenseRepo.getTotalExpensesForMonth(selectedMonth.value, selectedYear.value);
      } else {
        isLoadingMore(true);
      }

      totalSales.value = 77320.88;
      totalPurchases.value = 1100.00;

      // جلب المصروفات بنظام الـ Pagination (50 عنصر) بناءً على الفلتر المختار
      final List<Map<String, dynamic>> rawData = await _expenseRepo.getExpensesPaginated(
        month: selectedMonth.value,
        year: selectedYear.value,
        limit: pageSize,
        offset: (currentPage.value - 1) * pageSize,
      );

      if (rawData.isEmpty) {
        hasMoreData.value = false;
      } else {
        if (reset) {
          activeShiftExpenses.assignAll(rawData);
        } else {
          activeShiftExpenses.addAll(rawData);
        }
        if (rawData.length < pageSize) hasMoreData.value = false;
      }

      calculateValues();
    } catch (e) {
      Get.snackbar("خطأ", "فشل في تحديث الحسابات والبيانات النقدية");
    } finally {
      isRefreshing(false);
      isLoadingMore(false);
    }
  }

  Future<void> loadMoreExpenses() async {
    if (!hasMoreData.value || isLoadingMore.value) return;
    currentPage.value++;
    await refreshData(reset: false);
  }

  // عند تغيير الشهر أو السنة من الشاشة فوق
  void updateDateFilter(int? month, int? year) {
    if (month != null) selectedMonth.value = month;
    if (year != null) selectedYear.value = year;
    refreshData(reset: true); // تصفير الـ 50 القدام وجلب أول 50 من الفلتر الجديد
  }

  void calculateValues() {
    grossProfit.value = totalSales.value - totalPurchases.value;
    netProfit.value = grossProfit.value - totalExpenses.value;
  }

  String formatDateTime(String rawDateTime) {
    try {
      DateTime dt = DateTime.parse(rawDateTime);
      int hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      String period = dt.hour >= 12 ? "م" : "ص";
      String minute = dt.minute.toString().padLeft(2, '0');

      return "$hour:$minute $period|${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    } catch (e) {
      return rawDateTime.contains(' ') ? rawDateTime : "$rawDateTime| ";
    }
  }

  Future<bool> saveManualExpense() async {
    String title = titleCtrl.text.trim();
    double? amount = double.tryParse(amountCtrl.text);

    if (title.isEmpty || amount == null || amount <= 0) {
      Get.snackbar("تنبيه", "برجاء كتابة اسم البند والمبلغ بشكل صحيح",
          backgroundColor: Colors.orange, colorText: Colors.white);
      return false;
    }

    try {
      isLoading(true);
      int? currentShiftId = await DatabaseHelper.instance.getOpenShiftId();
      int shiftIdToSave = currentShiftId ?? 1;

      final db = await DatabaseHelper.instance.database;

      await db.insert('expenses', {
        'shift_id': shiftIdToSave,
        'title': title,
        'amount': amount,
        'date': DateTime.now().toIso8601String().split('T')[0],
        'created_at': DateTime.now().toString(),
      });

      resetExpenses();
      await refreshData(reset: true);
      return true;
    } catch (e) {
      return false;
    } finally {
      isLoading(false);
    }
  }

  Future<bool> updateCustomExpense(int id, String newTitle, double newAmount) async {
    if (newTitle.isEmpty || newAmount <= 0) return false;
    try {
      isLoading(true);
      final db = await DatabaseHelper.instance.database;
      await db.update(
        'expenses',
        {'title': newTitle, 'amount': newAmount},
        where: 'id = ?',
        whereArgs: [id],
      );
      await refreshData(reset: true);
      return true;
    } catch (e) {
      return false;
    } finally {
      isLoading(false);
    }
  }

  Future<void> deleteExpense(int id) async {
    try {
      isLoading(true);
      final db = await DatabaseHelper.instance.database;
      await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
      await refreshData(reset: true);
    } finally {
      isLoading(false);
    }
  }

  void resetExpenses() {
    titleCtrl.clear();
    amountCtrl.clear();
  }
}