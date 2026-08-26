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
  final TextEditingController stockCtrl = TextEditingController(text: '0');

  var selectedCategory = 'بن'.obs;
  var selectedTabCategory = 'الكل'.obs;
  var selectedUnit = 'كيلو'.obs;

  var categoriesList = <String>[].obs;
  var unitsList = <String>[].obs;

  var allProducts = <Product>[].obs;
  var filteredProducts = <Product>[].obs;

  var availableProductNames = <String>[].obs;
  var selectedProductName = ''.obs;

  var productStock = <int, double>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadCategoriesAndUnits();
    loadProducts();
  }

  Future<void> loadCategoriesAndUnits() async {
    try {
      final db = await dbHelper.database;
      final catData = await db.query('categories', orderBy: 'id ASC');
      final cats = catData.map((e) => e['name'] as String).toList();
      categoriesList.assignAll(cats);

      final unitData = await db.query('units', orderBy: 'id ASC');
      final uList = unitData.map((e) => e['name'] as String).toList();
      unitsList.assignAll(uList);

      if (categoriesList.isNotEmpty && !categoriesList.contains(selectedCategory.value)) {
        selectedCategory.value = categoriesList.first;
      }
    } catch (e) {
      // خطأ صامت
    }
  }

  Future<void> loadProducts() async {
    final db = await dbHelper.database;
    final maps = await db.query('products');

    allProducts.assignAll(maps.map((e) => Product.fromMap(e)).toList());
    await loadAvailableProductNames();
    await loadProductBalances();
    applyFilters(searchCtrl.text);
  }

  // 📊 حساب الرصيد الذكي للجميع (إذا لم تُدخل كمية يصبح رصيد مفتوح -1.0)
  Future<void> loadProductBalances() async {
    try {
      final db = await dbHelper.database;

      final purchasesResult = await db.rawQuery('''
      SELECT product_name, SUM(quantity) as total_purchased 
      FROM purchases 
      GROUP BY product_name
    ''');

      Map<String, double> purchasedQuantity = {};
      for (var row in purchasesResult) {
        final name = (row['product_name'] as String?)?.trim().toLowerCase();
        final qty = (row['total_purchased'] as num?)?.toDouble() ?? 0.0;
        if (name != null) purchasedQuantity[name] = qty;
      }

      final salesResult = await db.rawQuery('''
      SELECT product_id, SUM(quantity) as total_sold 
      FROM sales 
      GROUP BY product_id
    ''');

      Map<int, double> salesQuantity = {};
      for (var row in salesResult) {
        final productId = row['product_id'] as int?;
        final qty = (row['total_sold'] as num?)?.toDouble() ?? 0.0;
        if (productId != null) salesQuantity[productId] = qty;
      }

      final Map<int, double> newStock = {};

      for (var product in allProducts) {
        if (product.id == null) continue;

        String pNameNormalized = product.name.trim().toLowerCase();
        double purchased = purchasedQuantity[pNameNormalized] ?? 0.0;
        double manualStock = product.initialStock ?? 0.0;
        double totalIncoming = purchased + manualStock;

        // 💡 إذا لم يدخل المستخدم كمية أولية ولم يشترِ بضاعة -> رصيد مفتوح (-1.0)
        if (totalIncoming <= 0) {
          newStock[product.id!] = -1.0;
        } else {
          double sold = salesQuantity[product.id!] ?? 0.0;
          double remaining = totalIncoming - sold;
          newStock[product.id!] = remaining > 0 ? remaining : 0.0;
        }
      }

      productStock.value = newStock;
      productStock.refresh();
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
    } catch (e) {
      // خطأ صامت
    }
  }

  // 🎯 ضبط الوحدة التلقائية حسب الفئة: (بن -> كيلو | مشروب -> كوب | غيره -> قطعة)
  void changeCategory(String category) {
    selectedCategory.value = category;
    if (category == 'بن') {
      selectedUnit.value = 'كيلو';
    } else if (category == 'مشروب' || category.contains('مشروب')) {
      selectedUnit.value = 'كوب';
    } else {
      selectedUnit.value = 'قطعة';
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

  Future<void> addProduct() async {
    if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) {
      AppSnackbar.warning("برجاء ملء اسم المنتج وسعر البيع");
      return;
    }

    String name = nameCtrl.text.trim();
    double price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
    double inputStock = double.tryParse(stockCtrl.text.trim()) ?? 0.0;
    String category = selectedCategory.value;
    String safeUnit = selectedUnit.value;

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
          stockColumn: inputStock,
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
      AppSnackbar.error("حدث خطأ أثناء حفظ المنتج في قاعدة البيانات");
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
        AppSnackbar.error('فشل الحذف: الرقم $id غير موجود في قاعدة البيانات');
      }
    } catch (e) {
      AppSnackbar.error("حدث خطأ تقني أثناء الحذف");
    }
  }

  Future<void> updatePrice(int id, double newPrice) async {
    final db = await dbHelper.database;

    await db.update('products',
        {'price': newPrice},
        where: 'id = ?',
        whereArgs: [id]);

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
    if (categoriesList.isNotEmpty) {
      selectedCategory.value = categoriesList.first;
      changeCategory(categoriesList.first);
    }
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