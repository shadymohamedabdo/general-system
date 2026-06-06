import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/constants.dart';
import '../database_helper.dart';
import '../models/product_model.dart';
import '../repositories/purchases_repository.dart';
import '../repositories/reports_repository.dart';

class ProductsController extends GetxController {
  final dbHelper = DatabaseHelper.instance;
  final _purchasesRepo = PurchasesRepository();
  final _reportsRepo = ReportsRepository();

  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final searchCtrl = TextEditingController();
  final stockCtrl = TextEditingController(text: '0');

  // 🆕 قوائم ديناميكية لجلب الفئات والوحدات من الداتابيز
  var categoriesList = <String>[].obs;
  var unitsList = <String>[].obs;

  // 📌 الحالة الحالية المحدثة ديناميكياً
  var selectedCategory = RxnString();
  var selectedTabCategory = 'الكل'.obs;
  var selectedUnit = RxnString();

  var allProducts = <Product>[].obs;
  var filteredProducts = <Product>[].obs;

  var availableProductNames = <String>[].obs;
  var selectedProductName = ''.obs;

  var productStock = <int, double>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadProducts();
  }

  // 🔄 تحميل المنتجات والفئات والوحدات معاً
  Future<void> loadProducts() async {
    final db = await dbHelper.database;

    // 📥 1. جلب الفئات والوحدات الديناميكية من الجداول الجديدة
    final catData = await db.query('categories');
    final unitData = await db.query('units');

    categoriesList.assignAll(catData.map((e) => e['name'] as String).toList());
    unitsList.assignAll(unitData.map((e) => e['name'] as String).toList());

    // تعيين قيم مبدئية ذكية في حقول الإضافة إذا كانت فارغة
    if (selectedCategory.value == null && categoriesList.isNotEmpty) {
      selectedCategory.value = categoriesList.first;
    }
    if (selectedUnit.value == null && unitsList.isNotEmpty) {
      selectedUnit.value = unitsList.first;
    }

    // 📥 2. قراءة المنتجات من الجدول وتحويلها لـ model
    final maps = await db.query('products');
    allProducts.assignAll(maps.map((e) => Product.fromMap(e)).toList());

    await loadAvailableProductNames();
    await loadProductBalances();
    applyFilters(searchCtrl.text);
  }

  // 📊 حساب الرصيد الذكي بالاعتماد على الفئات والوحدات المرنة
// 📊 حساب الرصيد الذكي بالاعتماد على حركة المشتريات والمبيعات
  Future<void> loadProductBalances() async {
    try {
      final now = DateTime.now();
      final purchases = await _purchasesRepo.getPurchasesForMonth(now.month, now.year);
      final sales = await _reportsRepo.getMonthlySalesGroupedByProduct(now.month, now.year);

      Map<String, double> purchasedQuantity = {};
      for (var p in purchases) {
        purchasedQuantity[p.productName.trim().toLowerCase()] =
            (purchasedQuantity[p.productName.trim().toLowerCase()] ?? 0) + p.quantity;
      }

      final Map<int, double> newStock = {};

      for (var product in allProducts) {
        if (product.id == null) continue;

        String pNameNormalized = product.name.trim().toLowerCase();

        double purchased = purchasedQuantity[pNameNormalized] ?? 0.0;
        double manualStock = product.initialStock ?? 0.0;

        // إجمالي الكمية الواردة (سواء من المشتريات أو الإدخال اليدوي)
        double totalIncoming = purchased > 0 ? purchased : manualStock;

        // 🎯 التعديل السحري هنا:
        // لو مفيش مشتريات نزلت للمنتج ده، وكمان أنت مش مدخل له كمية بايدك (يعنيtotalIncoming = 0)
        // وكمان مش تبع قسم "بن" (لأن البن لازم يتحسب دايماً بوزنه)، يبقى ده رصيد مفتوح!
        if (totalIncoming == 0.0 && product.category != 'بن') {
          newStock[product.id!] = 999.0; // كود رمزي للرصيد المفتوح
        } else {
          // حساب الحسبة العادية للمنتجات المحددة بالكمية
          double sold = sales[product.name] ?? 0;
          double remaining = totalIncoming - sold;

          newStock[product.id!] = remaining > 0 ? remaining : 0.0;
        }
      }
      productStock.value = newStock;
    } catch (e) {
      AppSnackbar.error("خطأ في حساب الأرصدة: $e");
    }
  }
  Future<void> loadAvailableProductNames() async {
    try {
      final purchases = await _purchasesRepo.getAllPurchases();
      final allPurchaseNames = purchases.map((p) => p.productName).toSet();
      final existingProductNames = allProducts.map((p) => p.name).toSet();
      final available = allPurchaseNames.difference(existingProductNames).toList();

      availableProductNames.assignAll(available);

      if (selectedProductName.value.isEmpty && availableProductNames.isNotEmpty) {
        selectedProductName.value = availableProductNames.first;
      }
    } catch (e) {}
  }

  // 🔄 تغيير التصنيف يدوياً وتحديث الوحدة التلقائية الذكية إذا لزم الأمر
  void changeCategory(String category) {
    selectedCategory.value = category;
    // تخصيص ذكي مرن للوحدة إذا كانت تابعة لنظام الأوزان
    if (category == 'بن' && unitsList.contains('كيلو')) {
      selectedUnit.value = 'كيلو';
    } else if (category == 'مشروب' && unitsList.contains('كوب')) {
      selectedUnit.value = 'كوب';
    }
  }

  void updateTabFilter(String category) {
    selectedTabCategory.value = category;
    applyFilters(searchCtrl.text);
  }

  void applyFilters(String query) {
    List<Product> results = allProducts;

    if (selectedTabCategory.value != 'الكل') {
      results = results.where((p) => p.category == selectedTabCategory.value).toList();
    }

    if (query.isNotEmpty) {
      results = results.where((p) =>
          p.name.toLowerCase().contains(query.toLowerCase())).toList();
    }

    filteredProducts.assignAll(results);
  }

  // ➕ إضافة أو تحديث منتج ببيانات ديناميكية كاملة
  Future<void> addProduct() async {
    if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) {
      AppSnackbar.warning("برجاء ملء اسم المنتج وسعر البيع");
      return;
    }
    if (selectedCategory.value == null || selectedUnit.value == null) {
      AppSnackbar.warning("برجاء تحديد القسم والوحدة أولاً");
      return;
    }

    String name = nameCtrl.text.trim();
    double price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
    double inputStock = double.tryParse(stockCtrl.text.trim()) ?? 0.0;
    String category = selectedCategory.value!;
    String safeUnit = selectedUnit.value!;

    try {
      final db = await dbHelper.database;
      final existingProducts = await db.query(
        'products',
        where: 'LOWER(name) = ? AND category = ?',
        whereArgs: [name.toLowerCase(), category],
      );

      const String stockColumn = 'initial_stock';

      if (existingProducts.isNotEmpty) {
        var firstProduct = existingProducts.first;
        int id = firstProduct['id'] as int;
        double currentInitialStock = (firstProduct[stockColumn] as num?)?.toDouble() ?? 0.0;
        double updatedStock = currentInitialStock + inputStock;

        await db.update(
          'products',
          {
            'price': price,
            'unit': safeUnit,
            stockColumn: updatedStock,
          },
          where: 'id = ?',
          whereArgs: [id],
        );

        if (existingProducts.length > 1) {
          for (int i = 1; i < existingProducts.length; i++) {
            int duplicateId = existingProducts[i]['id'] as int;
            await db.delete('products', where: 'id = ?', whereArgs: [duplicateId]);
          }
        }
        AppSnackbar.success("تم تحديث كمية المنتج الحالي بنجاح 🎉");
      } else {
        await db.insert('products', {
          'name': name,
          'price': price,
          'category': category,
          'unit': safeUnit,
          stockColumn: category == 'مشروب' ? 0.0 : inputStock,
        });
        AppSnackbar.success("تم إضافة الصنف الجديد للمخزن ✨");
      }

      nameCtrl.clear();
      priceCtrl.clear();
      stockCtrl.text = '0';
      selectedProductName.value = '';
      await loadProducts();
      DatabaseHelper.notifySalesChanged();
    } catch (e) {
      AppSnackbar.error("حدث خطأ أثناء الحفظ: $e");
    }
  }

  Future<void> insertProduct(Product product) async {
    try {
      final db = await dbHelper.database;
      final id = await db.insert('products', product.toMap());

      final newProduct = Product(
        id: id,
        name: product.name,
        price: product.price,
        category: product.category,
        unit: product.unit,
        initialStock: product.initialStock,
      );

      allProducts.add(newProduct);
      applyFilters(searchCtrl.text);
      await loadProductBalances();
    } catch (e) {
      AppSnackbar.error("حدث خطأ أثناء حفظ المنتج");
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      final db = await dbHelper.database;
      int deletedRows = await db.delete('products', where: 'id = ?', whereArgs: [id]);

      if (deletedRows > 0) {
        allProducts.removeWhere((p) => p.id == id);
        applyFilters(searchCtrl.text);
        await loadAvailableProductNames();
        await loadProductBalances();
        AppSnackbar.success('تم الحذف بنجاح');
      } else {
        AppSnackbar.error('فشل الحذف');
      }
    } catch (e) {
      AppSnackbar.error("حدث خطأ تقني أثناء الحذف");
    }
  }

  Future<void> updatePrice(int id, double newPrice) async {
    final db = await dbHelper.database;
    await db.update('products', {'price': newPrice}, where: 'id = ?', whereArgs: [id]);

    int index = allProducts.indexWhere((p) => p.id == id);
    if (index != -1) {
      final oldP = allProducts[index];
      allProducts[index] = Product(
        id: id,
        name: oldP.name,
        category: oldP.category,
        unit: oldP.unit,
        price: newPrice,
        initialStock: oldP.initialStock,
      );
      applyFilters(searchCtrl.text);
      AppSnackbar.warning('تم تعديل السعر');
    }
  }

  void clearForm() {
    priceCtrl.clear();
    stockCtrl.text = '0';
    if (availableProductNames.isNotEmpty) {
      selectedProductName.value = availableProductNames.first;
      nameCtrl.text = selectedProductName.value;
    } else {
      selectedProductName.value = '';
      nameCtrl.clear();
    }
    if (categoriesList.isNotEmpty) selectedCategory.value = categoriesList.first;
    if (unitsList.isNotEmpty) selectedUnit.value = unitsList.first;
  }

  @override
  void onClose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    searchCtrl.dispose();
    stockCtrl.dispose();
    super.onClose();
  }
}