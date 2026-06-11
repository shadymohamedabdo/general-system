import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../binding.dart';
import '../constants/app_config.dart';
import '../constants/constants.dart';
import '../controllers/home_controller.dart';
import '../database_helper.dart';
import 'add_sale_screen.dart';
import 'shift_report_screen.dart';
import 'monthly_report.dart';
import 'dashboard_screen.dart';
import 'shift_screen.dart';
import 'products_screen.dart';
import 'add_employee_screen.dart';
import 'profit_calculator.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA), // خلفية طبية فاتحة ونظيفة جداً مريحة للعين
      appBar: AppBar(
        title: Text(
          AppConfig.businessName,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: AppConfig.system, // AppBar صريح متناسق مع هوية السيستم
        elevation: 2,
        actions: [
          if (controller.isAdmin)
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
              ),
              tooltip: 'تصفير الحسابات والبيانات',
              onPressed: () => _showResetConfirmationDialog(context),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 10),
            child: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.logout, color: Colors.white, size: 20),
              ),
              tooltip: 'تسجيل خروج',
              onPressed: () => controller.logout(),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: GridView.count(
            crossAxisCount: isLargeScreen ? 4 : 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: isLargeScreen ? 1.5 : 1.15,
            children: [
              _buildCleanMenuItem(
                label: 'تسجيل بيع',
                icon: Icons.add_shopping_cart_rounded,
                baseColor: Colors.green[600]!,
                onTap: () => Get.to(() => AddSaleScreen(currentUser: controller.currentUser), binding: AddSaleBinding()),
                isMain: true,
              ),
              _buildCleanMenuItem(
                label: 'تقرير الشيفت',
                icon: Icons.receipt_long_rounded,
                baseColor: Colors.orange[700]!,
                onTap: () => Get.to(() => ShiftReportScreen(currentUser: controller.currentUser), binding: ShiftReportBinding()),
              ),
              _buildCleanMenuItem(
                label: 'إدارة الشيفتات',
                icon: Icons.history_toggle_off_rounded,
                baseColor: Colors.red[600]!,
                onTap: () => Get.to(() => ShiftScreen(currentUserName: controller.displayName), binding: ShiftBinding()),
              ),
              _buildCleanMenuItem(
                label: 'المصروفات',
                icon: Icons.calculate_rounded,
                baseColor: Colors.blue[600]!,
                onTap: () => Get.to(() => const NetProfitScreen(), binding: CalculatorBinding()),
              ),
              if (controller.isAdmin) ...[
                _buildCleanMenuItem(
                  label: 'التقرير الشهري',
                  icon: Icons.calendar_month_rounded,
                  baseColor: Colors.teal[600]!,
                  onTap: () => Get.to(() => MonthlyReportScreen(), binding: MonthlyReportBinding()),
                ),
                _buildCleanMenuItem(
                  label: 'إدارة المنتجات',
                  icon: Icons.inventory_2_rounded,
                  baseColor: Colors.amber[800]!,
                  onTap: () => Get.to(() => const ProductsScreen(), binding: ProductsBinding()),
                ),
                _buildCleanMenuItem(
                  label: 'الاحصائيات',
                  icon: Icons.dashboard_rounded,
                  baseColor: Colors.indigo[600]!,
                  onTap: () => Get.to(() => const DashboardScreen(), binding: DashboardBinding()),
                ),
                _buildCleanMenuItem(
                  label: 'إدارة الموظفين',
                  icon: Icons.badge_rounded,
                  baseColor: Colors.purple[600]!,
                  onTap: () => Get.to(() => AddEmployeeScreen(currentUser: controller.currentUser), binding: EmployeesBinding()),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildCleanMenuItem({
    required String label,
    required IconData icon,
    required Color baseColor,
    required VoidCallback onTap,
    bool isMain = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey[200]!, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isMain ? 14 : 10),
              decoration: BoxDecoration(
                color: baseColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: isMain ? 36 : 28, color: baseColor),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: isMain ? 16 : 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 55,
      decoration: BoxDecoration(
        color: AppConfig.system,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Center(
        child: Text(
          'مرحباً بك: ${controller.displayName}',
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showResetConfirmationDialog(BuildContext context) {
    Get.defaultDialog(
      title: "تنبيه خطير جداً! ⚠️",
      titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
      content: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          "هل أنت متأكد من رغبتك في تصفير النظام بالكامل؟\nهذا الإجراء سيقوم بحذف جميع المنتجات، المبيعات، الفئات، الوحدات، المصروفات، والشيفتات نهائياً! لن يتبقى سوى حسابات الموظفين فقط.",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ),
      textConfirm: "نعم، صفر السيستم",
      textCancel: "تراجع",
      confirmTextColor: Colors.white,
      cancelTextColor: Colors.black87,
      buttonColor: Colors.red[700],
      onConfirm: () async {
        Get.back();
        Get.showOverlay(
          asyncFunction: () => DatabaseHelper.instance.clearAllTransactionsData(),
          loadingWidget: Center(child: CircularProgressIndicator(color: AppConfig.primaryColor)),
        );
        AppSnackbar.success('تم تصفير النظام وإعادة تهيئة البيانات بنجاح!');
      },
    );
  }
}