import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../database_helper.dart';
import '../constants/constants.dart';
import 'products_controller.dart'; // تم إضافة استيراد ProductsController للمزامنة

class AttributesController extends GetxController {
  final dbHelper = DatabaseHelper.instance;

  // قوائم المراقبة الديناميكية
  var categories = <Map<String, dynamic>>[].obs;
  var units = <Map<String, dynamic>>[].obs;

  var isCategoriesLoading = true.obs;
  var isUnitsLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadCategories();
    loadUnits();
  }

  // ==================== منطق الفئات (Categories) ====================
  Future<void> loadCategories() async {
    try {
      isCategoriesLoading(true);
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> data = await db.query('categories', orderBy: 'id DESC');
      categories.assignAll(data);
    } catch (e) {
      AppSnackbar.error("فشل تحميل الفئات");
    } finally {
      isCategoriesLoading(false);
    }
  }

  Future<void> addCategory(String name) async {
    if (name.trim().isEmpty) return;
    try {
      final db = await dbHelper.database;
      await db.insert('categories', {'name': name.trim()});
      await loadCategories();

      // 🔑 إرسال تحديث لـ ProductsController فوراً عند إضافة فئة جديدة
      if (Get.isRegistered<ProductsController>()) {
        Get.find<ProductsController>().loadCategoriesAndUnits();
      }

      AppSnackbar.success("تمت إضافة الفئة بنجاح");
    } catch (e) {
      AppSnackbar.error("فشل إضافة الفئة");
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      final db = await dbHelper.database;
      await db.delete('categories', where: 'id = ?', whereArgs: [id]);
      await loadCategories();

      // 🔑 إرسال تحديث لـ ProductsController فوراً عند حذف فئة
      if (Get.isRegistered<ProductsController>()) {
        Get.find<ProductsController>().loadCategoriesAndUnits();
      }

      AppSnackbar.success("تم حذف الفئة");
    } catch (e) {
      AppSnackbar.error("فشل حذف الفئة، قد تكون مرتبطة بمنتجات");
    }
  }

  // ==================== منطق الوحدات (Units) ====================
  Future<void> loadUnits() async {
    try {
      isUnitsLoading(true);
      final db = await dbHelper.database;
      final List<Map<String, dynamic>> data = await db.query('units', orderBy: 'id DESC');
      units.assignAll(data);
    } catch (e) {
      AppSnackbar.error("فشل تحميل الوحدات");
    } finally {
      isUnitsLoading(false);
    }
  }

  Future<void> addUnit(String name) async {
    if (name.trim().isEmpty) return;
    try {
      final db = await dbHelper.database;
      await db.insert('units', {'name': name.trim()});
      await loadUnits();

      // 🔑 إرسال تحديث لـ ProductsController فوراً عند إضافة وحدة قياس جديدة
      if (Get.isRegistered<ProductsController>()) {
        Get.find<ProductsController>().loadCategoriesAndUnits();
      }

      AppSnackbar.success("تمت إضافة الوحدة بنجاح");
    } catch (e) {
      AppSnackbar.error("فشل إضافة الوحدة");
    }
  }

  Future<void> deleteUnit(int id) async {
    try {
      final db = await dbHelper.database;
      await db.delete('units', where: 'id = ?', whereArgs: [id]);
      await loadUnits();

      // 🔑 إرسال تحديث لـ ProductsController فوراً عند حذف وحدة
      if (Get.isRegistered<ProductsController>()) {
        Get.find<ProductsController>().loadCategoriesAndUnits();
      }

      AppSnackbar.success("تم حذف الوحدة");
    } catch (e) {
      AppSnackbar.error("فشل حذف الوحدة، قد تكون مرتبطة بمنتجات");
    }
  }
}