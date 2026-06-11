import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_config.dart';
import '../constants/constants.dart';
import '../controllers/login_controller.dart';
import '../database_helper.dart';

class LoginScreen extends GetView<LoginController> {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown[50],
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: 400,
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🛠️ زر سري: عند الضغط مطولاً على أيقونة القهوة تفتح نافذة التفعيل
                    GestureDetector(
                      onLongPress: () => _showActivationDialog(context),
                      child:  Icon(Icons.coffee_rounded, size: 80, color: AppConfig.system),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'تسجيل الدخول',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppConfig.system),
                    ),
                    const SizedBox(height: 30),

                    // حقل اسم المستخدم
                    TextField(
                      controller: controller.usernameCtrl,
                      focusNode: controller.userFocus,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'اسم المستخدم',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onSubmitted: (_) {
                        controller.passwordFocus.requestFocus();
                      },
                    ),
                    const SizedBox(height: 16),

                    // حقل كلمة المرور
                    TextField(
                      controller: controller.passwordCtrl,
                      focusNode: controller.passwordFocus,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onSubmitted: (_) => controller.login(),
                    ),
                    const SizedBox(height: 30),

                    // زر تسجيل الدخول
                    Obx(() => SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: controller.isLoading.value ? null : controller.login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConfig.system,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        ),
                        child: controller.isLoading.value
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('دخول النظام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🛠️ نافذة إدخال كود التفعيل (تظهر لك أنت فقط عند الضغط المطول)
  void _showActivationDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    Get.defaultDialog(
      title: "تفعيل النسخة الكاملة",
      content: Padding(
        padding: const EdgeInsets.all(12.0),
        child: TextField(
          controller: codeCtrl,
          decoration: const InputDecoration(
            labelText: "أدخل كود التفعيل الماجيك الكامل",
            border: OutlineInputBorder(),
          ),
        ),
      ),
      textConfirm: "تفعيل الآن",
      textCancel: "إلغاء",
      confirmTextColor: Colors.white,
      buttonColor: Colors.brown[700],
      onConfirm: () async {
        // الاستدعاء الذكي للدالة المركزية من الـ DatabaseHelper 🎯
        if (DatabaseHelper.instance.verifyDailyActivationCode(codeCtrl.text)) {

          // 🛠️ جلب سيريال هذا الجهاز لقفل الداتابيز عليه فوراً ومنع النقل
          String currentSerial = await DatabaseHelper.instance.getWindowsSerial();
          await DatabaseHelper.instance.activateSystemFull(currentSerial);

          Get.back(); // إغلاق الـ Dialog
          AppSnackbar.success("تم تفعيل النسخة الكاملة للمحل بنجاح مدى الحياة! ✨");
          await Future.delayed(const Duration(seconds: 1));
          Get.offAll(() => const LoginScreen());
        } else {
          AppSnackbar.error("الكود غير صحيح أو انتهت صلاحيته اليومية!");
        }
      },
    );
  }
}