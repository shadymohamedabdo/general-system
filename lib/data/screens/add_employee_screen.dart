import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/employees_controller.dart';

// شاشة إضافة وإدارة الموظفين
class AddEmployeeScreen extends GetView<EmployeesController> {
  final Map<String, dynamic> currentUser;

  const AddEmployeeScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {

    // 🔐 حماية الشاشة: لو مش أدمن يرجعله رسالة
    if (currentUser['role'] != 'admin') {
      return const Scaffold(
        body: Center(child: Text('غير مصرح لك بالدخول')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F1E9), // لون الخلفية

      // 🔝 الـ AppBar
      appBar: AppBar(
        title: const Text(
          'إدارة فريق العمل',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF3E2723),
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // ➕ زر إضافة موظف
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF3E2723),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('موظف جديد', style: TextStyle(color: Colors.white)),
        onPressed: _showAddBottomSheet,
      ),

      // 📦 محتوى الشاشة
      body: Column(
        children: [

          // 🔍 شريط البحث
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (v) => controller.searchQuery.value = v, // فلترة البيانات
                decoration: InputDecoration(
                  hintText: 'ابحث عن موظف...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(Icons.search, color: Colors.brown[400]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),

          // 📋 قائمة الموظفين
          Expanded(
            child: Obx(() {

              // ⏳ حالة التحميل
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF3E2723)),
                );
              }

              // 🚫 لو مفيش بيانات
              if (controller.filteredList.isEmpty) {
                return _buildEmptyState();
              }

              // 📜 عرض القائمة
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: controller.filteredList.length,
                itemBuilder: (context, index) {
                  final emp = controller.filteredList[index];

                  // 👤 هل الموظف الحالي هو المستخدم؟
                  final bool isMe = emp['id'] == currentUser['id'];

                  return _buildEmployeeCard(emp, isMe);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  // ====================== كارت الموظف ======================
  Widget _buildEmployeeCard(Map<String, dynamic> emp, bool isMe) {

    final bool isAdmin = emp['role'] == 'admin';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),

      // 🎨 تصميم الكارت
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

        // 👤 صورة الموظف
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: isAdmin
              ? Colors.red[50]
              : const Color(0xFF3E2723).withValues(alpha: 0.1),
          child: Icon(
            isAdmin ? Icons.admin_panel_settings : Icons.person,
            color: isAdmin ? Colors.red[700] : const Color(0xFF3E2723),
            size: 32,
          ),
        ),

        // 📝 الاسم
        title: Row(
          children: [
            Text(
              emp['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.5),
            ),

            // ⭐ لو هو المستخدم الحالي
            if (isMe) ...[
              const SizedBox(width: 8),
              const Icon(Icons.star, color: Colors.amber, size: 22),
            ],
          ],
        ),

        // 🧾 بيانات إضافية
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emp['username'], style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 4),

            // 🏷️ نوع المستخدم
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isAdmin ? Colors.red[100] : Colors.brown[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isAdmin ? 'مدير النظام' : 'موظف',
                style: TextStyle(
                  fontSize: 12,
                  color: isAdmin ? Colors.red[800] : const Color(0xFF3E2723),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        // 🗑️ زر الحذف (مش لنفسك)
        trailing: isMe
            ? null
            : IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 26),
          onPressed: () => _confirmDelete(emp),
        ),
      ),
    );
  }

  // ====================== Empty State ======================
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 90, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('لا يوجد موظفين بعد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          const Text('اضغط على زر "+" لإضافة أول موظف',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ====================== BottomSheet الإضافة ======================
  void _showAddBottomSheet() {

    final formKey = GlobalKey<FormState>(); // مفتاح الفورم
    String role = 'employee';

    // 🧹 تنظيف الحقول
    controller.nameCtrl.clear();
    controller.userCtrl.clear();
    controller.passCtrl.clear();

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(24),

        // 🎨 تصميم الشيت
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),

        child: SingleChildScrollView(
          child: Form(
            key: formKey,

            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 🟰 الخط العلوي
                Center(
                  child: Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'إضافة موظف جديد',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 24),

                // 📝 الحقول
                _buildTextFormField(controller.nameCtrl, 'الاسم بالكامل', Icons.person_outline),
                _buildTextFormField(controller.userCtrl, 'اسم المستخدم', Icons.alternate_email),
                _buildTextFormField(controller.passCtrl, 'كلمة المرور', Icons.lock_outline, isPassword: true),

                const SizedBox(height: 20),

                // 🔽 اختيار الدور
                const Text('الصلاحية', style: TextStyle(fontWeight: FontWeight.w600)),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  items: const [
                    DropdownMenuItem(value: 'employee', child: Text('موظف (باريستا)')),
                    DropdownMenuItem(value: 'admin', child: Text('مدير (أدمن)')),
                  ],
                  onChanged: (v) => role = v!,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                const SizedBox(height: 32),

                // 💾 زر الحفظ
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3E2723),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),

                    onPressed: () async {

                      // ✅ تحقق من الفورم
                      if (formKey.currentState!.validate()) {

                        final success = await controller.addNewUser(
                          controller.nameCtrl.text,
                          controller.userCtrl.text,
                          controller.passCtrl.text,
                          role,
                        );

                        // 🔙 لو نجح يقفل كل الصفحات ويرجع للأولى
                        if (success) {

                          if (Get.context != null) {
                            Navigator.of(Get.context!).pop();
                          }
                        }
                      }
                    },

                    child: const Text(
                      'إضافة الموظف',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // ====================== TextFormField ======================
  Widget _buildTextFormField(
      TextEditingController ctrl,
      String label,
      IconData icon, {
        bool isPassword = false,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: ctrl,
        obscureText: isPassword,

        // ✅ Validation
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'هذا الحقل مطلوب';
          }
          if (isPassword && value.length < 4) {
            return 'كلمة المرور يجب أن تكون 4 أحرف على الأقل';
          }
          return null;
        },

        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF3E2723)),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF3E2723), width: 2),
          ),
        ),
      ),
    );
  }

  // ====================== تأكيد الحذف ======================
  void _confirmDelete(Map<String, dynamic> emp) {
    showDialog(
      context: Get.context!,
      barrierDismissible: false, // منع غلق الديالوج بالضغط خارجه أثناء الحذف
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            "حذف موظف",
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3E2723), fontSize: 18),
            textAlign: TextAlign.center,
          ),
          content: Text(
            "هل أنت متأكد من حذف ${emp['name']}؟",
            style: const TextStyle(fontSize: 15),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            // 1️⃣ زرار الإلغاء
            TextButton(
              onPressed: () {
                if (!controller.isDeleting.value) Navigator.pop(context);
              },
              child: Text("إلغاء", style: TextStyle(color: Colors.grey.shade700, fontSize: 15, fontWeight: FontWeight.bold)),
            ),

            // 2️⃣ زرار الحذف مراقب بالـ Obx بشكل سليم داخلياً
            Obx(() {
              if (controller.isDeleting.value) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2.5),
                  ),
                );
              }

              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                ),
                onPressed: () async {
                  // تنفيذ الحذف في قاعدة البيانات
                  await controller.deleteUser(emp['id']);

                  // قفل الديالوج بآمان عن طريق الـ Navigator المحلي
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text("حذف", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              );
            }),
          ],
        );
      },
    );
  }
}