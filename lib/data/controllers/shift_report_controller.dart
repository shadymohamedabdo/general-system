import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../constants/constants.dart';
import '../repositories/reports_repository.dart';
import '../repositories/expenses_repository.dart';
import '../database_helper.dart';

class ShiftReportController extends GetxController {
  final _repo = ReportsRepository();
  final _expenseRepo = ExpensesRepository();
  final dbHelper = DatabaseHelper.instance;

  var reportData = <Map<String, dynamic>>[].obs;
  var shifts = <Map<String, dynamic>>[].obs;
  var shiftExpenses = <Map<String, dynamic>>[].obs;

  var isLoading = true.obs;
  var isLoadingMore = false.obs;
  var selectedShiftId = RxnInt();

  // الإحصائيات الشاملة للوردية بالكامل 📊
  var totalSum = 0.0.obs;
  var totalExpensesSum = 0.0.obs;
  var finalNetCash = 0.0.obs;
  var ordersCount = 0.obs;
  var cancelledSum = 0.0.obs;

  var currentPage = 1.obs;
  var hasMoreData = true.obs;
  final int pageSize = 20;

  // 📄 متغيرات الباجنيشن الخاصة بشريط الورديات العلوى
  var isShiftsLoadingMore = false.obs;
  bool hasMoreShifts = true;
  int _shiftsOffset = 0;
  final int _shiftsLimit = 20;

  // 🎮 المتحكمات بالانتقال (السكرول)
  final ScrollController scrollController = ScrollController();
  final ScrollController shiftsScrollController = ScrollController();

  @override
  void onInit() {
    super.onInit();

    // 1. مراقبة سكرول المبيعات والعمليات الأسفل (القديم)
    scrollController.addListener(() {
      if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
        loadMoreTransactions();
      }
    });

    // 2. مراقبة سكرول شريط الورديات العلوى للباجنيشن اللانهائي
    shiftsScrollController.addListener(() {
      if (shiftsScrollController.position.pixels >= shiftsScrollController.position.maxScrollExtent - 100) {
        loadMoreShifts();
      }
    });

    loadInitialShifts();
  }

  @override
  void onClose() {
    scrollController.dispose();
    shiftsScrollController.dispose();
    super.onClose();
  }

  /// 🛠️ دالة جلب أول دفعة من الشفتات عند فتح الشاشة
  Future<void> loadInitialShifts() async {
    try {
      isLoading(true);
      _shiftsOffset = 0;
      hasMoreShifts = true;
      shifts.clear();

      await _fetchShiftsPage();

      if (shifts.isNotEmpty) {
        selectedShiftId.value = shifts.first['id'] as int?;
        await loadReport(reset: true);
      }
    } catch (e) {
      AppSnackbar.error("فشل تحميل الورديات");
    } finally {
      isLoading(false);
    }
  }

  /// 🛠️ دالة جلب المزيد من الشفتات القديمة عند سحب الشريط العلوى
  Future<void> loadMoreShifts() async {
    if (isShiftsLoadingMore.value || !hasMoreShifts) return;

    try {
      isShiftsLoadingMore(true);
      _shiftsOffset += _shiftsLimit;
      await _fetchShiftsPage();
    } catch (e) {
      // فشل صامت لعدم إزعاج المستخدم أثناء الحركة
    } finally {
      isShiftsLoadingMore(false);
    }
  }

  /// الاستعلام المباشر من الداتابيز
  Future<void> _fetchShiftsPage() async {
    final db = await dbHelper.database;
    final data = await db.query(
      'shifts',
      orderBy: 'id DESC',
      limit: _shiftsLimit,
      offset: _shiftsOffset,
    );

    if (data.length < _shiftsLimit) {
      hasMoreShifts = false;
    }

    shifts.addAll(data);
  }

  Future<void> loadAllShifts() async {
    await loadInitialShifts();
  }

  Future<void> loadReport({bool reset = true}) async {
    if (selectedShiftId.value == null) return;

    try {
      if (reset) {
        isLoading(true);
        currentPage.value = 1;
        hasMoreData.value = true;
        reportData.clear();
        shiftExpenses.clear();

        await _fetchTotalShiftStatistics();
      } else {
        isLoadingMore(true);
      }

      final data = await _repo.getShiftReportPaginated(
        selectedShiftId.value!,
        limit: pageSize,
        offset: (currentPage.value - 1) * pageSize,
      );

      if (reset) {
        final exps = await _expenseRepo.getExpensesRawForShift(selectedShiftId.value!);
        shiftExpenses.assignAll(exps);
      }

      if (data.isEmpty) {
        hasMoreData.value = false;
      } else {
        if (reset) {
          reportData.assignAll(data);
        } else {
          reportData.addAll(data);
        }
        if (data.length < pageSize) hasMoreData.value = false;
      }
    } catch (e) {
      AppSnackbar.error("فشل تحميل التقرير");
    } finally {
      if (reset) {
        isLoading(false);
      } else {
        isLoadingMore(false);
      }
    }
  }

  Future<void> loadMoreTransactions() async {
    if (!hasMoreData.value || isLoadingMore.value) return;
    currentPage.value++;
    await loadReport(reset: false);
  }

  void selectShift(int shiftId) {
    selectedShiftId.value = shiftId;
    loadReport(reset: true);
  }

  Future<void> _fetchTotalShiftStatistics() async {
    final shiftId = selectedShiftId.value!;
    double expsTotal = await _expenseRepo.getTotalExpensesForShift(shiftId);
    totalExpensesSum.value = expsTotal;

    final stats = await _repo.getShiftTotalStats(shiftId);
    totalSum.value = (stats['active_sum'] as num?)?.toDouble() ?? 0.0;
    ordersCount.value = (stats['active_count'] as num?)?.toInt() ?? 0;
    cancelledSum.value = (stats['cancelled_sum'] as num?)?.toDouble() ?? 0.0;

    finalNetCash.value = totalSum.value - totalExpensesSum.value;
  }

  Future<void> toggleStatus(int id, String currentStatus) async {
    try {
      String nextStatus = (currentStatus == 'active') ? 'cancelled' : 'active';
      await _repo.updateSaleStatus(id, nextStatus);
      await loadReport(reset: true);
      AppSnackbar.success("تم تحديث حالة العملية بنجاح");
    } catch (e) {
      AppSnackbar.error("فشل تحديث الحالة");
    }
  }

  // 🖨️ دالة طباعة تقرير إغلاق الوردية الحراري (80mm)
  Future<void> printShiftThermalReport(String currentUserName) async {
    if (selectedShiftId.value == null) {
      AppSnackbar.warning("يرجى اختيار وردية أولاً");
      return;
    }

    try {
      final shiftId = selectedShiftId.value!;
      final db = await dbHelper.database;

      // 1. جلب نوع الشيفت (صباحي / مسائي)
      final shiftData = await db.query('shifts', where: 'id = ?', whereArgs: [shiftId]);
      String shiftTypeStr = "صباحي";
      if (shiftData.isNotEmpty) {
        shiftTypeStr = shiftData.first['type'] == 'morning' ? "صباحي ☀️" : "مسائي 🌙";
      }

      // 2. جلب مبيعات الأصناف التجميعية للشيفت
      final productsSummary = await db.rawQuery('''
        SELECT 
          p.name AS product_name,
          SUM(s.quantity) AS total_quantity,
          SUM(s.quantity * s.unit_price) AS total_sales
        FROM sales s
        JOIN products p ON s.product_id = p.id
        WHERE s.shift_id = ? AND s.status = 'active'
        GROUP BY s.product_id, p.name
        ORDER BY total_quantity DESC
      ''', [shiftId]);

      // 3. تجهيز الخط ومقاس الورق 80 مم
      final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
      final arabicFont = pw.Font.ttf(fontData);

      final now = DateTime.now().toLocal();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final timeStr = DateFormat('HH:mm').format(now);

      const customRoll80 = PdfPageFormat(
        72 * PdfPageFormat.mm,
        double.infinity,
        marginTop: 0,
        marginBottom: 0,
        marginLeft: 0,
        marginRight: 0,
      );

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: customRoll80,
          build: (context) => pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 6 * PdfPageFormat.mm,
                vertical: 4 * PdfPageFormat.mm,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Center(
                    child: pw.Text(
                      'كافيه كراميل',
                      style: pw.TextStyle(font: arabicFont, fontSize: 15, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Center(
                    child: pw.Text(
                      'تقرير إغلاق الوردية ($shiftTypeStr)',
                      style: pw.TextStyle(font: arabicFont, fontSize: 13, fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text('التاريخ: $dateStr  |  الوقت: $timeStr', style: pw.TextStyle(font: arabicFont, fontSize: 9)),
                  pw.Text('المسؤول: $currentUserName', style: pw.TextStyle(font: arabicFont, fontSize: 9)),
                  pw.Divider(thickness: 1),

                  // 💵 الملخص المالي
                  pw.Text('الملخص المالي:', style: pw.TextStyle(font: arabicFont, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(height: 4),
                  _buildPdfRow('إجمالي المبيعات:', '${totalSum.value.toStringAsFixed(2)} ج.م', arabicFont),
                  _buildPdfRow('المصروفات النقدية:', '${totalExpensesSum.value.toStringAsFixed(2)} ج.م', arabicFont),
                  _buildPdfRow('الصافي بالصندوق:', '${finalNetCash.value.toStringAsFixed(2)} ج.م', arabicFont, isBold: true),
                  _buildPdfRow('عدد الطلبات:', '${ordersCount.value} طلب', arabicFont),

                  pw.Divider(thickness: 1),

                  // 📦 تفاصيل مبيعات الأصناف التجميعية
                  pw.Text('تفاصيل مبيعات الأصناف:', style: pw.TextStyle(font: arabicFont, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(height: 6),

                  if (productsSummary.isEmpty)
                    pw.Text('لا توجد مبيعات في هذا الشيفت', style: pw.TextStyle(font: arabicFont, fontSize: 9))
                  else
                    ...productsSummary.map((item) {
                      final name = (item['product_name'] ?? '').toString().replaceAll('بن', '').trim();
                      final qty = (item['total_quantity'] as num).toDouble();
                      final qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
                      final amount = (item['total_sales'] as num).toDouble().toStringAsFixed(0);

                      return pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 2),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('$qtyStr $name', style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                            pw.Text('$amount ج', style: pw.TextStyle(font: arabicFont, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      );
                    }),

                  pw.Divider(thickness: 1),
                  pw.SizedBox(height: 6),
                  pw.Center(
                    child: pw.Text('نهاية تقرير الوردية', style: pw.TextStyle(font: arabicFont, fontSize: 9)),
                  ),
                  pw.SizedBox(height: 25 * PdfPageFormat.mm),
                ],
              ),
            ),
          ),
        ),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'shift_z_report_$shiftId',
        format: customRoll80,
      );

      AppSnackbar.success("تم إرسال تقرير الوردية للطابعة بنجاح");
    } catch (e) {
      AppSnackbar.error("حدث خطأ أثناء طباعة تقرير الوردية: $e");
    }
  }

  pw.Widget _buildPdfRow(String title, String value, pw.Font font, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(title, style: pw.TextStyle(font: font, fontSize: 10)),
          pw.Text(
            value,
            style: pw.TextStyle(font: font, fontSize: 10, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ],
      ),
    );
  }
}