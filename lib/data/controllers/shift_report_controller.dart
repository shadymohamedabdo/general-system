import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
}