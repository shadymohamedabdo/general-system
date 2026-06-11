import 'package:flutter/material.dart';

class AppConfig {
  // ==========================================
  // 1️⃣ إعدادات الهوية والنشاط الأساسية
  // ==========================================

  // اسم النشاط اللي هيظهر في الشاشات والفاتورة
  static const String businessName = "كافيه شادي  "; // 👈 غيرها لـ "صيدلية الشفاء" أو "سوبر ماركت الخير"

  // العناوين الفرعية في الشاشات
  static const String salesHeaderTitle = "إضافة مبيعات الكافيه"; // 👈 أو "صرف الروشتة والأدوية"

  // ==========================================
  // 2️⃣ مسارات الصور والخلفيات (Images)
  // ==========================================
  static const String logoPath = 'images/coffe_logo.png';
  static const String mainPageBg = 'images/coffe.png'; // خلفية الصفحة الرئيسية
  static const String salePageBg = 'images/poss.png';  // خلفية شاشة البيع الـ POS

  // ==========================================
  // 3️⃣ الألوان الثيمية الموحدة (Colors)
  // ==========================================
  static const Color primaryColor = Colors.brown; // 👈 اللون الأساسي (Teal للصيدلية، Blue للماركت)
  static final Color primaryColorDark = Colors.brown.shade800; // الدرجة الغامقة للأزرار
  static final Color lightBackground = Colors.brown.shade50;  // لون خلفية الحقول والـ Dropdowns
  static final Color system =  Colors.brown;

  // ==========================================
  // 4️⃣ أيقونة النشاط الأساسية (Icons)
  // ==========================================
  static const IconData mainIcon = Icons.shopping_basket_outlined; // 👈 أو Icons.medication للصيدلية

  // ==========================================
  // 5️⃣ مفاتيح التحكم في ميزات السيستم (Feature Toggles)
  // ==========================================

  // ⚖️ هل النشاط يحتوي على مبيعات موازين وأوزان جاهزة (ربع، ثمن، نصف كيلو)؟
  // للكافيه (بن) = true | للصيدلية أو الماركت العادي = false
  static const bool enableWeightSystem = true;

  // 🔢 هل السيستم يسمح ببيع كميات بكسور عشرية (مثل 1.250 كيلو)؟
  // للكافيه والسوبر ماركت = true | للصيدلية ومحلات الموبايلات والملابس = false (البيع بالقطعة الصحيحة)
  static const bool allowDecimalQuantity = true;
}