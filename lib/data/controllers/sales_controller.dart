import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_config.dart';
import '../constants/constants.dart';
import '../database_helper.dart';
import '../models/cart_item.dart';
import '../repositories/sales_repository.dart';
import '../repositories/purchases_repository.dart';
import '../repositories/reports_repository.dart';
import '../models/product_model.dart';

class SalesController extends GetxController {
  final salesRepo = SalesRepository();
  final dbHelper = DatabaseHelper.instance;
  final _purchasesRepo = PurchasesRepository();
  final _reportsRepo = ReportsRepository();

  var products = <Product>[].obs;
  var availableProducts = <Product>[].obs; // القائمة المفلترة الجاهزة للعرض
  var isLoading = true.obs;
  var isSaving = false.obs;

  // 🆕 لست الفئات والوحدات الديناميكية القادمة من قاعدة البيانات
  var categoriesList = <String>[].obs;
  var unitsList = <String>[].obs;

  var selectedCategory = RxnString();
  var selectedProductId = RxnInt();

  var quantity = 1.0.obs;
  var unitPrice = 0.0.obs;
  var amount = RxnDouble();
  var unitLabel = "وحدة".obs; // 👈 لعرض وحدة المنتج المختار ديناميكياً
  var computedWeight = 0.0.obs;
  var productRemainingMap = <int, double>{}.obs;

  var searchQuery = ''.obs; // نص البحث

  var cartItems = <CartItem>[].obs; // السلة

  final formKey = GlobalKey<FormState>();
  final amountCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');

  @override
  void onInit() {
    super.onInit();
    // ربط البحث والنوع بإعادة الفلترة تلقائياً فور تغيرهم
    ever(searchQuery, (_) => _filterProducts());
    ever(selectedCategory, (_) => _filterProducts());
    loadProducts();
  }

  @override
  void onClose() {
    amountCtrl.dispose();
    qtyCtrl.dispose();
    super.onClose();
  }

  Future<void> loadProducts() async {
    isLoading(true);
    try {
      final db = await dbHelper.database;

      // 📥 1. جلب الفئات والوحدات المسجلة ديناميكياً من الجداول الجديدة
      final catData = await db.query('categories');
      final unitData = await db.query('units');

      categoriesList.assignAll(catData.map((e) => e['name'] as String).toList());
      unitsList.assignAll(unitData.map((e) => e['name'] as String).toList());

      // 📥 2. جلب المنتجات كالمعتاد
      final result = await db.query('products');
      products.assignAll(result.map((e) => Product.fromMap(e)).toList());

      await _loadRemainingBalances();
      _filterProducts(); // تشغيل الفلترة المبدئية
    } catch (e) {
      AppSnackbar.error("خطأ في تحميل المنتجات والبيانات الديناميكية: $e");
    } finally {
      isLoading(false);
    }
  }

  // 🧠 حساب الأرصدة ديناميكياً بدون إجبار السيستم على كلمة "مشروب" ثابتة
  Future<void> _loadRemainingBalances() async {
    try {
      final now = DateTime.now();
      final purchases = await _purchasesRepo.getPurchasesForMonth(now.month, now.year);
      final sales = await _reportsRepo.getMonthlySalesGroupedByProduct(now.month, now.year);

      Map<String, double> purchasedQuantityMap = {};
      for (var p in purchases) {
        String key = p.productName.trim().toLowerCase();
        purchasedQuantityMap[key] = (purchasedQuantityMap[key] ?? 0) + p.quantity;
      }

      for (var product in products) {
        // ⚡ لو المنتج ليس له رصيد مبيعات مسبق أو يعتبر خدمة مفتوحة (مثل الأكواب المفتوحة بالكافيه)
        // بنعطيه رصيد افتراضي كبير، عدا ذلك بنحسب الوارد - الصادر بدقة
        if (product.unit != 'كيلو' && product.category == 'مشروب') {
          productRemainingMap[product.id!] = 999.0;
        } else {
          String productKey = product.name.trim().toLowerCase();
          double purchasedQty = purchasedQuantityMap[productKey] ?? 0.0;

          double totalIncoming = 0.0;
          if (purchasedQty > 0) {
            totalIncoming = purchasedQty;
          } else {
            totalIncoming = product.initialStock ?? 0.0;
          }

          double sold = sales[product.name] ?? 0.0;
          double remaining = totalIncoming - sold;

          productRemainingMap[product.id!] = remaining > 0 ? remaining : 0.0;
        }
      }
    } catch (e) {
      AppSnackbar.error("خطأ في حساب الأرصدة: $e");
    }
  }

  // 🔍 الفلترة الذكية
  void _filterProducts() {
    var filtered = products.where((p) {
      bool matchesCategory = selectedCategory.value == null || p.category == selectedCategory.value;
      bool matchesSearch = searchQuery.value.isEmpty || p.name.toLowerCase().contains(searchQuery.value.toLowerCase());
      double remaining = productRemainingMap[p.id] ?? 0;
      bool hasStock = remaining > 0;

      return matchesCategory && matchesSearch && hasStock;
    }).toList();

    availableProducts.assignAll(filtered);
  }

  void onCategoryChanged(String? val) {
    selectedCategory.value = val;
    resetFields();
  }

  // 🔄 تحديث تفاصيل المنتج والتعرف على وحدته الديناميكية
  void updateProduct(int? id) {
    if (id == null) return;
    selectedProductId.value = id;
    amount.value = null;
    amountCtrl.clear();

    final p = products.firstWhere((p) => p.id == id);
    unitPrice.value = p.price;
    unitLabel.value = p.unit ?? "وحدة"; // 👈 تخزين وحدة الصنف الحالي (علبة، شريط، قطعة...)

    // فحص تشغيل الأوزان الجاهزة بناءً على ميزة الأوزان في الإعدادات ونوع الصنف
    final useWeights = AppConfig.enableWeightSystem && (p.unit == 'كيلو' || p.category == 'بن');

    if (useWeights) {
      quantity.value = 0.125;
      qtyCtrl.text = "0.125";
    } else {
      quantity.value = 1.0;
      qtyCtrl.text = "1";
    }
  }

  void updateAmountAndWeight(String value) {
    final useWeights = AppConfig.enableWeightSystem && (selectedCategory.value == 'بن' || unitLabel.value == 'كيلو');

    if (value.isEmpty) {
      amount.value = null;
      computedWeight.value = 0.0;
      quantity.value = useWeights ? 0.125 : 1.0;
      qtyCtrl.text = quantity.value.toString();
      return;
    }
    final amountValue = double.tryParse(value);
    if (amountValue != null && amountValue > 0 && unitPrice.value > 0) {
      amount.value = amountValue;
      computedWeight.value = amountValue / unitPrice.value;
      quantity.value = computedWeight.value;
      qtyCtrl.text = quantity.value.toStringAsFixed(3);
    } else {
      amount.value = null;
      computedWeight.value = 0.0;
    }
  }

  double get currentTotal {
    if (amount.value != null && amount.value! > 0) return amount.value!;
    if (selectedProductId.value == null) return 0.0;
    return quantity.value * unitPrice.value;
  }

  void addToCart() {
    if (selectedProductId.value == null) {
      AppSnackbar.warning("اختر منتجاً أولاً");
      return;
    }
    final product = products.firstWhere((p) => p.id == selectedProductId.value);
    final remaining = productRemainingMap[selectedProductId.value] ?? 0;
    if (quantity.value > remaining) {
      AppSnackbar.warning("الكمية المطلوبة أكبر من المتاح");
      return;
    }
    cartItems.add(CartItem(
      productId: product.id!,
      productName: product.name,
      quantity: quantity.value,
      unitPrice: unitPrice.value,
      total: currentTotal,
      category: product.category,
    ));
    resetFields();
    AppSnackbar.success("تمت الإضافة إلى السلة");
  }

  void removeCartItem(int index) => cartItems.removeAt(index);
  double get orderTotal => cartItems.fold(0, (sum, item) => sum + item.total);

  Future<bool> saveSingleProduct(int userId) async {
    if (selectedProductId.value == null) {
      AppSnackbar.warning("اختر منتجاً أولاً");
      return false;
    }
    double remaining = productRemainingMap[selectedProductId.value] ?? 0;
    double finalQuantity = (amount.value != null) ? (amount.value! / unitPrice.value) : quantity.value;
    if (finalQuantity > remaining) {
      AppSnackbar.warning("الكمية أكبر من المتاح");
      return false;
    }
    isSaving(true);
    try {
      int? shiftId = await dbHelper.getOpenShiftId();
      if (shiftId == null) {
        AppSnackbar.error("لا يوجد شيفت مفتوح");
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
      await loadProducts();
      DatabaseHelper.notifySalesChanged();
      resetFields();
      AppSnackbar.success("تم حفظ الفاتورة");
      return true;
    } catch (e) {
      AppSnackbar.error("خطأ أثناء الحفظ: $e");
      return false;
    } finally {
      isSaving(false);
    }
  }

  Future<bool> saveCart(int userId) async {
    if (cartItems.isEmpty) {
      AppSnackbar.warning("السلة فارغة");
      return false;
    }
    isSaving(true);
    try {
      int? shiftId = await dbHelper.getOpenShiftId();
      if (shiftId == null) {
        AppSnackbar.error("لا يوجد شيفت مفتوح");
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
      await loadProducts();
      DatabaseHelper.notifySalesChanged();
      AppSnackbar.success("تم حفظ الأوردر بالكامل");
      return true;
    } catch (e) {
      AppSnackbar.error("خطأ أثناء الحفظ: $e");
      return false;
    } finally {
      isSaving(false);
    }
  }

  Future<bool> saveSmart(int userId) async {
    if (cartItems.isNotEmpty) {
      return await saveCart(userId);
    } else {
      return await saveSingleProduct(userId);
    }
  }

  void resetFields() {
    selectedProductId.value = null;
    amount.value = null;
    computedWeight.value = 0.0;
    amountCtrl.clear();
    searchQuery.value = '';

    final useWeights = AppConfig.enableWeightSystem && (selectedCategory.value == 'بن' || unitLabel.value == 'كيلو');
    if (useWeights) {
      quantity.value = 0.125;
      qtyCtrl.text = "0.125";
    } else {
      quantity.value = 1.0;
      qtyCtrl.text = "1";
    }
  }
}