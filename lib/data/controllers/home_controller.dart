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
    // Get.arguments هي الطريقة الأنظف لاستلام البيانات في GetX
    currentUser = Get.arguments ?? {};
    _checkLicenseOnHome();

    // فحص كل 10 ثوانٍ، لكن بشرط إن السيستم ما يكونش قفل بالفعل
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

    if (securityData != null) {
      int isActivated = securityData['is_activated'] as int;
      String savedSerial = (securityData['device_serial'] ?? '') as String;

      // جلب سيريال بوردة الجهاز الحالي الحقيقية
      String currentHardwareSerial = await DatabaseHelper.instance.getWindowsSerial();

      // 🔐 [الـقـفـل الـصـخـري]: لو النسخة متفعلة، تأكد إن السيريال هو هو وماتنقلش لجهاز تاني
      if (isActivated == 1) {
        if (savedSerial != currentHardwareSerial) {
          // قفشناه! نقل قاعدة البيانات لجهاز تاني
          _stopTimerAndLock("تم رصد نقل غير مصرح به لقاعدة البيانات على جهاز آخر! يرجى التواصل مع المطور لتنشيط النسخة على هذا الجهاز.");
        } else {
          _licenseTimer?.cancel(); // متفعل وصاحب حق، اقفل التايمر عشان الرام
        }
        return;
      }

      DateTime trialStart = DateTime.parse(securityData['trial_start'] as String);
      DateTime lastOpened = DateTime.parse(securityData['last_opened'] as String);
      DateTime now = DateTime.now();

      // 1. كشف التلاعب بالساعة
      if (now.isBefore(lastOpened)) {
        _stopTimerAndLock("تم رصد تلاعب في وقت الجهاز الفعلي! يرجى إعادة ضبط الوقت وتفعيل النسخة الكاملة.");
        return;
      }

      // 2. كشف انتهاء الـ 24 ساعة التجريبية
      int hoursPassed = now.difference(trialStart).inHours;
      if (hoursPassed >= 24) {
        _stopTimerAndLock("انتهت الفترة التجريبية للسيستم (24 ساعة). يرجى التواصل مع المطور لتفعيل النسخة الكاملة واستمرار العمل.");
        return;
      }

      // حدّث الوقت الآمن الحالي
      await DatabaseHelper.instance.updateLastOpenedTime(now.toIso8601String());
    }
  }
  // 🛠️ دالة سحرية توقف التايمر تماماً وتطرد المستخدم لشاشة القفل بدون تعليق الـ Dialog
  void _stopTimerAndLock(String reason) {
    _isExpiringChecked = true;
    _licenseTimer?.cancel(); // إيقاف التايمر نهائياً لمنع تداخل الأكواد في الخلفية
    Get.offAll(() => TrialExpiredScreen(reason: reason));
  }

  void logout() {
    if (Get.isRegistered<LoginController>()) {
      final loginCtrl = Get.find<LoginController>();
      loginCtrl.usernameCtrl.clear();    // امسح حقل الايميل
      loginCtrl.passwordCtrl.clear(); // امسح حقل الباسورد
    }
    Get.offAll(() => const LoginScreen());
  }

  @override
  void onClose() {
    _licenseTimer?.cancel(); // إلغاء التايمر عند إغلاق الكنترولر لحفظ الميموري
    super.onClose();
  }
}