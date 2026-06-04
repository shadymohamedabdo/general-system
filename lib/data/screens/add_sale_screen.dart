import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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
          Container(decoration: const BoxDecoration(image: DecorationImage(image: AssetImage(coffeeSalePage), fit: BoxFit.cover))),
          Container(color: Colors.black.withValues(alpha: 0.6)),
          Positioned(top: 50, left: 16, child: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Get.back())),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: 550,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(30)),
                child: Form(
                  key: controller.formKey,
                  child: Obx(() {
                    if (controller.isLoading.value) return const Center(child: CircularProgressIndicator(color: Colors.brown));
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
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

  Widget _buildHeader() => Column(children: [
    const Icon(Icons.shopping_basket_outlined, size: 50, color: Colors.brown),
    const SizedBox(height: 10),
    const Text('إضافة مبيعات', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    Text('الموظف الحالي: ${currentUser['name']}', style: const TextStyle(color: Colors.grey)),
  ]);

  Widget _buildCategoryDropdown() => DropdownButtonFormField<String>(
    initialValue: controller.selectedCategory.value,
    decoration: InputDecoration(labelText: 'نوع الصنف', prefixIcon: const Icon(Icons.category_outlined, color: Colors.brown), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), filled: true, fillColor: Colors.brown[50]?.withValues(alpha: 0.3)),
    items: const [DropdownMenuItem(value: 'بن', child: Text('☕ بن (وزن)')), DropdownMenuItem(value: 'مشروب', child: Text('🍹 مشروب (كوب)')), DropdownMenuItem(value: 'أكل سريع / أخرى', child: Text('🍔 بيت الاعشاب  '))],
    onChanged: controller.onCategoryChanged,
  );

  Widget _buildSearchBar() => TextFormField(
    decoration: InputDecoration(hintText: '🔍 ابحث عن منتج هنا...', prefixIcon: const Icon(Icons.search, color: Colors.brown), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide(color: Colors.brown.shade200)), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
    onChanged: (value) => controller.searchQuery.value = value,
  );

  Widget _buildProductDropdown() {
    if (controller.availableProducts.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('لا توجد منتجات متوفرة أو مطابقة للبحث', style: TextStyle(color: Colors.red)),
      ));
    }

    final currentValue = controller.selectedProductId.value;
    final hasValidValue = controller.availableProducts.any((p) => p.id == currentValue);

    return DropdownButtonFormField<int>(
      initialValue: hasValidValue ? currentValue : null,
      decoration: InputDecoration(labelText: 'المنتج المتاح', prefixIcon: const Icon(Icons.inventory_2_outlined, color: Colors.brown), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
      items: controller.availableProducts.map((p) {
        double remaining = controller.productRemainingMap[p.id] ?? 0;
        return DropdownMenuItem<int>(
            value: p.id,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(p.name),
                  Text('${remaining.toStringAsFixed(2)} متاح', style: const TextStyle(fontSize: 12, color: Colors.blueGrey))
                ]
            )
        );
      }).toList(),
      onChanged: (v) => controller.updateProduct(v),
    );
  }

  Widget _buildQuantitySection() {
    final isCoffee = controller.selectedCategory.value == 'بن';
    if (isCoffee) {
      return Column(children: [
        DropdownButtonFormField<double>(
          initialValue: [0.125, 0.25, 0.5, 1.0].contains(controller.quantity.value) ? controller.quantity.value : null,
          decoration: const InputDecoration(labelText: 'أوزان جاهزة', border: OutlineInputBorder()),
          items: const [DropdownMenuItem(value: 0.125, child: Text('ثمن كيلو')), DropdownMenuItem(value: 0.25, child: Text('ربع كيلو')), DropdownMenuItem(value: 0.5, child: Text('نصف كيلو')), DropdownMenuItem(value: 1.0, child: Text('كيلو'))],
          onChanged: (v) { if (v != null) { controller.quantity.value = v; controller.amount.value = null; controller.amountCtrl.clear(); } },
        ),
        const SizedBox(height: 12),
        TextFormField(controller: controller.amountCtrl, decoration: const InputDecoration(labelText: 'أو ادخل مبلغ محدد (ج.م)', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: controller.updateAmountAndWeight),
        Obx(() => controller.computedWeight.value > 0 ? Text('الوزن المحسوب: ${controller.computedWeight.value.toStringAsFixed(3)} كجم', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)) : const SizedBox()),
      ]);
    }
    return TextFormField(controller: controller.qtyCtrl, decoration: const InputDecoration(labelText: 'الكمية', border: OutlineInputBorder()), keyboardType: TextInputType.number, onChanged: (v) => controller.quantity.value = double.tryParse(v) ?? 1.0);
  }

  Widget _buildPriceCard() => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.green[700], borderRadius: BorderRadius.circular(15)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('إجمالي الصنف الحالي:', style: TextStyle(color: Colors.white, fontSize: 16)), Obx(() => Text('${controller.currentTotal.toStringAsFixed(2)} ج.م', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)))]));

  Widget _buildCartSection() {
    return Obx(() {
      if (controller.cartItems.isEmpty) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[300]!)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('📋 الأوردر الحالي (عدة منتجات):', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: controller.cartItems.length, itemBuilder: (context, index) {
            final item = controller.cartItems[index];
            return ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(item.productName), subtitle: Text('${item.quantity.toStringAsFixed(2)} × ${item.unitPrice.toStringAsFixed(2)} ج.م'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text('${item.total.toStringAsFixed(2)} ج.م'), IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => controller.removeCartItem(index))]));
          }),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold)), Text('${controller.orderTotal.toStringAsFixed(2)} ج.م', style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold))]),
        ]),
      );
    });
  }

  Widget _buildActionButtons() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Obx(() => Badge(
          label: Text('${controller.cartItems.length}'),
          isLabelVisible: controller.cartItems.isNotEmpty,
          child: IconButton(
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.brown, size: 32),
            onPressed: controller.addToCart,
            tooltip: 'إضافة المنتج الحالي للسلة',
          ),
        )),
        const SizedBox(width: 8),
        const Spacer(),
        Expanded(
          child: ElevatedButton(
            onPressed: controller.isSaving.value ? null : () async {
              if (controller.cartItems.isNotEmpty) {
                await controller.saveCart(currentUser['id']);
              } else {
                await controller.saveSingleProduct(currentUser['id']);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[700]),
            child: const Text('حفظ الفاتورة 💾', style: TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: controller.isSaving.value ? null : () async {
              List<CartItem> itemsToPrint = [];
              double totalToPrint = 0;
              bool success = false;
              if (controller.cartItems.isNotEmpty) {
                itemsToPrint = List.from(controller.cartItems);
                totalToPrint = controller.orderTotal;
                success = await controller.saveCart(currentUser['id']);
              } else {
                if (controller.selectedProductId.value != null) {
                  final product = controller.products.firstWhere((p) => p.id == controller.selectedProductId.value);
                  itemsToPrint = [CartItem(
                    productId: product.id!,
                    productName: product.name,
                    quantity: controller.quantity.value,
                    unitPrice: controller.unitPrice.value,
                    total: controller.currentTotal,
                    category: product.category,
                  )];
                  totalToPrint = controller.currentTotal;
                  success = await controller.saveSingleProduct(currentUser['id']);
                } else {
                  // 🔥 استخدام الـ Snackbar التحذيري الخاص بك هنا
                  AppSnackbar.warning("لا توجد فاتورة للطباعة");
                  return;
                }
              }
              if (success) {
                await _printInvoice(itemsToPrint, totalToPrint);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[700]),
            child: const Text('حفظ وطباعة 🖨️', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }


  Future<void> _printInvoice(List<CartItem> items, double total) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final now = DateTime.now().toLocal();

    final dateStr = DateFormat('yyyy-MM-dd').format(now);
    final timeStr = DateFormat('HH:mm').format(now);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'محل بن الشيخ',
                  style: pw.TextStyle(font: arabicFont, fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  'فاتورة مبيعات',
                  style: pw.TextStyle(font: arabicFont, fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Text('التاريخ: $dateStr', style: pw.TextStyle(font: arabicFont, fontSize: 10)),
              pw.Text('الوقت: $timeStr', style: pw.TextStyle(font: arabicFont, fontSize: 10)),
              pw.Text('الكاشير: ${currentUser['name']}', style: pw.TextStyle(font: arabicFont, fontSize: 10)),
              pw.Divider(thickness: 1),

              // المنتجات
              ...items.map((item) {
                final description = _formatItemDescription(item);
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Text(
                    description,
                    style: pw.TextStyle(font: arabicFont, fontSize: 11, fontWeight: pw.FontWeight.bold),
                  ),
                );
              }),

              pw.Divider(thickness: 1),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('الإجمالي:', style: pw.TextStyle(font: arabicFont, fontWeight: pw.FontWeight.bold, fontSize: 13)),
                  pw.Text('${total.toStringAsFixed(0)} ج.م',
                      style: pw.TextStyle(font: arabicFont, fontWeight: pw.FontWeight.bold, fontSize: 14)),
                ],
              ),

              pw.SizedBox(height: 15),
              pw.Center(
                child: pw.Text('شكراً لزيارتكم', style: pw.TextStyle(font: arabicFont, fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'receipt_${DateTime.now().millisecondsSinceEpoch}',
        format: PdfPageFormat.roll80,
      );
      AppSnackbar.success("تم طباعة الفاتورة بنجاح");
    } catch (e) {
      AppSnackbar.error("تأكد من توصيل الطابعة الحرارية وتعيينها كافتراضية");
    }
  }

// دالة التنسيق الذكية (محافظ عليها)
  String _formatItemDescription(CartItem item) {
    final name = item.productName.replaceAll('بن', '').trim();
    final qty = item.quantity;
    final totalStr = item.total.toStringAsFixed(0);

    if (item.category == 'بن') {
      if ((qty - 0.125).abs() < 0.01) return "ثمن $name = $totalStr ج";
      if ((qty - 0.25).abs() < 0.01) return "ربع $name = $totalStr ج";
      if ((qty - 0.5).abs() < 0.01) return "نصف $name = $totalStr ج";
      if ((qty - 1.0).abs() < 0.01) return "كيلو $name = $totalStr ج";
      return "بـ $totalStr ج $name";
    } else {
      final unit = item.category == 'مشروب' ? 'كوب' : 'قطعة';
      final qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1);
      return "$qtyStr $unit $name = $totalStr ج";
    }
  }
}