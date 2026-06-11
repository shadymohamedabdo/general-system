import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_config.dart';
import '../controllers/profit_controller.dart';

class NetProfitScreen extends StatelessWidget {
  const NetProfitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfitController());

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F1),
      appBar: AppBar(
        title: const Text('سجل المصروفات النثرية',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
        backgroundColor: AppConfig.system,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          // 🗓️ قوائم اختيار الأشهر والسنوات ديناميكياً من الـ AppBar ليطابق شكل الشهري تماماً
          Obx(() => Row(
            children: [
              DropdownButton<int>(
                value: controller.selectedMonth.value,
                dropdownColor: AppConfig.system,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                underline: const SizedBox(),
                items: controller.monthsList.map((m) => DropdownMenuItem(value: m, child: Text("شهر $m "))).toList(),
                onChanged: (m) => controller.updateDateFilter(m, null),
              ),
              const SizedBox(width: 4),
              DropdownButton<int>(
                value: controller.selectedYear.value,
                dropdownColor: AppConfig.system,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                underline: const SizedBox(),
                items: controller.yearsList.map((y) => DropdownMenuItem(value: y, child: Text("$y"))).toList(),
                onChanged: (y) => controller.updateDateFilter(null, y),
              ),
              const SizedBox(width: 8),
            ],
          )),
        ],
      ),
      body: Obx(() {
        if (controller.isRefreshing.value && controller.activeShiftExpenses.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1B5E20)),
          );
        }

        return Column(
          children: [
            // كارت إجمالي المصروفات للشهر المحدد
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إجمالي المصروفات المسجلة للفلتر',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${controller.totalExpenses.value.toStringAsFixed(2)} ج.م',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor: Colors.red.shade50,
                    radius: 26,
                    child: const Icon(Icons.trending_up_rounded, color: Colors.redAccent, size: 30),
                  )
                ],
              ),
            ),

            // عنوان سجل المصروفات
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "بيانات المصروفات الخارجة",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  IconButton(
                    icon:  Icon(Icons.add_circle, color: AppConfig.system, size: 32),
                    onPressed: () => _showAddExpenseDialog(context, controller),
                  ),
                ],
              ),
            ),

            // قائمة المصروفات المحدودة بـ 50 عنصر + السحب الذكي للأعلى
            Expanded(
              child: controller.activeShiftExpenses.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 70, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('لا توجد مصروفات مسجلة في هذا الشهر', style: TextStyle(fontSize: 15, color: Colors.grey)),
                  ],
                ),
              )
                  : ListView.builder(
                controller: controller.scrollController, // 🎯 ربط الكونترولر لمراقبة السكرول والـ Pagination
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: controller.activeShiftExpenses.length + (controller.isLoadingMore.value ? 1 : 0),
                itemBuilder: (context, index) {
                  // لو واصل لآخر اللستة وجاري جلب داتا جديدة، اعرض لودر صغير تحت
                  if (index == controller.activeShiftExpenses.length) {
                    return const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF1B5E20))),
                    );
                  }

                  final exp = controller.activeShiftExpenses[index];
                  final amount = (exp['amount'] as num?)?.toDouble() ?? 0.0;

                  final formatted = controller.formatDateTime(exp['created_at']?.toString() ?? '');
                  final parts = formatted.split('|');
                  final timePart = parts.isNotEmpty ? parts[0] : '';
                  final datePart = parts.length > 1 ? parts[1] : '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Colors.red[50],
                        radius: 20,
                        child: const Icon(Icons.money_off_rounded, color: Colors.red, size: 22),
                      ),
                      title: Text(
                        exp['title']?.toString() ?? 'مصروف غير محدد',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                timePart,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                              ),
                              const SizedBox(width: 8),
                              Text(datePart, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "الوردية: ${exp['cashier_name'] ?? 'كاشير الوردية'}",
                            style: TextStyle(fontSize: 12, color: Colors.teal[700], fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '- ${amount.toStringAsFixed(2)} ج',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.blueGrey, size: 18),
                            onPressed: () => _showEditExpenseDialog(context, controller, exp),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                            onPressed: () => _confirmDelete(context, controller, exp['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  // الـ Dialogs تظل كما هي بنفس السرعة وآلية الإغلاق الفوري السريعة دون تغيير
  void _showAddExpenseDialog(BuildContext context, ProfitController controller) {
    final formKey = GlobalKey<FormState>();
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_card_rounded, color: Color(0xFF1B5E20)),
            SizedBox(width: 10),
            Text('تسجيل مصروف جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: controller.titleCtrl,
                decoration: const InputDecoration(labelText: 'بيان الصرف'),
                validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller.amountCtrl,
                decoration: const InputDecoration(labelText: 'المبلغ (ج.م)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v == null || double.tryParse(v) == null || double.parse(v) <= 0 ? 'ادخل مبلغ صحيح' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppConfig.system, foregroundColor: Colors.white),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Get.back();
                await controller.saveManualExpense();
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showEditExpenseDialog(BuildContext context, ProfitController controller, Map<String, dynamic> exp) {
    final titleCtrl = TextEditingController(text: exp['title'].toString());
    final amountCtrl = TextEditingController(text: exp['amount'].toString());
    final formKey = GlobalKey<FormState>();

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تعديل المصروف', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'البيان')),
              const SizedBox(height: 12),
              TextFormField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'المبلغ'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Get.back();
                await controller.updateCustomExpense(exp['id'], titleCtrl.text.trim(), double.parse(amountCtrl.text));
              }
            },
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ProfitController controller, int id) {
    Get.defaultDialog(
      title: "تأكيد الحذف",
      middleText: "هل أنت متأكد من حذف هذا المصروف؟",
      textConfirm: "حذف",
      textCancel: "إلغاء",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () async {
        Get.back();
        await controller.deleteExpense(id);
      },
    );
  }
}