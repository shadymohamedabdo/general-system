import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/constants.dart';
import '../database_helper.dart';
import 'login_screen.dart';

class TrialExpiredScreen extends StatelessWidget {
  final String reason;
  const TrialExpiredScreen({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 🛠️ زر سري: عند الضغط مطولاً على أيقونة القفل تفتح نافذة التفعيل
                  GestureDetector(
                    onLongPress: () => _showActivationDialog(context),
                    child: const Icon(Icons.lock_clock_rounded, size: 90, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'تنبيه النظام',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF4E342E)),
                  ),
                  const Divider(height: 30, thickness: 1.5),
                  Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
                  ),
                  const SizedBox(height: 25),

                  // 🔐 عرض السيريال نمبر الفريد للجهاز الحالي (علشان العميل يمليهولك في التليفون)
                  FutureBuilder<String>(
                    future: DatabaseHelper.instance.getWindowsSerial(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[400]!),
                          ),
                          child: SelectableText(
                            'رقم تعريف الجهاز: ${snapshot.data}',
                            style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.grey[700]),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.brown[50], borderRadius: BorderRadius.circular(15)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone_android, color: Colors.brown[800]),
                        const SizedBox(width: 10),
                        Text(
                          'ل للتفعيل: 01099389285',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown[900]),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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
        // الاستدعاء الذكي للدالة المركزية الموحدة من الـ DatabaseHelper 🎯
        if (DatabaseHelper.instance.verifyDailyActivationCode(codeCtrl.text)) {

          // جلب سيريال الجهاز الحالي المقفول عليه الهاردوير لمنع النقل
          String currentSerial = await DatabaseHelper.instance.getWindowsSerial();

          // تفعيل النسخة مدى الحياة على الجهاز ده
          await DatabaseHelper.instance.activateSystemFull(currentSerial);

          Get.back(); // إغلاق الـ Dialog
          Get.offAll(() => const LoginScreen());
          AppSnackbar.success('تم تفعيل النسخة الكاملة للجهاز بنجاح مدى الحياة! ✨');
        } else {
          AppSnackbar.error('الكود غير صحيح أو انتهت صلاحيته اليومية!');
        }
      },
    );
  }
}