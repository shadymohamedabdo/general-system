import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../constants/app_config.dart';
import '../constants/constants.dart';
import '../controllers/sales_controller.dart';
import '../models/cart_item.dart';

class AddSaleScreen extends GetView<SalesController> {
  final Map<String, dynamic> currentUser;
  const AddSaleScreen({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage(AppConfig.salePageBg),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.6)),
          Positioned(
            top: 50,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Get.back(),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: 600,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Form(
                  key: controller.formKey,
                  child: Obx(() {
                    if (controller.isLoading.value) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.brown),
                      );
                    }
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 16),
                        _buildTableSelector(context), // 🍽️ تحديد الترابيزة
                        const SizedBox(height: 16),
                        _buildCategoryDropdown(),
                        if (controller.selectedCategory.value != null) ...[
                          const SizedBox(height: 16),
                          _buildSearchBar(),
                          const SizedBox(height: 12),
                          _buildProductDropdown(),
                          const SizedBox(height: 16),
                          _buildQuantitySection(),
                          const SizedBox(height: 16),
                          _buildPriceCard(),
                          const SizedBox(height: 16),
                          _buildCartSection(),
                          const SizedBox(height: 20),
                          _buildActionButtons(),
                        ],
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() => Column(
    children: [
      const Icon(Icons.shopping_basket_outlined, size: 48, color: Colors.brown),
      const SizedBox(height: 8),
      const Text('نقطة البيع والترابيزات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      Text('الموظف الحالي: ${currentUser['name']}', style: const TextStyle(color: Colors.grey)),
    ],
  );

  Widget _buildTableSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: controller.currentTableNumber.value == null
            ? Colors.orange.shade50
            : Colors.brown.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: controller.currentTableNumber.value == null
              ? Colors.orange.shade300
              : Colors.brown.shade300,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                controller.currentTableNumber.value == null
                    ? Icons.takeout_dining
                    : Icons.table_restaurant,
                color: controller.currentTableNumber.value == null
                    ? Colors.orange.shade800
                    : Colors.brown.shade800,
              ),
              const SizedBox(width: 8),
              Text(
                controller.currentTableNumber.value == null
                    ? 'الطلب حالياً: تيك أواي / سفري'
                    : 'الطلب لـ: ترابيزة ${controller.currentTableNumber.value}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: controller.currentTableNumber.value == null
                      ? Colors.orange.shade900
                      : Colors.brown.shade900,
                ),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => _showTableSelectionDialog(context),
            icon: const Icon(Icons.grid_view_rounded, size: 18, color: Colors.white),
            label: Text(
              controller.currentTableNumber.value == null ? 'تحديد ترابيزة' : 'تغيير الترابيزة',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown[700],
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  void _showTableSelectionDialog(BuildContext context) {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('اختر الترابيزة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Get.back()),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                leading: const Icon(Icons.takeout_dining, color: Colors.orange),
                title: const Text('تيك أواي / سفري (بدون ترابيزة)', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: controller.currentTableNumber.value == null
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () {
                  controller.selectTable(null);
                  Get.back();
                },
              ),
              const SizedBox(height: 15),
              SizedBox(
                height: 300,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: 30,
                  itemBuilder: (context, index) {
                    final tableNum = index + 1;
                    final isSelected = controller.currentTableNumber.value == tableNum;
                    return InkWell(
                      onTap: () {
                        controller.selectTable(tableNum);
                        Get.back();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.brown : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.brown : Colors.grey.shade400,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.table_restaurant, color: isSelected ? Colors.white : Colors.brown, size: 22),
                              const SizedBox(height: 4),
                              Text('$tableNum', style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Obx(() {
      return DropdownButtonFormField<String>(
        value: controller.selectedCategory.value,
        decoration: InputDecoration(
          labelText: 'نوع الصنف / الفئة',
          prefixIcon: const Icon(Icons.category_outlined, color: Colors.brown),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        ),
        items: controller.categories.map((category) {
          return DropdownMenuItem<String>(
            value: category,
            child: Text(category),
          );
        }).toList(),
        onChanged: (val) => controller.onCategoryChanged(val),
      );
    });
  }

  Widget _buildSearchBar() => TextFormField(
    decoration: InputDecoration(
      hintText: '🔍 ابحث عن منتج هنا...',
      prefixIcon: const Icon(Icons.search, color: Colors.brown),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(25),
        borderSide: BorderSide(color: Colors.brown.shade200),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ),
    onChanged: (value) => controller.searchQuery.value = value,
  );

  Widget _buildProductDropdown() {
    if (controller.availableProducts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Text('لا توجد منتجات متوفرة أو مطابقة للبحث', style: TextStyle(color: Colors.red)),
        ),
      );
    }

    final currentValue = controller.selectedProductId.value;
    final hasValidValue = controller.availableProducts.any((p) => p.id == currentValue);

    return DropdownButtonFormField<int>(
      value: hasValidValue ? currentValue : null,
      decoration: InputDecoration(
        labelText: 'المنتج المتاح',
        prefixIcon: const Icon(Icons.inventory_2_outlined, color: Colors.brown),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      ),
      items: controller.availableProducts.map((p) {
        double? remaining = controller.productRemainingMap[p.id];

        String stockText = (remaining == null)
            ? 'رصيد مفتوح'
            : (remaining <= 0 ? 'نفد من المخزن' : '${remaining.toStringAsFixed(0)} متاح');

        Color textColor = (remaining != null && remaining <= 0) ? Colors.red : Colors.blueGrey;

        return DropdownMenuItem<int>(
          value: p.id,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(p.name),
              Text(stockText, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) => controller.updateProduct(v),
    );
  }
  Widget _buildQuantitySection() {
    final isCoffee = controller.selectedCategory.value == 'بن';
    if (isCoffee) {
      return Column(
        children: [
          DropdownButtonFormField<double>(
            initialValue: [0.125, 0.25, 0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0].contains(controller.quantity.value)
                ? controller.quantity.value
                : null,
            decoration: const InputDecoration(labelText: 'أوزان جاهزة', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: 0.125, child: Text('ثمن كيلو')),
              const DropdownMenuItem(value: 0.25, child: Text('ربع كيلو')),
              const DropdownMenuItem(value: 0.5, child: Text('نصف كيلو')),
              ...List.generate(10, (index) {
                final kiloValue = index + 1;
                return DropdownMenuItem(
                  value: kiloValue.toDouble(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('كيلو'),
                      const SizedBox(width: 6),
                      Text('$kiloValue'),
                    ],
                  ),
                );
              }),
            ],
            onChanged: (v) {
              if (v != null) {
                controller.quantity.value = v;
                controller.amount.value = null;
                controller.amountCtrl.clear();
              }
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller.amountCtrl,
            decoration: const InputDecoration(labelText: 'أو ادخل مبلغ محدد (ج.م)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            onChanged: controller.updateAmountAndWeight,
          ),
          Obx(() => controller.computedWeight.value > 0
              ? Text('الوزن المحسوب: ${controller.computedWeight.value.toStringAsFixed(3)} كجم', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
              : const SizedBox()),
        ],
      );
    }
    return TextFormField(
      controller: controller.qtyCtrl,
      decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()),
      keyboardType: TextInputType.number,
      onChanged: (v) => controller.quantity.value = double.tryParse(v) ?? 1.0,
    );
  }

  Widget _buildPriceCard() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.green[700], borderRadius: BorderRadius.circular(15)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('إجمالي الصنف الحالي:', style: TextStyle(color: Colors.white, fontSize: 16)),
        Obx(() => Text('${controller.currentTotal.toStringAsFixed(2)} ج.م', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
      ],
    ),
  );

  Widget _buildCartSection() {
    return Obx(() {
      final tableNum = controller.currentTableNumber.value;
      final savedOrders = controller.currentTableOrders;
      final cartItems = controller.cartItems;

      if (cartItems.isEmpty && savedOrders.isEmpty) return const SizedBox.shrink();

      double savedTotal = savedOrders.fold(0.0, (sum, item) => sum + ((item['total_price'] ?? 0) as num).toDouble());
      double totalAll = controller.orderTotal + savedTotal;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الطلبات المحفوظة سابقاً
            if (tableNum != null && savedOrders.isNotEmpty) ...[
              Text('📌 الأصناف المسجلة على ترابيزة ($tableNum):', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
              const SizedBox(height: 6),
              ...savedOrders.map((order) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(order['product_name'] ?? ''),
                subtitle: Text('${order['quantity']} × ${order['unit_price']} ج.م'),
                trailing: Text('${order['total_price']} ج.م', style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
              const Divider(),
            ],

            // الأصناف الجديدة
            if (cartItems.isNotEmpty) ...[
              const Text('📋 أصناف جديدة قيد الإضافة:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 6),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.productName),
                    subtitle: Text('${item.quantity.toStringAsFixed(2)} × ${item.unitPrice.toStringAsFixed(2)} ج.م'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${item.total.toStringAsFixed(2)} ج.م'),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () => controller.removeCartItem(index),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Divider(),
            ],

            // السعر النهائي والمجموع
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('السعر النهائي للترابيزة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${totalAll.toStringAsFixed(2)} ج.م', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildActionButtons() {
    final tableNum = controller.currentTableNumber.value;
    final hasSavedOrders = controller.currentTableOrders.isNotEmpty;

    return Column(
      children: [
        Row(
          children: [
            Obx(() => Badge(
              label: Text('${controller.cartItems.length}'),
              isLabelVisible: controller.cartItems.isNotEmpty,
              child: IconButton(
                icon: const Icon(Icons.add_shopping_cart, color: Colors.brown, size: 32),
                onPressed: controller.addToCart,
                tooltip: 'إضافة الصنف الحالي للطلب',
              ),
            )),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: controller.isSaving.value
                    ? null
                    : () async {
                  if (controller.cartItems.isEmpty && controller.selectedProductId.value != null) {
                    controller.addToCart();
                  }
                  await controller.saveCartOrAddToTable(currentUser['id']);
                },
                icon: const Icon(Icons.save, color: Colors.white),
                label: Text(
                  tableNum == null ? 'حفظ الطلب 💾' : 'حفظ للترابيزة 🍽️',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[700]),
              ),
            ),
            const SizedBox(width: 8),
            // زر المطبخ
            if (tableNum != null) ...[
              IconButton(
                icon: const Icon(Icons.soup_kitchen, color: Colors.orange, size: 30),
                tooltip: 'إرسال للمطبخ',
                onPressed: () async {
                  await controller.dbHelper.markOrdersAsSentToKitchen(tableNum);
                  AppSnackbar.success("تم إرسال الطلبات للمطبخ 👨‍🍳");
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // 🔥 زر تقفيل الحساب + الطباعة السريعة المباشرة
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: controller.isSaving.value
                ? null
                : () async {
              // 1. تجميع المنتجات للطباعة
              List<CartItem> allItemsToPrint = List.from(controller.cartItems);

              // سحب أيمات الترابيزة القديمة وتحويلها لـ CartItem
              for (var o in controller.currentTableOrders) {
                allItemsToPrint.add(CartItem(
                  productId: o['product_id'] ?? 0,
                  productName: o['product_name'] ?? '',
                  category: o['category'] ?? 'عام',
                  unitPrice: ((o['unit_price'] ?? 0) as num).toDouble(),
                  quantity: ((o['quantity'] ?? 1) as num).toDouble(),
                  total: ((o['total_price'] ?? 0) as num).toDouble(),
                ));
              }

              if (allItemsToPrint.isEmpty && controller.selectedProductId.value != null) {
                controller.addToCart();
                allItemsToPrint = List.from(controller.cartItems);
              }

              if (allItemsToPrint.isNotEmpty) {
                double totalAmount = allItemsToPrint.fold(0.0, (sum, item) => sum + item.total);

                // حفظ أي منتجات جديدة أضيفت
                if (controller.cartItems.isNotEmpty) {
                  await controller.saveCartOrAddToTable(currentUser['id']);
                }

                // 2. طباعة الفاتورة النهائية للعميل
                await _printInvoice(allItemsToPrint, totalAmount);

                // 3. تقفيل الحساب وتفريغ الترابيزة
                if (tableNum != null) {
                  await controller.checkoutAndGetTableOrders(tableNum, currentUser['id']);                } else {
                  controller.cartItems.clear();
                }
              } else {
                AppSnackbar.warning("لا توجد أصناف لتقفيل الحساب والطباعة");
              }
            },
            icon: const Icon(Icons.print_rounded, color: Colors.white, size: 24),
            label: Text(
              tableNum != null ? 'تفعيل السعر النهائي وتقفيل الحساب + طباعة 🖨️' : 'تفعيل السعر النهائي وطباعة 🖨️',
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade800),
          ),
        ),
      ],
    );
  }

  Future<void> _printInvoice(List<CartItem> items, double total) async {
    final pdf = pw.Document();

    final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
    final arabicFont = pw.Font.ttf(fontData);

    final now = DateTime.now().toLocal();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm').format(now);

    const customRoll80 = PdfPageFormat(
      72 * PdfPageFormat.mm,
      double.infinity,
      marginTop: 0,
      marginBottom: 0,
      marginLeft: 0,
      marginRight: 0,
    );

    final tableHeader = controller.currentTableNumber.value != null
        ? 'طلب ترابيزة: ${controller.currentTableNumber.value}'
        : 'فاتورة مبيعات (سفري)';

    pdf.addPage(
      pw.Page(
        pageFormat: customRoll80,
        build: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6 * PdfPageFormat.mm, vertical: 2 * PdfPageFormat.mm),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'محل بن الشيخ الاصلي المحطه',
                    style: pw.TextStyle(font: arabicFont, fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    tableHeader,
                    style: pw.TextStyle(font: arabicFont, fontSize: 13, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text('التاريخ: $dateStr', style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                pw.Text('الوقت: $timeStr', style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                pw.Text('الكاشير: ${currentUser['name']}', style: pw.TextStyle(font: arabicFont, fontSize: 10)),
                pw.Divider(thickness: 1),
                ...items.map((item) {
                  final description = _formatItemDescription(item);
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3),
                    child: pw.Text(
                      description,
                      style: pw.TextStyle(font: arabicFont, fontSize: 10, fontWeight: pw.FontWeight.bold),
                    ),
                  );
                }),
                pw.Divider(thickness: 1),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('السعر النهائي والإجمالي:', style: pw.TextStyle(font: arabicFont, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Text('${total.toStringAsFixed(0)} ج.م', style: pw.TextStyle(font: arabicFont, fontWeight: pw.FontWeight.bold, fontSize: 14)),
                  ],
                ),
                pw.SizedBox(height: 15),
                pw.Center(
                  child: pw.Text('شكراً لزيارتكم', style: pw.TextStyle(font: arabicFont, fontSize: 11)),
                ),
                pw.SizedBox(height: 25 * PdfPageFormat.mm),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'receipt_${DateTime.now().millisecondsSinceEpoch}',
        format: customRoll80,
      );
      AppSnackbar.success("تمت الطباعة وتقفيل الحساب بنجاح");
    } catch (e) {
      AppSnackbar.error("تأكد من توصيل الطابعة الحرارية وتعيينها كافتراضية");
    }
  }

  String _formatItemDescription(CartItem item) {
    final name = item.productName.replaceAll('بن', '').trim();
    final qty = item.quantity;
    final totalStr = item.total.toStringAsFixed(0);

    if (item.category == 'بن') {
      if ((qty - 0.125).abs() < 0.005) return "ثمن $name = $totalStr ج";
      if ((qty - 0.25).abs() < 0.005) return "ربع $name = $totalStr ج";
      if ((qty - 0.5).abs() < 0.005) return "نصف $name = $totalStr ج";
      if ((qty - 1.0).abs() < 0.005) return "كيلو $name = $totalStr ج";

      if (qty > 1.0) {
        if (qty % 1 == 0) {
          return "${qty.toInt()} كيلو $name = $totalStr ج";
        }

        double fraction = qty - qty.floor();
        if ((fraction - 0.5).abs() < 0.005) {
          return "${qty.floor()} كيلو ونصف $name = $totalStr ج";
        }
        if ((fraction - 0.25).abs() < 0.005) {
          return "${qty.floor()} كيلو وربع $name = $totalStr ج";
        }
      }

      return "بـ $totalStr ج $name";
    } else {
      final unit = item.category == 'مشروب' ? 'كوب' : 'قطعة';
      final qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
      return "$qtyStr $unit $name = $totalStr ج";
    }
  }
}