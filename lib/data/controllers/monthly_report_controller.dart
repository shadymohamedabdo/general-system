import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/constants.dart';
import '../repositories/reports_repository.dart';
import '../repositories/purchases_repository.dart';
import '../repositories/dashboard_repository.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';

class MonthlyReportController extends GetxController {
  final ReportsRepository _repo = ReportsRepository();
  final PurchasesRepository _purchasesRepo = PurchasesRepository();
  final DashboardRepository _dashboardRepo = DashboardRepository();

  // الحالة
  var isLoading = true.obs;
  var errorMessage = "".obs;

  // البيانات المجلوبة
  var salesData = <SaleItem>[].obs;
  var purchases = <PurchaseItem>[].obs;

  // إحصائيات الأرباح المفصلة
  var totalSales = 0.0.obs;
  var totalPurchaseCost = 0.0.obs;
  var totalExpenses = 0.0.obs;
  var netProfit = 0.0.obs;

  // الجدول النهائي المعروض
  var tableData = <Map<String, dynamic>>[].obs;

  // فلاتر التقرير
  var selectedMonth = DateTime.now().month.obs;
  var selectedYear = DateTime.now().year.obs;

  // نموذج الإدخال الجانبي
  var showAddPurchaseForm = false.obs;
  final productNameCtrl = TextEditingController();
  final quantityCtrl = TextEditingController();
  final costPerUnitCtrl = TextEditingController(); // 🟢 يستقبل الآن: سعر الكيلو / الوحدة الواحد
  final totalCostCtrl = TextEditingController();   // 🔥 الجديد: التكلفة الإجمالية المحسوبة تلقائياً

  var selectedCategory = 'بن'.obs;
  var selectedUnit = 'كيلو'.obs;

  final List<String> categories = ['بن', 'مشروب', 'أكل سريع'];

  // الـ Pagination للمشتريات
  var currentPage = 1.obs;
  var hasMoreData = true.obs;
  var isLoadingMore = false.obs;
  final int pageSize = 20;

  @override
  void onInit() {
    super.onInit();
    loadReport();

    // 🔥 مراقبة حقل الكمية وسعر الوحدة لحظياً لتحديث الإجمالي تلقائياً
    quantityCtrl.addListener(_calculateTotalCost);
    costPerUnitCtrl.addListener(_calculateTotalCost);

    ever(selectedCategory, (cat) {
      updateUnitFromCategory(cat);
    });
  }

  // ✨ دالة الحساب التلقائي السحرية
  void _calculateTotalCost() {
    final double qty = double.tryParse(quantityCtrl.text.trim()) ?? 0.0;
    final double price = double.tryParse(costPerUnitCtrl.text.trim()) ?? 0.0;

    if (qty > 0 && price > 0) {
      final double total = qty * price;
      // لو الرقم صحيح بنعرضه بدون فاصلة عشرية، لو كسر بنعرض رقمين بعد الفاصلة
      totalCostCtrl.text = total % 1 == 0 ? '${total.toInt()}' : total.toStringAsFixed(2);
    } else {
      totalCostCtrl.text = ''; // تفريغ الحقل لو الخانات فاضية
    }
  }

  void updateUnitFromCategory(String category) {
    switch (category) {
      case 'بن':
        selectedUnit.value = 'كيلو';
        break;
      case 'مشروب':
        selectedUnit.value = 'كوب';
        break;
      case 'أكل سريع':
        selectedUnit.value = 'قطعة';
        break;
      default:
        selectedUnit.value = 'قطعة';
    }
  }

  void changeMonth(int month) {
    selectedMonth.value = month;
    loadReport();
  }

  void changeYear(int year) {
    selectedYear.value = year;
    loadReport();
  }

  Future<void> loadReport() async {
    try {
      isLoading(true);
      errorMessage("");

      int month = selectedMonth.value;
      int year = selectedYear.value;

      final sales = await _repo.getMonthlyReport(month, year);
      salesData.assignAll(sales.map((e) => SaleItem.fromMap(e)).toList());
      totalSales.value = salesData.fold(0.0, (sum, item) => sum + item.totalAmount);

      totalExpenses.value = await _dashboardRepo.getMonthlyExpenses(month, year);

      currentPage.value = 1;
      hasMoreData.value = true;
      purchases.clear();

      await loadPurchasesPage(month, year, 1);
    } catch (e) {
      errorMessage.value = "فشل في جلب التقرير: $e";
      AppSnackbar.error("خطأ في التحميل: $e");
    } finally {
      isLoading(false);
    }
  }

  Future<void> loadPurchasesPage(int month, int year, int page) async {
    if (isLoadingMore.value) return;

    try {
      isLoadingMore(true);
      final offset = (page - 1) * pageSize;
      final newPurchases = await _purchasesRepo.getPurchasesForMonthWithPagination(
        month,
        year,
        limit: pageSize,
        offset: offset,
      );

      if (newPurchases.isEmpty) {
        hasMoreData.value = false;
        if (page == 1) purchases.clear();
      } else {
        if (page == 1) {
          purchases.assignAll(newPurchases);
        } else {
          purchases.addAll(newPurchases);
        }
        if (newPurchases.length < pageSize) hasMoreData.value = false;
      }

      updateTableData();
      totalPurchaseCost.value = purchases.fold(0.0, (sum, p) => sum + p.totalCost);
      calculateNetProfit();
    } catch (e) {
      AppSnackbar.error("خطأ في جلب صفحة المصروفات: $e");
    } finally {
      isLoadingMore(false);
    }
  }

  Future<void> loadNextPage() async {
    if (!hasMoreData.value || isLoadingMore.value) return;

    currentPage.value++;
    await loadPurchasesPage(
      selectedMonth.value,
      selectedYear.value,
      currentPage.value,
    );
  }

  void updateTableData() {
    final Map<String, Map<String, dynamic>> combined = {};

    for (var sale in salesData) {
      final normalizedName = sale.productName.trim().toLowerCase();

      if (combined.containsKey(normalizedName)) {
        combined[normalizedName]!['sold_quantity'] += sale.totalQuantity;
        combined[normalizedName]!['sales_amount'] += sale.totalAmount;
      } else {
        combined[normalizedName] = {
          'product_name': sale.productName,
          'sold_quantity': sale.totalQuantity,
          'sales_amount': sale.totalAmount,
          'purchased_quantity': 0.0,
          'purchase_cost': 0.0,
          'unit': sale.unit,
        };
      }
    }

    for (var purchase in purchases) {
      final normalizedName = purchase.productName.trim().toLowerCase();

      if (combined.containsKey(normalizedName)) {
        combined[normalizedName]!['purchased_quantity'] += purchase.quantity;
        combined[normalizedName]!['purchase_cost'] += purchase.totalCost;
      } else {
        combined[normalizedName] = {
          'product_name': purchase.productName,
          'sold_quantity': 0.0,
          'sales_amount': 0.0,
          'purchased_quantity': purchase.quantity,
          'purchase_cost': purchase.totalCost,
          'unit': purchase.unit,
        };
      }
    }

    tableData.value = combined.values.toList();
  }

  void calculateNetProfit() {
    netProfit.value = totalSales.value - totalPurchaseCost.value - totalExpenses.value;
  }

  // ➕ حفظ المصروف الجديد بعد الحساب التلقائي
  Future<void> addPurchase() async {
    if (productNameCtrl.text.isEmpty) {
      AppSnackbar.warning("يرجى إدخال اسم المصروف أو المنتج");
      return;
    }

    final quantity = double.tryParse(quantityCtrl.text) ?? 0;
    if (quantity <= 0) {
      AppSnackbar.warning("الكمية يجب أن تكون أكبر من صفر");
      return;
    }

    // 🔥 تم التعديل لتصبح القراءة من حقل الإجمالي التلقائي المباشر
    final totalCost = double.tryParse(totalCostCtrl.text) ?? 0;
    if (totalCost <= 0) {
      AppSnackbar.warning("القيمة الإجمالية يجب أن تكون أكبر من صفر (تأكد من إدخال السعر)");
      return;
    }

    // سعر الوحدة الواحدة جاهز ومقروء من حقل السعر الذي أدخله المستخدم
    final pricePerUnit = double.tryParse(costPerUnitCtrl.text) ?? 0;

    try {
      final purchase = PurchaseItem(
        productName: productNameCtrl.text.trim(),
        quantity: quantity,
        unit: selectedUnit.value,
        costPerUnit: pricePerUnit, // نمرر سعر الوحدة الصافي للداتابيز بآمان
        month: selectedMonth.value,
        year: selectedYear.value,
      );

      await _purchasesRepo.addPurchase(purchase);

      clearForm();
      showAddPurchaseForm.value = false;
      await loadReport();
      AppSnackbar.success("تم الحفظ في الحسابات بنجاح");
    } catch (e) {
      AppSnackbar.error("فشل في حفظ البيانات: $e");
    }
  }

  Future<void> deletePurchase(int id, String productName) async {
    try {
      isLoading(true);
      final deleted = await _purchasesRepo.deletePurchase(id);

      if (deleted) {
        purchases.removeWhere((p) => p.id == id);
        await loadReport();
        AppSnackbar.success("تم الحذف وتحديث الأرباح");
      }
    } catch (e) {
      AppSnackbar.error("خطأ أثناء الحذف");
    } finally {
      isLoading(false);
    }
  }

  void clearForm() {
    productNameCtrl.clear();
    quantityCtrl.clear();
    costPerUnitCtrl.clear();
    totalCostCtrl.clear(); // تصفير خانة الإجمالي المحسوب
    selectedCategory.value = 'بن';
  }

  @override
  void onClose() {
    productNameCtrl.dispose();
    quantityCtrl.dispose();
    costPerUnitCtrl.dispose();
    totalCostCtrl.dispose(); // تنظيف خانة الإجمالي لمنع الـ Memory Leaks
    super.onClose();
  }
}