import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/constants.dart';
import '../controllers/monthly_report_controller.dart';

/// الشاشة الرئيسية لعرض التقرير الشهري المتقدم وإدارة المشتريات والمصروفات
class MonthlyReportScreen extends GetView<MonthlyReportController> {
  const MonthlyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 🔥 تعريف الـ ScrollController هنا وربطه بالشاشة الأساسية هو الحل الوحيد للـ Pagination في الموبايل والـ Desktop معاً
    final ScrollController mainScrollController = ScrollController();

    mainScrollController.addListener(() {
      if (mainScrollController.position.pixels >=
          mainScrollController.position.maxScrollExtent - 200) {
        controller.loadNextPage(); // استدعاء الصفحة التالية عند الاقتراب من النهاية
      }
    });

    return Scaffold(
      backgroundColor: Colors.brown[50],
      appBar: AppBar(
        title: const Text('التقرير الشهري المتقدم'),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart),
            onPressed: () => controller.showAddPurchaseForm.value = !controller.showAddPurchaseForm.value,
          ),
          _buildFilterHeader(),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) return const Center(child: CircularProgressIndicator(color: Colors.brown));
        if (controller.errorMessage.isNotEmpty) return _buildError();

        return SingleChildScrollView(
          controller: mainScrollController, // ✨ الربط السليم هنا يمنع الـ Infinite Loop والتعليق
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildMonthHeader(),
              const SizedBox(height: 16),
              if (controller.showAddPurchaseForm.value)
                _buildAddPurchaseForm(),
              const SizedBox(height: 16),
              const _PaginatedTable(), // عرض الجدول (تم تنظيفه وتبسيطه)
              const SizedBox(height: 16),
              _buildProfitCard(), // الكارد المنفصل تماماً
            ],
          ),
        );
      }),
    );
  }

  Widget _buildFilterHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
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
              items: [2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(
                value: y,
                child: Text('$y'),
              )).toList(),
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
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return months[month - 1];
  }

  Widget _buildMonthHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_month, color: Colors.brown),
          const SizedBox(width: 8),
          Obx(() => Text(
            "تقرير شهر ${_getMonthName(controller.selectedMonth.value)} ${controller.selectedYear.value}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          )),
        ],
      ),
    );
  }

  Widget _buildAddPurchaseForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.brown[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFormHeader(),
              const SizedBox(height: 20),
              _buildInputField(
                controller: controller.productNameCtrl,
                label: 'اسم المنتج المشتري / المصروف',
                icon: Icons.inventory,
                hint: 'مثال:  بن يمني',
              ),
              const SizedBox(height: 12),
              _buildCategoryDropdown(),
              const SizedBox(height: 12),

              // 1. حقل إدخال الكمية
              _buildInputField(
                controller: controller.quantityCtrl,
                label: 'الكمية',
                icon: Icons.numbers,
                hint: 'مثال: 10',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              _buildUnitDisplay(),
              const SizedBox(height: 12),

              // 2. 🔥 الحقل الجديد: سعر الكيلو أو سعر الوحدة الواحدة
              _buildInputField(
                controller: controller.costPerUnitCtrl, // الكنترولر الجديد
                label: 'سعر الكيلو / الوحدة (ج.م)',
                icon: Icons.price_change_outlined,
                hint: 'مثال: 50',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),

              // 3. ✨ حقل التكلفة الإجمالية: أصبح للقراءة فقط ويحسب تلقائياً
              _buildInputField(
                controller: controller.totalCostCtrl, // الكنترولر الإجمالي الاوتوماتيكي
                label: 'التكلفة الإجمالية التلقائية (ج.م)',
                icon: Icons.attach_money,
                hint: 'ستحسب تلقائياً...',
                readOnly: true, // 🔒 قفل الحقل لمنع تعديله يدوياً بالاخطاء
                fillColor: Colors.grey[100], // تمييزه بصرياً للمستخدم
              ),
              const SizedBox(height: 24),
              _buildFormButtons(),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildFormHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.brown[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shopping_cart, color: Colors.brown),
        ),
        const SizedBox(width: 12),
        const Text(
          'إضافة مشتريات ومصروفات الشهر',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Obx(() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('الفئة', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: controller.selectedCategory.value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              items: controller.categories.map((cat) {
                IconData icon;
                if (cat == 'بن') {
                  icon = Icons.grain;
                } else if (cat == 'مشروب') {
                  icon = Icons.local_cafe;
                } else {
                  icon = Icons.fastfood;
                }
                return DropdownMenuItem(
                  value: cat,
                  child: Row(
                    children: [
                      Icon(icon, size: 18, color: Colors.brown),
                      const SizedBox(width: 8),
                      Text(cat),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) controller.selectedCategory.value = value;
              },
            ),
          ),
        ),
      ],
    ));
  }

  Widget _buildUnitDisplay() {
    return Obx(() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.brown[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.scale, size: 18, color: Colors.brown),
          const SizedBox(width: 8),
          const Text('الوحدة:'),
          const SizedBox(width: 8),
          Text(
            controller.selectedUnit.value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ));
  }

  Widget _buildFormButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: controller.addPurchase,
            icon: const Icon(Icons.save),
            label: const Text('حفظ في التقرير'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => controller.showAddPurchaseForm.value = false,
            icon: const Icon(Icons.cancel),
            label: const Text('إلغاء'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String hint = '',
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false, // القيمة الافتراضية قابلة للكتابة
    Color? fillColor,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly, // تفعيل خاصية القراءة فقط
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.brown),
        filled: fillColor != null,
        fillColor: fillColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.brown[400]!),
        ),
      ),
    );
  }

  // 🔥 تعديل الكارد ليفصل المشتريات لوحدها والمصروفات لوحدها زي ما كانت بالظبط
  Widget _buildProfitCard() {
    final isProfit = controller.netProfit.value >= 0;
    return Card(
      color: isProfit ? Colors.green[700] : Colors.red[700],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isProfit ? Icons.trending_up : Icons.trending_down, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  isProfit ? 'صافي الربح الحقيقي' : 'صافي الخسارة الحقيقية',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${controller.netProfit.value.abs().toStringAsFixed(2)} ج.م',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const Divider(color: Colors.white54),

            // سطر المبيعات والمشتريات
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('إجمالي المبيعات: ${controller.totalSales.value.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(color: Colors.white70)),
                Text('إجمالي المشتريات: ${controller.totalPurchaseCost.value.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 6),

            // 🔥 إضافة سطر مستقل لعرض إجمالي المصروفات اليدوية لوحدها لضبط الدنيا بالكامل
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Obx(() => Text(
                  'إجمالي المصروفات الأخرى: ${controller.totalExpenses.value.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(color: Colors.white70),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 60, color: Colors.red),
        Text(controller.errorMessage.value, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: controller.loadReport,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
          child: const Text("إعادة المحاولة"),
        ),
      ],
    ),
  );
}

// ✅ إرجاع الـ Widget إلى Stateless وتطهيره من الـ ScrollController الداخلي المسبب للتعليق
class _PaginatedTable extends StatelessWidget {
  const _PaginatedTable();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MonthlyReportController>();
    return Obx(() {
      if (controller.tableData.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Center(
            child: Text('لا توجد بيانات للعرض في هذا الشهر', style: TextStyle(color: Colors.grey)),
          ),
        );
      }

      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return _buildMobileTable(controller);
            }
            return _buildDesktopTable(controller);
          },
        ),
      );
    });
  }

  Widget _buildDesktopTable(MonthlyReportController controller) {
    final List<DataRow> rows = controller.tableData.asMap().entries.map((entry) {
      final index = entry.key;
      final row = entry.value;
      final profit = (row['sales_amount'] as num) - (row['purchase_cost'] as num);
      return DataRow(
        color: WidgetStateProperty.resolveWith((states) => index.isEven ? Colors.grey[50] : Colors.white),
        cells: [
          DataCell(Text(row['product_name'] ?? '')),
          DataCell(Text('${row['sold_quantity']} ${row['unit'] ?? ''}')),
          DataCell(Text('${(row['sales_amount'] as num).toStringAsFixed(2)} ج.م')),
          DataCell(Text('${row['purchased_quantity']} ${row['unit'] ?? ''}')),
          DataCell(Text('${(row['purchase_cost'] as num).toStringAsFixed(2)} ج.م')),
          DataCell(
            Text(
              '${profit.toStringAsFixed(2)} ج.م',
              style: TextStyle(color: profit >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
          DataCell(
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 18),
              onPressed: () => _showDeleteDialog(controller, row['product_name']),
            ),
          ),
        ],
      );
    }).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        children: [
          DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.brown[400]),
            columnSpacing: 25,
            columns: const [
              DataColumn(label: Text('الصنف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('المبيعات (كمية)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('إيراد البيع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('المشتريات/المصروف', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('التكلفة المدفوعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('الربح/الخسارة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('', style: TextStyle(color: Colors.white))),
            ],
            rows: rows,
          ),
          // الـ Loading الأسفل للـ Desktop يشتغل بناء على الكنترولر الأساسي
          if (controller.isLoadingMore.value)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(color: Colors.brown),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileTable(MonthlyReportController controller) {
    final dataLength = controller.tableData.length;
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // ✨ يعتمد كلياً على سكرول الشاشة الأب لمنع التعليق واللوب
          itemCount: dataLength,
          itemBuilder: (context, index) {
            final row = controller.tableData[index];
            final profit = (row['sales_amount'] as num) - (row['purchase_cost'] as num);
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              color: Colors.white,
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(row['product_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.brown)),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                          onPressed: () => _showDeleteDialog(controller, row['product_name']),
                        ),
                      ],
                    ),
                    const Divider(height: 10),
                    _buildMobileRow('إجمالي المبيعات:', '${row['sold_quantity']} ${row['unit'] ?? ''}', '${(row['sales_amount'] as num).toStringAsFixed(2)} ج.م'),
                    _buildMobileRow('إجمالي المشتريات/المصروف:', '${row['purchased_quantity']} ${row['unit'] ?? ''}', '${(row['purchase_cost'] as num).toStringAsFixed(2)} ج.م'),
                    const Divider(height: 10),
                    _buildMobileRow('الربح/الخسارة للصنف:', '', '${profit.toStringAsFixed(2)} ج.م', isProfit: profit >= 0),
                  ],
                ),
              ),
            );
          },
        ),
        // 🔥 مؤشر اللودنج للموبايل يظهر هنا بالأسفل بشكل طبيعي جداً ويفصل فور انتهاء الصفحات الحقيقية
        if (controller.isLoadingMore.value)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(color: Colors.brown)),
          ),
      ],
    );
  }

  Widget _buildMobileRow(String label, String quantity, String amount, {bool isProfit = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          if (quantity.isNotEmpty) Text(quantity, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(amount, style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isProfit ? Colors.green : null,
          )),
        ],
      ),
    );
  }

  void _showDeleteDialog(MonthlyReportController controller, String productName) {
    final purchase = controller.purchases.firstWhereOrNull((p) => p.productName == productName);
    if (purchase == null || purchase.id == null) {
      AppSnackbar.error("الصنف غير موجود بالمشتريات المباشرة");
      return;
    }
    Get.dialog(
      AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف مصروفات "$productName"؟'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              controller.deletePurchase(purchase.id!, productName);
              Get.back();
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }
}