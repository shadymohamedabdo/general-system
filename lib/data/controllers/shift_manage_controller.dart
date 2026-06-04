import 'package:get/get.dart';
import '../models/shift_model.dart';
import '../repositories/shifts_repository.dart';
import '../constants/constants.dart';

class ShiftsController extends GetxController {
  final repo = ShiftsRepository();

  var openShift = Rxn<ShiftModel>();
  var allShifts = <ShiftModel>[].obs;

  var isLoading = false.obs;
  var isLoadingMore = false.obs;
  var isProcessing = false.obs;
  var hasMoreData = true.obs;

  int _currentOffset = 0;
  final int _limit = 20;

  @override
  void onInit() {
    super.onInit();
    loadInitialData(showLoader: true);
  }

  // ===================== التحميل الأولي أو التحديث الكامل =====================
  Future<void> loadInitialData({bool showLoader = false}) async {
    try {
      if (showLoader) isLoading.value = true;

      _currentOffset = 0;
      hasMoreData.value = true;

      final currentMap = await repo.getOpenShift();
      final historyMaps = await repo.getAllShifts(limit: _limit, offset: _currentOffset);

      openShift.value = currentMap != null ? ShiftModel.fromMap(currentMap) : null;

      final converted = historyMaps.map((m) => ShiftModel.fromMap(m)).toList();
      allShifts.assignAll(converted);

      if (historyMaps.length < _limit) hasMoreData.value = false;
    } catch (e) {
      AppSnackbar.error("فشل تحميل البيانات");
    } finally {
      isLoading.value = false;
    }
  }

  // ===================== تحميل المزيد من الشيفتات (Pagination) =====================
  Future<void> loadMoreShifts() async {
    // is loading run or no more data = stop
    if (isLoadingMore.value || !hasMoreData.value) return;
    isLoadingMore.value = true;
    try {
      // _limit = count of items to load
      // _currentOffset = offset of current page
      _currentOffset += _limit;

      final moreMaps = await repo.getAllShifts(limit: _limit, offset: _currentOffset);
      if (moreMaps.isEmpty) {
        hasMoreData.value = false;
      } else {
        // convert maps to models
        final converted = moreMaps.map((m) => ShiftModel.fromMap(m)).toList();
        allShifts.addAll(converted);
        if (moreMaps.length < _limit) hasMoreData.value = false;
      }
    } catch (e) {
      AppSnackbar.error("فشل تحميل المزيد");
    } finally {
      isLoadingMore.value = false;
    }
  }

  // ===================== فتح شيفت جديد =====================
  Future<void> startShift(String type, String userName) async {
    if (isProcessing.value) return;
    isProcessing.value = true;
    try {
      await repo.openShift(type, userName);
      await loadInitialData(showLoader: false);
      AppSnackbar.success("تم فتح الشيفت بنجاح");
    } catch (e) {
      AppSnackbar.error("فشل فتح الشيفت");
    } finally {
      isProcessing.value = false;
    }
  }

  // ===================== إغلاق الشيفت الحالي =====================
  Future<void> endShift(int id) async {
    if (isProcessing.value) return;
    isProcessing.value = true;
    try {
      await repo.closeShift(id);
      await loadInitialData(showLoader: false);
      AppSnackbar.warning("تم إغلاق الشيفت");
    } catch (e) {
      AppSnackbar.error("فشل إغلاق الشيفت");
    } finally {
      isProcessing.value = false;
    }
  }
}