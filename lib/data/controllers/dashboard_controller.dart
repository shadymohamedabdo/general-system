import 'package:get/get.dart';
import '../models/dashboard_model.dart';
import '../repositories/dashboard_repository.dart';

class DashboardController extends GetxController {
  final _repo = DashboardRepository();

  var dailySales = <DailySale>[].obs;
  var topProducts = <ProductSale>[].obs;
  var isLoading = true.obs;
  var hasError = false.obs;
  var errorMessage = ''.obs;

  // 🗓️ متغيرات الفلتر
  var selectedMonth = DateTime.now().month.obs;
  var selectedYear = DateTime.now().year.obs;

  // 💰 متغيرات الكارت العلوي الديناميكية
  var totalSales = 0.0.obs;
  var totalPurchases = 0.0.obs;
  var totalExpenses = 0.0.obs;
  var netProfit = 0.0.obs;

  // Cache للبيانات المحسوبة
  var maxDailySales = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    loadAllData();
  }

  Future<void> loadAllData() async {
    try {
      isLoading(true);
      hasError(false);
      errorMessage('');

      int month = selectedMonth.value;
      int year = selectedYear.value;

      final rawSales = await _repo.getDailySales(month, year);
      final products = await _repo.getTopProducts(month, year);

      // 1. جلب المصروفات الحقيقية (يدوي + استهلاك)
      totalExpenses.value = await _repo.getMonthlyExpenses(month, year);

      // 2. حساب إجمالي المبيعات
      totalSales.value = rawSales.fold(0.0, (sum, e) => sum + e.total);

      // 🔥 3. جلب المشتريات الحقيقية للشهر والسنة المحددة بدلاً من تصفيرها
      totalPurchases.value = await _repo.getMonthlyPurchases(month, year);

      // 4. الحسبة المالية لصافي الأرباح (المبيعات - المشتريات - المصروفات)
      netProfit.value = totalSales.value - totalPurchases.value - totalExpenses.value;

      // 5. بناء الشارت
      int daysInMonth = DateTime(year, month + 1, 0).day;
      List<DailySale> fullMonth = [];

      for (int i = 1; i <= daysInMonth; i++) {
        final found = rawSales.firstWhere(
              (s) => s.day == i,
          orElse: () => DailySale(day: i, total: 0.0),
        );
        fullMonth.add(DailySale(day: i, total: found.total));
      }

      dailySales.assignAll(fullMonth);
      topProducts.assignAll(products);

      if (fullMonth.isNotEmpty) {
        maxDailySales.value = fullMonth.map((e) => e.total).reduce((a, b) => a > b ? a : b) * 1.2;
      }
    } catch (e) {
      hasError(true);
      errorMessage('فشل في تحميل البيانات: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  void changeMonth(int month) {
    selectedMonth.value = month;
    loadAllData();
  }

  void changeYear(int year) {
    selectedYear.value = year;
    loadAllData();
  }
}