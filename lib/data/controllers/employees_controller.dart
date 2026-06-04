import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/constants.dart';
import '../repositories/users_repository.dart';

// Controller المسؤول عن إدارة الموظفين (عرض + إضافة + حذف + بحث)
class EmployeesController extends GetxController {

  // Repository للتعامل مع قاعدة البيانات أو API
  final UsersRepository _repo = UsersRepository();

  // قائمة الموظفين (Reactive List عشان UI يتحدث تلقائي)
  final RxList<Map<String, dynamic>> employees = <Map<String, dynamic>>[].obs;

  // حالة التحميل العامة للشاشة (loading indicator)
  final RxBool isLoading = true.obs;

  // ✨ حالة التحميل الخاصة بعملية الحذف لمنع الكراش وتغيير زر الحذف في الديالوج
  final RxBool isDeleting = false.obs;

  // نص البحث
  final RxString searchQuery = "".obs;

  // Controllers الخاصة بحقول الإدخال
  final nameCtrl = TextEditingController();
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    // أول ما الكنترولر يشتغل نجيب الداتا
    fetchEmployees();
  }

  // جلب كل الموظفين من الداتا بيز
  Future<void> fetchEmployees() async {
    try {
      isLoading(true); // تشغيل اللودينج
      final data = await _repo.getAllEmployees();
      // تخزين البيانات في الـ reactive list
      employees.assignAll(data);
    } catch (e) {
      // في حالة الخطأ
      AppSnackbar.error("فشل تحميل البيانات: $e");
    } finally {
      // إيقاف اللودينج مهما حصل
      isLoading(false);
    }
  }

  // فلترة الموظفين حسب البحث
  List<Map<String, dynamic>> get filteredList {
    // لو مفيش بحث نرجع كل البيانات
    if (searchQuery.isEmpty) return employees;

    final query = searchQuery.value.toLowerCase().trim();

    return employees.where((e) {
      final name = (e['name'] ?? '').toString().toLowerCase();
      final username = (e['username'] ?? '').toString().toLowerCase();

      // البحث في الاسم واسم المستخدم
      return name.contains(query) || username.contains(query);
    }).toList();
  }

  // ✨ حذف موظف (معدلة ومضمونة 100%)
  Future<void> deleteUser(int id) async {
    try {
      isDeleting(true);

      // استدعاء التحديث من الـ ريبوزيتوري
      await _repo.deleteUser(id);

      // حذفه من القائمة المحلية عشان يختفي من الشاشة فوراً
      employees.removeWhere((e) => e['id'] == id);
      employees.refresh();

      AppSnackbar.success("تم حذف الحساب وبيانات الدخول بنجاح");
    } catch (e) {
      AppSnackbar.error("حدث خطأ أثناء الحذف: $e");
    } finally {
      isDeleting(false);
    }
  }
  // إضافة موظف جديد
// إضافة موظف جديد (مؤمنة بالكامل)
  Future<bool> addNewUser(String name, String user, String pass, String role) async {
    final cleanName = name.trim();
    final cleanUser = user.trim();
    final cleanPass = pass.trim();

    if (cleanName.isEmpty || cleanUser.isEmpty || cleanPass.isEmpty) {
      AppSnackbar.error("برجاء إكمال جميع الحقول");
      return false;
    }

    // 🔥 تعديل: نتحقق من عدم التكرار مع الموظفين النشطين فقط (الذين لم يتم أرشفة حسابهم)
    if (employees.any((e) =>
    e['role'] != 'archived' &&
        e['username'].toString().toLowerCase() == cleanUser.toLowerCase())) {
      AppSnackbar.error("اسم المستخدم موجود بالفعل");
      return false;
    }

    if (employees.any((e) =>
    e['role'] != 'archived' &&
        e['name'].toString().toLowerCase() == cleanName.toLowerCase())) {
      AppSnackbar.error("يوجد موظف بنفس الاسم");
      return false;
    }

    try {
      isLoading(true);

      await _repo.addUser(
        name: cleanName,
        username: cleanUser,
        password: cleanPass,
        role: role,
      );

      await fetchEmployees();
      AppSnackbar.success("تم إضافة $cleanName بنجاح");
      return true;
    } catch (e) {
      AppSnackbar.error("فشل الإضافة: $e");
      return false;
    } finally {
      isLoading(false);
    }
  }
  @override
  void onClose() {
    // تنظيف الـ controllers لتجنب memory leak
    nameCtrl.dispose();
    userCtrl.dispose();
    passCtrl.dispose();
    super.onClose();
  }
}