import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../binding.dart';
import '../constants/constants.dart';
import '../repositories/users_repository.dart';
import '../screens/home_screen.dart';

class LoginController extends GetxController {
  var isLoading = false.obs;
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  final userFocus = FocusNode();
  final passwordFocus = FocusNode();

  // 🛠️ تم تصحيح النقص: تعريف الـ UserRepository للتعامل مع قاعدة البيانات في عملية الدخول
  final UsersRepository repo = UsersRepository();



  Future<void> login() async {
    // Validation
    if (usernameCtrl.text.isEmpty || passwordCtrl.text.isEmpty) {
      AppSnackbar.warning("برجاء إدخال اسم المستخدم وكلمة المرور!");
      return;
    }

    try {
      isLoading(true);

      final user = await repo.login(
        usernameCtrl.text.trim(),
        passwordCtrl.text.trim(),
      );

      if (user != null) {
        // Navigation to Home
        Get.offAll(
              () => const HomeScreen(),
          arguments: user,
          binding: HomeBinding(),
        );
      } else {
        AppSnackbar.error('اسم المستخدم أو كلمة المرور غير صحيحة');
      }
    } catch (e) {
      // Error handling (رسالة عامة)
      AppSnackbar.error('حدث خطأ، حاول مرة أخرى');
    } finally { // 🛠️ هنا التعديل تم تصحيح الحرف بنجاح
      isLoading(false);
    }
  }
  @override
  void onClose() {
    // Dispose الحقول لمنع الـ Memory Leak
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    userFocus.dispose();
    passwordFocus.dispose();
    super.onClose();
  }
}