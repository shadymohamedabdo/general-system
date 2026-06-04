import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/shift_report_controller.dart';

class ShiftReportScreen extends GetView<ShiftReportController> {
  final Map<String, dynamic> currentUser;
  const ShiftReportScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    // 🔥 1. تحديد إذا كان المستخدم أدمن أم لا
    bool isAdmin = currentUser['role'] == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E9),
      appBar: AppBar(
        title: const Text('تقرير الوردية المقفل',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: const Color(0xFF3E2723),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            onPressed: () => controller.loadAllShifts(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.shifts.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF3E2723)));
        }

        final successfulOrdersCount = controller.ordersCount.value;

        return Column(
          children: [
            _buildShiftsHeader(),

            // 📊 الكروت العلوية
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCreativeStatCard(
                      "الطلبات الناجحة",
                      "$successfulOrdersCount",
                      const Color(0xFF1565C0),
                      Icons.receipt_long_rounded,
                    ),
                    const SizedBox(width: 12),
                    _buildCreativeStatCard(
                      "إجمالي المبيعات",
                      "${controller.totalSum.value.toStringAsFixed(2)} ج",
                      Colors.green.shade700,
                      Icons.point_of_sale_rounded,
                    ),
                    const SizedBox(width: 12),
                    _buildCreativeStatCard(
                      "المصروفات النقدية",
                      "${controller.totalExpensesSum.value.toStringAsFixed(2)} ج",
                      Colors.orange.shade700,
                      Icons.money_off_rounded,
                    ),
                    const SizedBox(width: 12),
                    _buildCreativeStatCard(
                      "الصافي بالصندوق",
                      "${controller.finalNetCash.value.toStringAsFixed(2)} ج",
                      Colors.blue.shade700,
                      Icons.account_balance_wallet_rounded,
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.assignment_outlined, color: Color(0xFF3E2723), size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    "سجل عمليات الوردية",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),

            // القائمة بالتصميم المطور مع دعم الإلغاء للأدمن 🎯
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => controller.loadReport(reset: true),
                child: controller.reportData.isEmpty && controller.shiftExpenses.isEmpty
                    ? const Center(child: Text("لا توجد عمليات في هذه الوردية", style: TextStyle(fontSize: 16)))
                    : ListView.builder(
                  controller: controller.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: controller.shiftExpenses.length +
                      controller.reportData.length +
                      (controller.isLoadingMore.value ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < controller.shiftExpenses.length) {
                      return _buildExpenseItem(controller.shiftExpenses[index]);
                    }

                    final saleIndex = index - controller.shiftExpenses.length;

                    if (saleIndex == controller.reportData.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: CircularProgressIndicator(color: Color(0xFF3E2723)),
                        ),
                      );
                    }

                    final sale = controller.reportData[saleIndex];
                    // 🔥 تمرير صلاحية الـ isAdmin لكارت البيع
                    return _buildSaleItem(sale, isAdmin);
                  },
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // شريط الورديات
// جوة الـ ShiftReportScreen
  Widget _buildShiftsHeader() {
    return Container(
      height: 82,
      margin: const EdgeInsets.only(top: 8),
      child: Obx(() {
        if (controller.shifts.isEmpty && controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF3E2723)));
        }

        return ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          ),
          child: ListView.builder(
            controller: controller.shiftsScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: controller.shifts.length + (controller.isShiftsLoadingMore.value ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == controller.shifts.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF3E2723)),
                    ),
                  ),
                );
              }

              final s = controller.shifts[index];
              final isSelected = controller.selectedShiftId.value == s['id'];
              return _buildShiftChip(s, isSelected);
            },
          ),
        );
      }),
    );
  }  Widget _buildShiftChip(Map s, bool isSelected) {
    DateTime? dt = s['start_time'] != null ? DateTime.tryParse(s['start_time'].toString())?.toLocal() : null;
    String displayDate = dt != null ? DateFormat('dd/MM').format(dt) : "—";
    bool isMorning = s['type'] == "morning";

    return GestureDetector(
      onTap: () => controller.selectShift(s['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3E2723) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.brown : Colors.grey.shade300),
          boxShadow: isSelected ? [BoxShadow(color: Colors.brown.withValues(alpha: 0.3), blurRadius: 10)] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isMorning ? "☀️ صباحي" : "🌙 مسائي",
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.brown[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                )),
            Text(displayDate, style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildCreativeStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildExpenseItem(Map exp) {
    final amount = (exp['amount'] as num?)?.toDouble() ?? 0.0;
    final notes = exp['notes']?.toString().trim() ?? '';
    final cashierName = (exp['cashier_name'] ?? exp['user_name'] ?? controller.shifts.firstWhere((s) => s['id'] == exp['shift_id'], orElse: () => {})['user_name'] ?? 'سيد').toString().trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              exp['title']?.toString() ?? 'مصروف الخزنة',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person, size: 13, color: Colors.grey.shade600),
                  const SizedBox(width: 3),
                  Text(
                    "الوردية: $cashierName",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: notes.isNotEmpty && notes != 'null'
            ? Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(notes, style: TextStyle(color: Colors.grey[600], fontSize: 12.5)),
        )
            : null,
        trailing: Text(
          "- ${amount.toStringAsFixed(2)} ج",
          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15.5),
        ),
      ),
    );
  }

  // 🔥 تحديث: دعم خاصية الإلغاء والاستعادة بناءً على الـ isAdmin
  Widget _buildSaleItem(Map sale, bool isAdmin) {
    bool isCancelled = sale['status'] == 'cancelled';
    final quantity = (sale['quantity'] as num?)?.toDouble() ?? 0.0;
    final totalAmount = (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
    String unitType = (sale['unit_type'] ?? sale['unit'] ?? sale['unit_name'] ?? '').toString().trim();

    final cashierName = (sale['cashier_name'] ?? sale['user_name'] ?? sale['employee_name'] ?? controller.shifts.firstWhere((s) => s['id'] == sale['shift_id'], orElse: () => {})['user_name'] ?? 'كاشير').toString().trim();

    // 🎯 المنطق الجديد لتحديد الوحدة:
    if (unitType.isEmpty) {
      if (unitType == 'بن') {
        unitType = 'كيلو';
      } else if (unitType == 'مشروب') {
        unitType = 'كوب';
      } else {
        unitType = 'قطعة';
      }
    }
    String formattedQty = quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCancelled ? Colors.red.withValues(alpha: 0.02) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCancelled ? Colors.red.withValues(alpha: 0.1) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale['product_name']?.toString() ?? 'منتج غير محدد',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isCancelled ? Colors.grey : Colors.black,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "$unitType  x$formattedQty".trim(),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 13, color: Colors.grey.shade600),
                          const SizedBox(width: 3),
                          Text(
                            cashierName,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "${totalAmount.toStringAsFixed(1)} ج",
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: isCancelled ? Colors.grey : Colors.black,
                ),
              ),
              const SizedBox(height: 4),

              // ✨ التعديل هنا: شلنا الـ if(isAdmin) وبقى متاح للكل (كاشير أو آدمن)
              InkWell(
                onTap: () => controller.toggleStatus(
                  sale['id'],
                  sale['status'],
                ),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), // تكبير مساحة الضغط شوية لتجربة مستخدم أفضل
                  child: Text(
                    isCancelled ? "إستعادة" : "إلغاء العملية",
                    style: TextStyle(
                      fontSize: 12,
                      color: isCancelled ? Colors.blue.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }}