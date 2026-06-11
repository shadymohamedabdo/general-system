import 'dart:async';
import 'package:get/get.dart';
import '../database_helper.dart';
import '../screens/expired.dart';
import '../screens/login_screen.dart';
import 'login_controller.dart';

class HomeController extends GetxController {
  // استقبال بيانات المستخدم اللي جاية من صفحة اللوجن
  late Map<String, dynamic> currentUser;
  Timer? _licenseTimer;
  bool _isExpiringChecked = false; // 🛠️ متغير لمنع التكرار والتعليق في الخلفية

  @override
  void onInit() {
    super.onInit();
    currentUser = Get.arguments ?? {};
    _checkLicenseOnHome();

    // فحص دوري كل 10 ثوانٍ للتأكد من الأمان أثناء تشغيل البرنامج
    _licenseTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isExpiringChecked) {
        _checkLicenseOnHome();
      }
    });
  }

  bool get isAdmin => currentUser['role'] == 'admin';
  String get displayName => currentUser['name'] ?? currentUser['username'] ?? 'المستخدم';

  Future<void> _checkLicenseOnHome() async {
    final securityData = await DatabaseHelper.instance.getSecurityData();

    if (securityData.isNotEmpty) {
      int isActivated = securityData['is_activated'] as int;
      String savedSerial = (securityData['device_serial'] ?? '') as String;

      // جلب سيريال بوردة الجهاز الحالي الحقيقية
      String currentHardwareSerial = await DatabaseHelper.instance.getWindowsSerial();

      // 1️⃣ 🎯 [الـقـفـل الـصـخـري لكشف النقل]: لو السيريال اتغير (سواء النسخة متفعلة أو تجريبية) اطرد بره
      if (savedSerial.isNotEmpty && savedSerial != currentHardwareSerial) {
        _stopTimerAndLock("تم رصد نقل غير مصرح به للنظام على جهاز آخر! يرجى التواصل مع البشمهندس شادي لتنشيط النسخة أو بدء فترة تجربة جديدة.");
        return;
      }

      DateTime trialStart = DateTime.parse(securityData['trial_start'] as String);
      String lastOpenedStr = (securityData['last_opened'] ?? '') as String;
      DateTime now = DateTime.now();

      // 2️⃣ 🔒 كشف التلاعب بالساعة (Time Travel)
      if (lastOpenedStr.isNotEmpty) {
        DateTime lastOpened = DateTime.parse(lastOpenedStr);
        if (now.isBefore(lastOpened)) {
          _stopTimerAndLock("تم رصد تلاعب في وقت الجهاز الفعلي! يرجى إعادة ضبط الوقت وتفعيل النسخة الكاملة.");
          return;
        }
      }

      // 3️⃣ لو النسخة متفعلة رسمي مدى الحياة والسيريال سليم.. بنقفل التايمر لتوفير الرام
      if (isActivated == 1) {
        _licenseTimer?.cancel();
        return;
      }

      // 4️⃣ ⏳ حساب فترة الـ 7 أيام التجريبية بالأيام
      int daysPassed = now.difference(trialStart).inDays;
      if (daysPassed >= 7 || daysPassed < 0) {
        _stopTimerAndLock("انتهت الفترة التجريبية المجانية للسيستم (7 أيام).\nيرجى التواصل مع البشمهندس شادي (01099389285) لتفعيل النسخة الكاملة.");
        return;
      }

      // حدّث الوقت الآمن الحالي طالما كلو تمام والبرنامج شغال
      await DatabaseHelper.instance.updateLastOpenedTime(now.toIso8601String());
    }
  }

  // 🛠️ دالة مركزية توقف التايمر تماماً وتطرد المستخدم لشاشة القفل بدون تعليق الـ Dialog
  void _stopTimerAndLock(String reason) {
    _isExpiringChecked = true;
    _licenseTimer?.cancel(); // إيقاف التايمر نهائياً لمنع تداخل الأكواد في الخلفية
    Get.offAll(() => TrialExpiredScreen(reason: reason));
  }

  void logout() {
    if (Get.isRegistered<LoginController>()) {
      final loginCtrl = Get.find<LoginController>();
      loginCtrl.usernameCtrl.clear();    // امسح حقل اليوزر
      loginCtrl.passwordCtrl.clear();   // امسح حقل الباسورد
    }
    Get.offAll(() => const LoginScreen());
  }

  @override
  void onClose() {
    _licenseTimer?.cancel(); // إلغاء التايمر عند إغلاق الكنترولر لحفظ الميموري
    super.onClose();
  }
}