import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/constants.dart';
import '../database_helper.dart';
import '../models/product_model.dart';
import '../repositories/purchases_repository.dart';
import '../repositories/reports_repository.dart';

class ProductsController extends GetxController {

  // 🗄️ instance من الداتابيز
  final dbHelper = DatabaseHelper.instance;

  // 📦 repository خاص بالمشتريات
  final _purchasesRepo = PurchasesRepository();

  // 📊 repository خاص بالتقارير (المبيعات)
  final _reportsRepo = ReportsRepository();

  // 🎯 controllers للـ TextFields
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final searchCtrl = TextEditingController();
  final TextEditingController stockCtrl = TextEditingController(text: '0'); // حقل كمية المصنع الجديد

  // 📌 الحالة الحالية للفلاتر
  var selectedCategory = 'بن'.obs;         // نوع المنتج
  var selectedTabCategory = 'الكل'.obs;    // التبويب الحالي
  var selectedUnit = 'كيلو'.obs;           // وحدة القياس

  // 📋 كل المنتجات + المنتجات بعد الفلترة
  var allProducts = <Product>[].obs;
  var filteredProducts = <Product>[].obs;

  // 🆕 أسماء منتجات متاحة (جاية من المشتريات ومش مضافة كمنتج)
  var availableProductNames = <String>[].obs;
  var selectedProductName = ''.obs;

  // 📦 رصيد كل منتج النهائي (المشتريات أو بضاعة الجرد - المبيعات)
  var productStock = <int, double>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadProducts(); // 🚀 تحميل البيانات أول ما الكنترولر يشتغل
  }

  // 🔄 تحميل كل المنتجات من الداتابيز
  Future<void> loadProducts() async {
    final db = await dbHelper.database;

    // 📥 قراءة المنتجات من الجدول
    final maps = await db.query('products');

    // 🔄 تحويل البيانات لـ model
    allProducts.assignAll(maps.map((e) => Product.fromMap(e)).toList());

    // 🧠 تحميل الأسماء المتاحة (لازم قبل الأرصدة)
    await loadAvailableProductNames();

    // 📊 حساب الرصيد لكل منتج
    await loadProductBalances();

    // 🔍 تطبيق الفلترة
    applyFilters(searchCtrl.text);
  }

  // 📊 حساب الرصيد الذكي: يمنع الجمع التلقائي ويلتزم باقتراحك بالملي
// 📊 حساب الرصيد الذكي: يدمج المشتريات الخارجية مع بضاعة المصنع المباشرة بدقة
  Future<void> loadProductBalances() async {
    try {
      final now = DateTime.now();

      final purchases = await _purchasesRepo.getPurchasesForMonth(now.month, now.year);
      final sales = await _reportsRepo.getMonthlySalesGroupedByProduct(now.month, now.year);

      // تجميع المشتريات بناءً على اسم المنتج للشهر الحالي
      Map<String, double> purchasedQuantity = {};
      for (var p in purchases) {
        purchasedQuantity[p.productName.trim().toLowerCase()] =
            (purchasedQuantity[p.productName.trim().toLowerCase()] ?? 0) + p.quantity;
      }

      final Map<int, double> newStock = {};

      for (var product in allProducts) {
        if (product.id == null) continue; // حماية

        String pNameNormalized = product.name.trim().toLowerCase();

        if (product.category == 'مشروب' || product.category == 'أكل سريع') {
          newStock[product.id!] = 999.0; // أرصدة مفتوحة للمشروبات والوجبات
        } else {
          double purchased = purchasedQuantity[pNameNormalized] ?? 0;
          double manualStock = product.initialStock ?? 0.0;

          // ✨ التعديل الجوهري: إجمالي الداخل = المشتريات الخارجية + كمية المصنع اليدوية
          double totalIncoming = purchased + manualStock; // 10 مشتريات + 20 مصنع = 30 كيلو داخلي

          double sold = sales[product.name] ?? 0;
          double remaining = totalIncoming - sold;

          // حفظ الرصيد الفعلي (المتبقي) مع منع الأرقام السالبة
          newStock[product.id!] = remaining > 0 ? remaining : 0.0;
        }
      }

      productStock.value = newStock;

    } catch (e) {
      AppSnackbar.error("خطأ في حساب الأرصدة: $e");
    }
  }
  // 🎯 تحميل الأسماء للمساعدة فقط
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

  // 🔄 تغيير التصنيف + تغيير الوحدة تلقائي
  void changeCategory(String category) {
    selectedCategory.value = category;
    selectedUnit.value = (category == 'بن') ? 'كيلو' : (category == 'مشروب') ? 'كوب' : 'قطعة';
  }

  // 📂 تغيير التبويب
  void updateTabFilter(String category) {
    selectedTabCategory.value = category;
    applyFilters(searchCtrl.text);
  }

  // 🔍 تطبيق الفلترة (حسب التبويب + البحث)
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

  // ➕ إضافة أو تحديث منتج جديد بدون فرض قيم الـ 50 الإجبارية
  Future<void> addProduct() async {

    if (nameCtrl.text.trim().isEmpty || priceCtrl.text.trim().isEmpty) {
      AppSnackbar.warning("برجاء ملء اسم المنتج وسعر البيع");
      return;
    }

    String name = nameCtrl.text.trim();
    double price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
    double inputStock = double.tryParse(stockCtrl.text.trim()) ?? 0.0;
    String category = selectedCategory.value;
    String safeUnit = (category == 'بن') ? 'كيلو' : (category == 'مشروب') ? 'كوب' : 'قطعة';

    // ⚡ إلغاء فرض القيمة 50: لو المستخدم سابها صفر أو فاضية، تفضل صفر والسيستم يعتمد على فواتير المشتريات
    // تم حذف شرط فرض الـ 50 القديم هنا تماماً

    try {
      final db = await dbHelper.database;
      final existingProducts = await db.query(
        'products',
        where: 'LOWER(name) = ? AND category = ?',
        whereArgs: [name.toLowerCase(), category],
      );

      const String stockColumn = 'initial_stock'; // الحفاظ على اسم العمود الفعلي

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

      // 🧹 تنظيف الحقول وإعادة التصفير
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

  // 🗑️ حذف منتج
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

  // ✏️ تعديل سعر المنتج
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

  // 🧹 إعادة تعيين الفورم
  void clearForm() {
    priceCtrl.clear();
    stockCtrl.text = '0'; // تصفير حقل الكمية عند المسح للسلامة
    if (availableProductNames.isNotEmpty) {
      selectedProductName.value = availableProductNames.first;
      nameCtrl.text = selectedProductName.value;
    } else {
      selectedProductName.value = '';
      nameCtrl.clear();
    }
    selectedCategory.value = 'بن';
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