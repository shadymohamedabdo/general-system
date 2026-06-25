import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../database_helper.dart';
import '../constants/constants.dart'; // عشان الـ AppSnackbar لو عندك

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
      AppSnackbar.success("تمت إضافة الفئة بنجاح");
    } catch (e) {
      AppSnackbar.error("فشل إضافة الفئة");
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      final db = await dbHelper.database;
      // تنبيه: يفضل التأكد أولاً أن الفئة غير مرتبطة بمنتجات
      await db.delete('categories', where: 'id = ?', whereArgs: [id]);
      await loadCategories();
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
      AppSnackbar.success("تم حذف الوحدة");
    } catch (e) {
      AppSnackbar.error("فشل حذف الوحدة، قد تكون مرتبطة بمنتجات");
    }
  }
}