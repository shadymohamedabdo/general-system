import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/constants.dart';
import '../database_helper.dart';
import '../repositories/sales_repository.dart';
import '../repositories/purchases_repository.dart';
import '../repositories/reports_repository.dart';
import '../models/product_model.dart';
import '../models/cart_item.dart';

class SalesController extends GetxController {
  // 🔹 Repositories & Helpers
  final salesRepo = SalesRepository();
  final dbHelper = DatabaseHelper.instance;
  final _purchasesRepo = PurchasesRepository();
  final _reportsRepo = ReportsRepository();

  // 🔹 Text Controllers
  final amountCtrl = TextEditingController();
  final qtyCtrl = TextEditingController();

  // 🔹 المنتجات والسلة
  var products = <Product>[].obs;
  var availableProducts = <Product>[].obs;
  var cartItems = <CartItem>[].obs;

  // 🔹 البحث والتصفية
  var searchQuery = ''.obs;

  // 🔹 حالات
  var isLoading = true.obs;
  var isSaving = false.obs;

  // 🔹 الاختيارات
  var selectedCategory = RxnString();
  var selectedProductId = RxnInt();

  // 🔹 القيم
  var quantity = 1.0.obs;
  var unitPrice = 0.0.obs;
  var amount = RxnDouble();
  var unitLabel = "وحدة".obs;
  var computedWeight = 0.0.obs;

  // 🔹 الرصيد لكل منتج (null تعني رصيد مفتوح)
  var productRemainingMap = <int, double?>{}.obs;
  final formKey = GlobalKey<FormState>();

  var categories = <String>[].obs;

  // 🔹 الترابيزات المشغولة والطلبات النشطة
  var busyTableNumbers = <int>{}.obs;
  var currentTableNumber = RxnInt();
  var currentTableOrders = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadProducts();
    loadBusyTables();

    // فلترة المنتجات فوراً عند البحث
    debounce(searchQuery, (_) => _filterAvailableProducts(), time: const Duration(milliseconds: 300));
  }

  @override
  void onClose() {
    amountCtrl.dispose();
    qtyCtrl.dispose();
    super.onClose();
  }

  // ================= جلب الترابيزات المشغولة =================
  Future<void> loadBusyTables() async {
    try {
      final db = await dbHelper.database;
      final result = await db.rawQuery('SELECT DISTINCT table_number FROM table_orders');
      final busyList = result.map((row) => row['table_number'] as int).toSet();
      busyTableNumbers.assignAll(busyList);
    } catch (e) {
      debugPrint("خطأ في جلب الترابيزات المشغولة: $e");
    }
  }

  // ================= حذف عنصر محفوظ على الترابيزة =================
  Future<void> removeSavedTableOrderItem(int orderId, int tableNum) async {
    try {
      final db = await dbHelper.database;
      await db.delete('table_orders', where: 'id = ?', whereArgs: [orderId]);
      await loadTableOrders(tableNum);
      await loadBusyTables();
      AppSnackbar.success("تم حذف الصنف من الترابيزة بنجاح");
    } catch (e) {
      AppSnackbar.error("خطأ أثناء حذف الصنف: $e");
    }
  }

  // ================= تحميل المنتجات =================
  Future<void> loadProducts() async {
    isLoading(true);
    try {
      final db = await dbHelper.database;
      final result = await db.query('products');

      products.assignAll(
        result.map((e) => Product.fromMap(e)).toList(),
      );

      final uniqueCategories = products
          .map((p) => p.category.trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList();

      categories.assignAll(uniqueCategories);

      await _loadRemainingBalances();
      _filterAvailableProducts();
    } catch (e) {
      AppSnackbar.error("خطأ في تحميل المنتجات: $e");
    } finally {
      isLoading(false);
    }
  }

  // ================= حساب الأرصدة المتاحة الحقيقية =================
  Future<void> _loadRemainingBalances() async {
    try {
      final db = await dbHelper.database;

      final purchasesResult = await db.rawQuery('''
        SELECT product_name, SUM(quantity) as total_purchased 
        FROM purchases 
        GROUP BY product_name
      ''');

      final salesResult = await db.rawQuery('''
        SELECT product_id, SUM(quantity) as total_sold 
        FROM sales 
        GROUP BY product_id
      ''');

      Map<String, double> purchasedQuantityMap = {};
      for (var row in purchasesResult) {
        final name = (row['product_name'] as String?)?.trim().toLowerCase();
        final qty = (row['total_purchased'] as num?)?.toDouble() ?? 0.0;
        if (name != null) purchasedQuantityMap[name] = qty;
      }

      Map<int, double> soldQuantityMap = {};
      for (var row in salesResult) {
        final productId = row['product_id'] as int?;
        final qty = (row['total_sold'] as num?)?.toDouble() ?? 0.0;
        if (productId != null) soldQuantityMap[productId] = qty;
      }

      for (var product in products) {
        final cleanProductName = product.name.trim().toLowerCase();
        bool hasPurchases = purchasedQuantityMap.containsKey(cleanProductName);
        double totalPurchased = purchasedQuantityMap[cleanProductName] ?? 0.0;
        double totalSold = soldQuantityMap[product.id] ?? 0.0;

        if (product.initialStock == 0 && !hasPurchases) {
          productRemainingMap[product.id!] = null;
        } else {
          double totalStockIn = product.initialStock + totalPurchased;
          double remaining = totalStockIn - totalSold;
          productRemainingMap[product.id!] = remaining;
        }
      }
    } catch (e) {
      AppSnackbar.error("خطأ في حساب الأرصدة: $e");
    }
  }

  // ================= فلترة المنتجات للمبيعات =================
  void _filterAvailableProducts() {
    availableProducts.assignAll(
      products.where((p) {
        final pCategory = p.category.trim().toLowerCase();
        final selCategory = selectedCategory.value?.trim().toLowerCase();

        bool matchesCategory = false;
        if (selCategory == null || selCategory.isEmpty) {
          matchesCategory = true;
        } else if (selCategory.contains('بن') && pCategory.contains('بن')) {
          matchesCategory = true;
        } else if (selCategory.contains('مشروب') && pCategory.contains('مشروب')) {
          matchesCategory = true;
        } else if ((selCategory.contains('عصير') || selCategory.contains('عصائر')) &&
            (pCategory.contains('عصير') || pCategory.contains('عصائر'))) {
          matchesCategory = true;
        } else {
          matchesCategory = pCategory == selCategory;
        }

        final matchesSearch = searchQuery.value.isEmpty ||
            p.name.toLowerCase().contains(searchQuery.value.toLowerCase());

        return matchesCategory && matchesSearch;
      }).toList(),
    );
  }

  // ================= إدارات الترابيزات والتيك أواي =================
  Future<bool> saveCartOrAddToTable(int userId) async {
    if (cartItems.isEmpty) return false;

    if (currentTableNumber.value != null) {
      try {
        for (var item in cartItems) {
          await dbHelper.addOrUpdateTableOrderItem(
            tableNumber: currentTableNumber.value!,
            productId: item.productId,
            productName: item.productName,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
          );
        }
        await loadTableOrders(currentTableNumber.value!);
        await loadBusyTables();

        cartItems.clear();
        resetFields();
        AppSnackbar.success("تمت إضافة الطلبات للترابيزة ${currentTableNumber.value}");
        return true;
      } catch (e) {
        AppSnackbar.error("خطأ أثناء إضافة الطلبات للترابيزة: $e");
        return false;
      }
    }

    return await saveCart(userId);
  }

  void selectTable(int? tableNum) async {
    currentTableNumber.value = tableNum;
    if (tableNum != null) {
      await loadTableOrders(tableNum);
    } else {
      currentTableOrders.clear();
    }
  }

  Future<void> loadTableOrders(int tableNum) async {
    final orders = await dbHelper.getTableOrders(tableNum);
    currentTableOrders.assignAll(orders);
  }

  Future<bool> checkoutAndGetTableOrders(int tableNum, int userId) async {
    final orders = await dbHelper.getTableOrders(tableNum);
    if (orders.isEmpty && cartItems.isEmpty) return false;

    int? shiftId = await dbHelper.getOpenShiftId();
    if (shiftId == null) {
      AppSnackbar.error("لا يوجد شيفت مفتوح لإغلاق الفاتورة");
      return false;
    }

    for (var order in orders) {
      await salesRepo.addSale(
        shiftId: shiftId,
        userId: userId,
        productId: order['product_id'] as int,
        quantity: (order['quantity'] as num).toDouble(),
        unitPrice: (order['unit_price'] as num).toDouble(),
        totalAmount: (order['total_price'] as num).toDouble(),
      );
    }

    await dbHelper.clearTableSession(tableNum);
    currentTableOrders.clear();
    currentTableNumber.value = null;
    cartItems.clear();

    await loadBusyTables();
    await loadProducts();
    DatabaseHelper.notifySalesChanged();

    return true;
  }

  Future<void> checkoutTable(int tableNum) async {
    await dbHelper.clearTableSession(tableNum);
    currentTableOrders.clear();
    currentTableNumber.value = null;
    await loadBusyTables();
    AppSnackbar.success("تم تقفيل حساب الترابيزة $tableNum بنجاح");
  }

  // ================= تغيير الكاتيجوري والمنتج =================
  void onCategoryChanged(String? val) {
    selectedCategory.value = val;
    selectedProductId.value = null;
    amount.value = null;
    unitPrice.value = 0.0;
    computedWeight.value = 0.0;
    amountCtrl.clear();
    qtyCtrl.clear();

    if (val == 'بن') {
      unitLabel.value = "كيلو";
      quantity.value = 0.125;
    } else {
      unitLabel.value = val == 'مشروب' ? "كوب" : "قطعة";
      quantity.value = 1.0;
    }
    _filterAvailableProducts();
  }

  Future<void> updateProduct(int? id) async {
    selectedProductId.value = id;
    amount.value = null;
    amountCtrl.clear();

    if (id != null) {
      final p = products.firstWhere((p) => p.id == id);
      unitPrice.value = p.price;

      double? remaining = productRemainingMap[id];
      if (remaining != null && remaining <= 0) {
        AppSnackbar.warning("تنبيه: هذا المنتج نفد من المخزن (الرصيد الحالي: ${remaining.toStringAsFixed(0)})");
      }
    }
  }

  void updateAmountAndWeight(String value) {
    final amountValue = double.tryParse(value);
    if (amountValue != null && amountValue > 0 && unitPrice.value > 0) {
      amount.value = amountValue;
      computedWeight.value = amountValue / unitPrice.value;
      quantity.value = computedWeight.value;
    } else {
      amount.value = null;
      computedWeight.value = 0.0;
    }
  }

  double get currentTotal => amount.value ?? (quantity.value * unitPrice.value);
  double get orderTotal => cartItems.fold(0.0, (sum, item) => sum + item.total);

  // ================= السلة (Cart) =================
  void addToCart() {
    if (selectedProductId.value == null) {
      AppSnackbar.warning("برجاء اختيار المنتج أولاً");
      return;
    }

    final product = products.firstWhere((p) => p.id == selectedProductId.value);
    double? remaining = productRemainingMap[product.id];
    double finalQuantity = (amount.value != null) ? (amount.value! / unitPrice.value) : quantity.value;

    if (remaining != null && finalQuantity > remaining) {
      AppSnackbar.warning("الكمية المطلوبة أكبر من المتاح بالمخزن (المتاح: ${remaining.toStringAsFixed(2)})");
      return;
    }

    cartItems.add(CartItem(
      productId: product.id!,
      productName: product.name,
      quantity: finalQuantity,
      unitPrice: unitPrice.value,
      total: currentTotal,
      category: product.category,
    ));

    resetFields();
    AppSnackbar.success("تمت إضافة الصنف للسلة");
  }

  void removeCartItem(int index) {
    cartItems.removeAt(index);
  }

  // ================= حفظ المنتج الفردي =================
  Future<bool> saveSingleProduct(int userId) async {
    if (!formKey.currentState!.validate()) return false;
    if (selectedProductId.value == null) {
      AppSnackbar.warning("اختار المنتج");
      return false;
    }

    double? remaining = productRemainingMap[selectedProductId.value];
    double finalQuantity = (amount.value != null) ? (amount.value! / unitPrice.value) : quantity.value;

    if (remaining != null && finalQuantity > remaining) {
      AppSnackbar.warning("الكمية أكبر من المتاح بالمخزن");
      return false;
    }

    isSaving(true);
    try {
      int? shiftId = await dbHelper.getOpenShiftId();
      if (shiftId == null) {
        AppSnackbar.error("مفيش شيفت مفتوح");
        return false;
      }

      await salesRepo.addSale(
        shiftId: shiftId,
        userId: userId,
        productId: selectedProductId.value!,
        quantity: finalQuantity,
        unitPrice: unitPrice.value,
        totalAmount: currentTotal,
      );

      AppSnackbar.success("تم الحفظ بنجاح");
      resetFields();
      await loadProducts();
      DatabaseHelper.notifySalesChanged();
      return true;
    } catch (e) {
      AppSnackbar.error("حدث خطأ أثناء الحفظ: $e");
      return false;
    } finally {
      isSaving(false);
    }
  }

  // ================= حفظ الفاتورة بالكامل =================
  Future<bool> saveCart(int userId) async {
    if (cartItems.isEmpty) return false;

    isSaving(true);
    try {
      int? shiftId = await dbHelper.getOpenShiftId();
      if (shiftId == null) {
        AppSnackbar.error("مفيش شيفت مفتوح");
        return false;
      }

      for (var item in cartItems) {
        await salesRepo.addSale(
          shiftId: shiftId,
          userId: userId,
          productId: item.productId,
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          totalAmount: item.total,
        );
      }

      cartItems.clear();
      AppSnackbar.success("تم حفظ الفاتورة بنجاح");
      resetFields();
      await loadProducts();
      DatabaseHelper.notifySalesChanged();
      return true;
    } catch (e) {
      AppSnackbar.error("خطأ في حفظ السلة: $e");
      return false;
    } finally {
      isSaving(false);
    }
  }

  void resetFields() {
    selectedProductId.value = null;
    amount.value = null;
    computedWeight.value = 0.0;
    amountCtrl.clear();
    qtyCtrl.clear();
    quantity.value = (selectedCategory.value == 'بن') ? 0.125 : 1.0;
  }
}