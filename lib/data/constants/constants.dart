import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppSnackbar {
  // ✅ نجاح
  static void success(String message) {
    Get.rawSnackbar(
      messageText: Text(
        message,
        textAlign: TextAlign.center,

        style: const TextStyle(

          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.green,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
      borderRadius: 0,
      margin: EdgeInsets.zero,
    );
  }

  // ❌ خطأ
  static void error(String message) {
    Get.rawSnackbar(
      messageText: Text(
        message,
        textAlign: TextAlign.center,

        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: const Color(0xFFEF5350),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
      borderRadius: 0,
      margin: EdgeInsets.zero,
    );
  }

  // ⚠️ تحذير
  static void warning(String message) {
    Get.rawSnackbar(
      messageText: Text(
        message,
        textAlign: TextAlign.center,

        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: Colors.orange,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 1),
      borderRadius: 0,
      margin: EdgeInsets.zero,
    );
  }
}

// images
const coffeeMainPage = 'images/coffe.png' ;
const coffeeSalePage = 'images/poss.png' ;