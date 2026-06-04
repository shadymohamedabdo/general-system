import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:get/get.dart';
import '../controllers/dashboard_controller.dart';

// الشاشة الرئيسية لعرض الإحصائيات (خاصة بالإدارة فقط)
class DashboardScreen extends GetView<DashboardController> {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // لون خلفية خفيف ومريح
      backgroundColor: Colors.grey[100],

      // ================= AppBar =================
      appBar: AppBar(
        title: const Text(
          'لوحة الإحصائيات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.brown[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [_buildFilterHeader()],
      ),

      // ================= Body =================
      body: Obx(() {
        // لو البيانات بتتحمل
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.brown),
          );
        }

        // لو في Error
        if (controller.hasError.value) {
          return _buildErrorWidget();
        }

        // عرض البيانات
        return RefreshIndicator(
          onRefresh: () async {
            // تحديث كافة البيانات من الكنترولر الموحد عند السحب لأسفل
            await controller.loadAllData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 📊 كارت الأرباح الشامل والمطور والمربوط بالفلتر ديناميكياً
                _buildAdvancedSummaryCard(),

                const SizedBox(height: 20),

                // الشارت
                _buildChartSection(),

                const SizedBox(height: 20),

                // أفضل المنتجات
                _buildTopProductsSection(),
              ],
            ),
          ),
        );
      }),
    );
  }

  // ================= فلتر الشهر والسنة =================
  Widget _buildFilterHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // Dropdown الشهر
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<int>(
              value: controller.selectedMonth.value,
              dropdownColor: Colors.brown[700],
              style: const TextStyle(color: Colors.white),
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              items: List.generate(12, (i) => DropdownMenuItem(
                value: i + 1,
                child: Text(_getMonthName(i + 1)),
              )),
              onChanged: (val) {
                if (val != null) controller.changeMonth(val);
              },
            ),
          ),

          const SizedBox(width: 8),

          // Dropdown السنة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<int>(
              value: controller.selectedYear.value,
              dropdownColor: Colors.brown[700],
              style: const TextStyle(color: Colors.white),
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              items: [2024, 2025, 2026, 2027]
                  .map((y) => DropdownMenuItem(
                value: y,
                child: Text('$y'),
              ))
                  .toList(),
              onChanged: (val) {
                if (val != null) controller.changeYear(val);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'يناير','فبراير','مارس','أبريل','مايو','يونيو',
      'يوليو','أغسطس','سبتمبر','أكتوبر','نوفمبر','ديسمبر'
    ];
    return months[month - 1];
  }

  // ================= Error UI =================
  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            controller.errorMessage.value,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => controller.loadAllData(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  // ================= 🟢 كارت الأرباح الشامل الديناميكي المربوط بالفلتر =================
  Widget _buildAdvancedSummaryCard() {
    return Obx(() {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)], // تدرج أخضر مالي مريح ومتناسق
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withValues(alpha: 0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            const Text(
              'صافي الربح النهائي (بعد الخصومات والمصروفات)',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              '${controller.netProfit.value.toStringAsFixed(2)} ج.م',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),

            // 🎯 التحديث التلقائي لاسم الشهر والسنة داخل الكارت بناءً على القائمة العلوية
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_getMonthName(controller.selectedMonth.value)} ${controller.selectedYear.value}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),

            const SizedBox(height: 20),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 16),

            // تفاصيل نفس الشهر المختار بالكامل من الداتابيز: مبيعات - مشتريات - مصروفات
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildDashboardStatItem("المبيعات", controller.totalSales.value),
                _buildDashboardStatItem("المشتريات", controller.totalPurchases.value),
                _buildDashboardStatItem("المصروفات", controller.totalExpenses.value),
              ],
            )
          ],
        ),
      );
    });
  }

  // ويدجت فرعية لعرض عناصر الإحصائيات الثلاثية تحت كارت الأرباح
  Widget _buildDashboardStatItem(String label, double value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
        const SizedBox(height: 4),
        Text(
          "${value.toStringAsFixed(2)} ج",
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  // ================= الشارت =================
  Widget _buildChartSection() {
    if (controller.dailySales.isEmpty) return const SizedBox();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 أداء المبيعات اليومي',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                maxY: controller.maxDailySales.value,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() % 2 == 0 || value.toInt() == 1) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${value.toInt()}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                barGroups: controller.dailySales.map((e) {
                  return BarChartGroupData(
                    x: e.day,
                    barRods: [
                      BarChartRodData(
                        toY: e.total,
                        color: Colors.brown[400],
                        width: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= أفضل المنتجات =================
  Widget _buildTopProductsSection() {
    if (controller.topProducts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: const Text(
          'لا توجد مبيعات في هذا الشهر',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🏆 أعلى 5 منتجات مبيعاً',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...controller.topProducts.map((product) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              title: Text(product.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
              subtitle: Text('${product.totalQuantity} ${product.unitType}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              trailing: Text('${product.totalAmount} ج.م', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
            );
          }),
        ],
      ),
    );
  }
}