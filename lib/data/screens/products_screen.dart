import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_config.dart';
import '../controllers/products_controller.dart';
import '../models/product_model.dart';

class ProductsScreen extends GetView<ProductsController> {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // ديناميكية بناء الـ Tabs بناء على الأقسام الموجودة في الداتابيز
      List<String> dynamicTabs = ['الكل', ...controller.categoriesList];

      return DefaultTabController(
        length: dynamicTabs.length,
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F5F2),
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => controller.loadProducts(),
                tooltip: 'تحديث الأرصدة',
              ),
            ],
            title: Text("${AppConfig.businessName} - المخزن",
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            centerTitle: true,
            backgroundColor: AppConfig.system,
            foregroundColor: Colors.white,
            elevation: 0,
            bottom: TabBar(
              onTap: (index) {
                // تصفية المنتجات ديناميكياً حسب اسم الـ Tab المضغوط
                controller.updateTabFilter(dynamicTabs[index]);
              },
              isScrollable: true,

              // 🎨 تظبيط ألوان الوقوف والتفاعل بناءً على الهوية الجديدة
              indicatorColor: Colors.orangeAccent, // لون الخط السفلي للـ Tab النشط
              indicatorWeight: 4,

              labelColor: Colors.red, // 👈 لون نص وأيقونة الـ Tab النشط (اللي واقف عليه حالياً)
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),

              unselectedLabelColor: Colors.white.withOpacity(0.65), // 👈 لون نص وأيقونات الـ Tabs غير النشطة (علشان ما تضايقش العين)
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),

              tabs: dynamicTabs.map((tabName) {
                IconData tabIcon = tabName == 'الكل'
                    ? Icons.all_inclusive
                    : (tabName == 'بن' ? Icons.grain : Icons.category);
                return Tab(text: tabName, icon: Icon(tabIcon));
              }).toList(),
            ),
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
          ),
          body: Row(
            children: [
              _buildCreativeSideForm(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCreativeSearchBar(),
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الرفوف الحالية',
                              style: TextStyle(fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4E342E))),
                          Text('${controller.filteredProducts.length} صنف',
                              style: TextStyle(color: AppConfig.primaryColor,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Expanded(child: _buildProductGrid()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildProductGrid() {
    return Obx(() {
      if (controller.filteredProducts.isEmpty) {
        return const Center(child: Text('الرف فارغ حالياً'));
      }
      return GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 300,
          mainAxisExtent: 180,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
        ),
        itemCount: controller.filteredProducts.length,
        itemBuilder: (context, index) =>
            _buildPremiumProductCard(controller.filteredProducts[index]),
      );
    });
  }

  Widget _buildPremiumProductCard(Product p) {
    double remaining = controller.productStock[p.id] ?? 0.0;

    // 🎯 التعديل: المنتج يعتبر نافد فقط لو كميته صفر أو أقل، وبشرط ميكونش رصيد مفتوح (999)
    bool isOutofStock = remaining <= 0 && remaining != 999.0;

    // 💡 النواقص: بتتحسب فقط للمنتجات العادية اللي مش رصيد مفتوح
    bool isLowStock = remaining != 999.0 && (
        (p.category == 'بن' && remaining > 0 && remaining <= 2.0) ||
            (p.category != 'بن' && remaining > 0 && remaining <= 5.0)
    );

    Color cardBgColor = Colors.white;
    if (isOutofStock) {
      cardBgColor = Colors.grey[200]!;
    } else if (isLowStock) {
      cardBgColor = const Color(0xFFFFF3E0);
    }

    String unitLabel = p.unit ?? 'وحدة';
    final style = _getCategoryStyle(p.category);

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(25),
        border: isLowStock ? Border.all(color: Colors.orangeAccent, width: 1.5) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isOutofStock ? 0.02 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10, bottom: -10,
            child: IgnorePointer(
              child: Icon(
                style['icon'],
                size: 80,
                color: style['color'].withOpacity(isOutofStock ? 0.02 : 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBadge(p.category, isOutofStock ? Colors.grey : style['color']),
                    Row(
                      children: [
                        _buildActionBtn(Icons.edit, Colors.blue, () => _showEditDialog(p), !isOutofStock),
                        const SizedBox(width: 8),
                        _buildActionBtn(Icons.delete_forever, Colors.red, () => _confirmDelete(p), true),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  p.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isOutofStock ? Colors.grey[600] : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // 🎯 التعديل: لو الرصيد مش 999 يعرض المتاح بالأرقام، ولو 999 يقلب رصيد مفتوح فوراً
                if (remaining != 999.0) ...[
                  Text(
                    isOutofStock
                        ? 'المتاح: 0 $unitLabel ⚠️'
                        : 'المتاح: ${remaining.toStringAsFixed(p.category == 'بن' ? 2 : 0)} $unitLabel',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isOutofStock
                          ? Colors.red[700]
                          : (isLowStock ? Colors.orange[800] : Colors.blueGrey[700]),
                    ),
                  ),
                ] else ...[
                  Text(
                    'رصيد مفتوح ($unitLabel) ✨',
                    style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w500),
                  ),
                ],
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isOutofStock)
                      Text('نفد من المخزن', style: TextStyle(color: Colors.red[700], fontSize: 12, fontWeight: FontWeight.bold))
                    else if (isLowStock)
                      Text('قارب على الانتهاء! ⏳', style: TextStyle(color: Colors.orange[900], fontSize: 11, fontWeight: FontWeight.bold))
                    else
                      const SizedBox(),

                    Text(
                      '${p.price} ج.م',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: isOutofStock
                            ? Colors.grey[500]
                            : (isLowStock ? Colors.orange[900] : Colors.green[800]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
  Widget _buildActionBtn(IconData icon, Color color, VoidCallback onTap, bool enabled) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: color.withValues(alpha: enabled ? 0.1 : 0.05),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: enabled ? color : color.withValues(alpha: 0.5), size: 20),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _confirmDelete(Product p) {
    Get.defaultDialog(
      title: "حذف!",
      middleText: "حذف ${p.name} من المخزن؟",
      textConfirm: "نعم، حذف",
      textCancel: "تراجع",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () {
        controller.deleteProduct(p.id!);
        Get.back();
      },
    );
  }

  Widget _buildCreativeSideForm() {
    return Container(
      width: 320,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(25)),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إضافة صنف جديد',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const Divider(height: 30),

            const Text('اسم المنتج:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            _buildField(controller.nameCtrl, 'مثال: نسكافيه، كابوتشينو...', Icons.label),

            const SizedBox(height: 15),

            Obx(() {
              if (controller.availableProductNames.isEmpty) return const SizedBox();
              final currentValue = controller.selectedProductName.value;
              final bool hasValidValue = controller.availableProductNames.contains(currentValue);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('أو اختر سريعاً من المشتريات:',
                      style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: (currentValue.isEmpty || !hasValidValue) ? null : currentValue,
                        isExpanded: true,
                        hint: const Text('اضغط للاختيار السريع', style: TextStyle(fontSize: 12)),
                        items: controller.availableProductNames.map((name) {
                          return DropdownMenuItem(
                            value: name,
                            child: Text(name, style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            controller.selectedProductName.value = value;
                            controller.nameCtrl.text = value;
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                ],
              );
            }),

            const Text('سعر البيع لعميل الصالة:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            _buildField(controller.priceCtrl, 'سعر البيع', Icons.payments, isNumber: true),

            const SizedBox(height: 15),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الكمية المتوفرة حالياً:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Obx(() => Text('(${controller.selectedUnit.value ?? ''})',
                    style: TextStyle(color: AppConfig.primaryColor, fontSize: 11, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 8),
            _buildField(controller.stockCtrl, 'مثال: 10 أو 25.5', Icons.inventory_2_rounded, isNumber: true),

            const SizedBox(height: 15),

            // 🆕 إضافة اختيار ديناميكي لوحدة القياس من جداول الوحدات القادمة من الداتابيز
            const Text('وحدة القياس المعتمدة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(15)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: controller.selectedUnit.value,
                  isExpanded: true,
                  items: controller.unitsList.map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
                  onChanged: (val) => controller.selectedUnit.value = val,
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text('التصنيف داخل المنيو:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildCustomSelector(),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: controller.addProduct,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: AppConfig.system,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: const Text('إضافة للمخزن 💾',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCustomSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: controller.categoriesList.map((cat) {
        return Obx(() {
          bool isSelected = controller.selectedCategory.value == cat;
          return GestureDetector(
            onTap: () => controller.changeCategory(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppConfig.system : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? AppConfig.primaryColor : Colors.grey.shade300),
              ),
              child: Text(cat, style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ),
          );
        });
      }).toList(),
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.brown[300]),
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
    );
  }

  Widget _buildCreativeSearchBar() {
    return TextField(
      controller: controller.searchCtrl,
      onChanged: controller.applyFilters,
      decoration: InputDecoration(
          hintText: 'ابحث في الرفوف...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)),
    );
  }

  Map<String, dynamic> _getCategoryStyle(String cat) {
    if (cat == 'بن') return {'icon': Icons.grain, 'color': Colors.brown};
    if (cat == 'مشروب') return {'icon': Icons.local_cafe, 'color': Colors.blue};
    return {'icon': Icons.fastfood, 'color': Colors.orange};
  }

  void _showEditDialog(Product p) {
    final ctrl = TextEditingController(text: p.price.toString());
    Get.defaultDialog(
        title: "تعديل السعر",
        content: Padding(
          padding: const EdgeInsets.all(15.0),
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "السعر الجديد"),
          ),
        ),
        textConfirm: "تحديث",
        onConfirm: () {
          controller.updatePrice(p.id!, double.parse(ctrl.text));
          Get.back();
        });
  }
}