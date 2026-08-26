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

      // ⚡ استدعاء البيانات بالتوازي لسرعة أفضل في التحميل
      final results = await Future.wait([
        _repo.getDailySales(month, year),
        _repo.getTopProducts(month, year),
        _repo.getMonthlyExpenses(month, year),
        _repo.getMonthlyPurchases(month, year),
      ]);

      final rawSales = results[0] as List<DailySale>;
      final products = results[1] as List<ProductSale>;
      final expensesVal = results[2] as double;
      final purchasesVal = results[3] as double;

      // 1. إسناد المصروفات والمشتريات
      totalExpenses.value = expensesVal;
      totalPurchases.value = purchasesVal;

      // 2. حساب إجمالي المبيعات (تيك أواي + ترابيزات)
      totalSales.value = rawSales.fold(0.0, (sum, e) => sum + e.total);

      // 3. الحسبة المالية لصافي الأرباح (المبيعات - المصروفات الكلية)
      netProfit.value = totalSales.value - totalExpenses.value;

      // 4. بناء الشارت لأيام الشهر بالكامل
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
        final maxSale = fullMonth.map((e) => e.total).reduce((a, b) => a > b ? a : b);
        maxDailySales.value = maxSale > 0 ? maxSale * 1.2 : 100.0;
      }
    } catch (e) {
      hasError(true);
      errorMessage('فشل في تحميل البيانات: ${e.toString()}');
    } finally {
      isLoading(false);
    }
  }

  void changeMonth(int month) {
    if (selectedMonth.value == month) return;
    selectedMonth.value = month;
    loadAllData();
  }

  void changeYear(int year) {
    if (selectedYear.value == year) return;
    selectedYear.value = year;
    loadAllData();
  }
}