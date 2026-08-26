import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/constants.dart';
import '../database_helper.dart'; // 👈 استيراد الداتابيز لجلب الفئات والوحدات
import '../repositories/reports_repository.dart';
import '../repositories/purchases_repository.dart';
import '../repositories/dashboard_repository.dart';
import '../models/purchase_model.dart';
import '../models/sale_model.dart';

class MonthlyReportController extends GetxController {
  final ReportsRepository _repo = ReportsRepository();
  final PurchasesRepository _purchasesRepo = PurchasesRepository();
  final DashboardRepository _dashboardRepo = DashboardRepository();
  final dbHelper = DatabaseHelper.instance;

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
  // 🔍 متغير البحث
  var searchQuery = ''.obs;

  // ⚡ قائمة التقرير المفلترة لحظياً بناءً على كلمة البحث
  List<Map<String, dynamic>> get filteredTableData {
    if (searchQuery.value.trim().isEmpty) {
      return tableData;
    }
    final query = searchQuery.value.trim().toLowerCase();
    return tableData.where((row) {
      final productName = (row['product_name'] ?? '').toString().toLowerCase();
      return productName.contains(query);
    }).toList();
  }

  // فلاتر التقرير
  var selectedMonth = DateTime.now().month.obs;
  var selectedYear = DateTime.now().year.obs;

  // نموذج الإدخال
  var showAddPurchaseForm = false.obs;
  final productNameCtrl = TextEditingController();
  final quantityCtrl = TextEditingController();
  final costPerUnitCtrl = TextEditingController();
  final totalCostCtrl = TextEditingController();

  // 🆕 قوائم ديناميكية للفئات والوحدات بدلاً من القيم الثابتة
  var categories = <String>[].obs;
  var unitsList = <String>[].obs;
  var selectedCategory = 'بن'.obs;
  var selectedUnit = 'كيلو'.obs;

  // الـ Pagination للمشتريات
  var currentPage = 1.obs;
  var hasMoreData = true.obs;
  var isLoadingMore = false.obs;
  final int pageSize = 20;

  @override
  void onInit() {
    super.onInit();
    loadReport();

    // 🔄 مراقبة حقل الكمية وسعر الوحدة لحظياً لتحديث الإجمالي تلقائياً
    quantityCtrl.addListener(_calculateTotalCost);
    costPerUnitCtrl.addListener(_calculateTotalCost);

    // مراقبة الفئة لتحديث الوحدة ذكياً
    ever(selectedCategory, (String? cat) {
      if (cat != null) updateUnitFromCategory(cat);
    });
  }

  // ✨ دالة الحساب التلقائي اللحظية
  void _calculateTotalCost() {
    final double qty = double.tryParse(quantityCtrl.text.trim()) ?? 0.0;
    final double price = double.tryParse(costPerUnitCtrl.text.trim()) ?? 0.0;

    if (qty > 0 && price > 0) {
      final double total = qty * price;
      totalCostCtrl.text = total % 1 == 0 ? '${total.toInt()}' : total.toStringAsFixed(2);
    } else {
      totalCostCtrl.text = '';
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

      // 📥 جلب الفئات والوحدات الديناميكية من الداتابيز وإزالة أي تكرارات
      final db = await dbHelper.database;
      final catData = await db.query('categories');
      final unitData = await db.query('units');

      final fetchedCategories = catData
          .map((e) => e['name'] as String)
          .where((e) => e.trim().isNotEmpty)
          .toSet()
          .toList();

      final fetchedUnits = unitData
          .map((e) => e['name'] as String)
          .where((e) => e.trim().isNotEmpty)
          .toSet()
          .toList();

      categories.assignAll(fetchedCategories);
      unitsList.assignAll(fetchedUnits);

      // 🎯 تعيين أول عنصر ديناميكي متاح إذا كانت القيمة الحالية غير سليمة
      if (categories.isNotEmpty && !categories.contains(selectedCategory.value)) {
        selectedCategory.value = categories.first;
      }

      if (unitsList.isNotEmpty && !unitsList.contains(selectedUnit.value)) {
        selectedUnit.value = unitsList.first;
      }

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

  // 🔄 تحديث الوحدة ديناميكياً بدون شروط ثابتة
  void updateUnitFromCategory(String category) {
    if (unitsList.isNotEmpty && !unitsList.contains(selectedUnit.value)) {
      selectedUnit.value = unitsList.first;
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

    final totalCost = double.tryParse(totalCostCtrl.text) ?? 0;
    if (totalCost <= 0) {
      AppSnackbar.warning("القيمة الإجمالية يجب أن تكون أكبر من صفر (تأكد من إدخال السعر)");
      return;
    }

    final pricePerUnit = double.tryParse(costPerUnitCtrl.text) ?? 0;

    try {
      final purchase = PurchaseItem(
        productName: productNameCtrl.text.trim(),
        quantity: quantity,
        unit: selectedUnit.value,
        costPerUnit: pricePerUnit,
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

  // 📄📥 دالة إنشاء وحفظ ملف הـ PDF مباشرة على الجهاز
  Future<void> downloadPdfReport() async {
    try {
      isLoading(true);

      // جلب خط يدعم العربية من خطوط جوجل
      final font = await PdfGoogleFonts.cairoRegular();
      final pdf = pw.Document();

      final monthName = _getMonthName(selectedMonth.value);
      final year = selectedYear.value;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: pw.ThemeData.withFont(base: font, bold: font),
          build: (pw.Context context) {
            return [
              // الهيدر
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal700,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Text(
                  'تقرير شهر $monthName $year',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 16),

              // جدول الأصناف المفلترة
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.teal900),
                rowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: [
                  'الصنف',
                  'المبيعات (كمية)',
                  'إيراد البيع',
                  'المشتريات/المصروف',
                  'التكلفة المدفوعة',
                  'الربح/الخسارة',
                ],
                data: filteredTableData.map((row) {
                  final profit = (row['sales_amount'] as num) - (row['purchase_cost'] as num);
                  return [
                    row['product_name'] ?? '',
                    '${row['sold_quantity']} ${row['unit'] ?? ''}',
                    '${(row['sales_amount'] as num).toStringAsFixed(2)} ج.م',
                    '${row['purchased_quantity']} ${row['unit'] ?? ''}',
                    '${(row['purchase_cost'] as num).toStringAsFixed(2)} ج.م',
                    '${profit.toStringAsFixed(2)} ج.م',
                  ];
                }).toList(),
              ),

              pw.SizedBox(height: 20),
              pw.Divider(),

              // كارت صافي الأرباح والمصروفات
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: netProfit.value >= 0 ? PdfColors.green50 : PdfColors.red50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(
                    color: netProfit.value >= 0 ? PdfColors.green700 : PdfColors.red700,
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          netProfit.value >= 0 ? 'صافي الربح الحقيقي:' : 'صافي الخسارة الحقيقية:',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          '${netProfit.value.abs().toStringAsFixed(2)} ج.م',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: netProfit.value >= 0 ? PdfColors.green800 : PdfColors.red800,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('إجمالي المبيعات: ${totalSales.value.toStringAsFixed(2)} ج.م'),
                        pw.Text('إجمالي المشتريات: ${totalPurchaseCost.value.toStringAsFixed(2)} ج.م'),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('إجمالي المصروفات الأخرى: ${totalExpenses.value.toStringAsFixed(2)} ج.م'),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      final bytes = await pdf.save();

      // تحديد مسار التنزيل المباشر
      Directory output = await getApplicationDocumentsDirectory();
      if (Platform.isAndroid) {
        output = Directory('/storage/emulated/0/Download');
        if (!await output.exists()) {
          output = await getApplicationDocumentsDirectory();
        }
      }

      final fileName = "تقرير_شهر_${monthName}_$year.pdf";
      final filePath = "${output.path}/$fileName";
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      AppSnackbar.success("تم حفظ ملف PDF في مجلد التنزيلات بنجاح");

      // فتح الملف تلقائياً للمستخدم
    } catch (e) {
      AppSnackbar.error("حدث خطأ أثناء حفظ ملف الـ PDF: $e");
    } finally {
      isLoading(false);
    }
  }

  String _getMonthName(int month) {
    const months = [
      "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
      "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"
    ];
    return months[month - 1];
  }

  void clearForm() {
    productNameCtrl.clear();
    quantityCtrl.clear();
    costPerUnitCtrl.clear();
    totalCostCtrl.clear();
    if (categories.isNotEmpty) selectedCategory.value = categories.first;
    if (unitsList.isNotEmpty) selectedUnit.value = unitsList.first;
  }

  @override
  void onClose() {
    productNameCtrl.dispose();
    quantityCtrl.dispose();
    costPerUnitCtrl.dispose();
    totalCostCtrl.dispose();
    super.onClose();
  }
}