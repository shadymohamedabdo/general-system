import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/products_controller.dart';
import '../models/product_model.dart';

/// شاشة إدارة المنتجات والمخزن (مخزن بيت البن)
class ProductsScreen extends GetView<ProductsController> {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F5F2), // خلفية الشاشة بدرجة البيج الهادئة
        appBar: AppBar(
          actions: [
            // زر تحديث الأرصدة وإعادة تحميل المنتجات من قاعدة البيانات
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => controller.loadProducts(),
              tooltip: 'تحديث الأرصدة',
            ),
          ],
          title: const Text('مخزن بيت البن',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
          centerTitle: true,
          backgroundColor: Colors.brown[700], // تلوين شريط التطبيق بالبني الغامق
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            onTap: (index) {
              // فلترة المنتجات في الكنترولر بناءً على التبويب المحدد
              List<String> types = ['الكل', 'بن', 'مشروب', 'أكل سريع / أخرى'];
              String targetCat = types[index] == 'أكل سريع / أخرى' ? 'أكل سريع / أخرى' : types[index];
              controller.updateTabFilter(targetCat);
            },
            isScrollable: true,

            // 🌟 تعديلات الألوان والخطوط للظهور بوضوح:
            indicatorColor: Colors.amber[400], // لون مؤشر التحديد (أصفر دافئ متناسق مع البيج والبني)
            indicatorWeight: 4,
            labelColor: Colors.white, // لون الأيقونة والنص للتبويب النشط (المحدد حالياً)
            unselectedLabelColor: Colors.white.withValues(alpha: 0.45), // لون التبويبات الأخرى غير النشطة لتوفير تباين مريح
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo'), // تخصيص الخط للمحدد
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13, fontFamily: 'Cairo'),

            tabs: const [
              Tab(text: 'الكل', icon: Icon(Icons.all_inclusive)),
              Tab(text: 'ركن البن', icon: Icon(Icons.grain)),
              Tab(text: 'المشروبات', icon: Icon(Icons.local_cafe)),
              Tab(text: 'أصناف أخرى', icon: Icon(Icons.fastfood)),
            ],
          ),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
        ),
        body: Row(
          children: [
            _buildCreativeSideForm(), // القائمة الجانبية المرنة لإضافة صنف جديد
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(25.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCreativeSearchBar(), // شريط البحث العلوي
                    const SizedBox(height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الرفوف الحالية',
                            style: TextStyle(fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF4E342E))),
                        Obx(() =>
                            Text('${controller.filteredProducts.length} صنف',
                                style: TextStyle(color: Colors.brown[400],
                                    fontWeight: FontWeight.bold))),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Expanded(child: _buildProductGrid()), // شبكة عرض المنتجات
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // بناء شبكة عرض الأصناف (Grid) بشكل مرن ومتجاوب
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

  // بناء بطاقة المنتج الاحترافية
// بناء بطاقة المنتج الاحترافية المحدثة بالأرصدة والألوان التحذيرية
  Widget _buildPremiumProductCard(Product p) {
    // 📊 جلب الرصيد الحالي الفعلي من الكنترولر
    double remaining = controller.productStock[p.id] ?? 0.0;

    // 🔍 تحديد حالة المخزن (خلصان - قرب يخلص - متوفر)
    bool isOutofStock = remaining <= 0;

    // شرط التنبيه: لو بن وأقل من 2 كيلو، أو لو أصناف تانية وأقل من 5 قطع
    bool isLowStock = (p.category == 'بن' && remaining > 0 && remaining <= 2.0) ||
        (p.category != 'بن' && p.category != 'مشروب' && remaining > 0 && remaining <= 5.0);

    // 🎨 تحديد لون خلفية الكارد بناءً على حالة الجرد
    Color cardBgColor = Colors.white;
    if (isOutofStock) {
      cardBgColor = Colors.grey[200]!; // رمادي لو خلص
    } else if (isLowStock) {
      cardBgColor = const Color(0xFFFFF3E0); // برتقالي خفيف تنبيهي لو قرب يخلص
    }

    // 🏷️ تحديد تمييز الوحدة (كيلو للبن، قطعة للأخرى، والمشروبات رصيد مفتوح)
    String unitLabel = p.category == 'بن' ? 'كيلو' : 'قطعة';

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

                // 📊 ⚡ الجزء الجديد: عرض الكمية المتاحة فعلياً بلون ديناميكي
                if (p.category != 'مشروب') ...[
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
                  // المشروبات السائلة رصيدها مفتوح دايماً من المنيو
                  Text(
                    'رصيد مفتوح (كوب) ✨',
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

  // ========== 🟢 تحديث: نموذج الإضافة الجانبي المطور والمرن بالكامل ==========
// ========== 🟢 تحديث: نموذج الإضافة الجانبي الآمن تماماً من الـ Crash ==========
// ========== 🟢 تحديث: نموذج الإضافة الجانبي مع إضافة حقل الكمية المخزنية المباشرة ==========
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

            // 1. حقل نصي حر لكتابة اسم المنتج يدوياً
            const Text('اسم المنتج (اكتب هنا مباشرة):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            _buildField(controller.nameCtrl, 'مثال:  نسكافيه، نعناع ...', Icons.label),

            const SizedBox(height: 15),

            // 2. قائمة المساعدة المنسدلة المحمية من مشاكل الـ Duplicate والـ Missing values
            Obx(() {
              if (controller.availableProductNames.isEmpty) return const SizedBox();

              // التحقق هل القيمة المخزنة موجودة فعلياً داخل القائمة المجلوبة؟
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

            // 3. حقل إدخال سعر البيع المخصص
            const Text('سعر البيع لعميل الصالة:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            _buildField(controller.priceCtrl, 'سعر البيع', Icons.payments, isNumber: true),

            const SizedBox(height: 15),

            // ⚡ 4. الحقل الجديد: إضافة الكمية المتوفرة مباشرة للمخزن (بدون مشتريات)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الكمية المتوفرة بالمخزن حالياً:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Obx(() {
                  // إشعار مستخدم نوع الوحدة ديناميكياً
                  String unitHint = 'قطعة';
                  if (controller.selectedCategory.value == 'بن') unitHint = 'كيلو';
                  if (controller.selectedCategory.value == 'مشروب') unitHint = 'كوب';
                  return Text('($unitHint)', style: TextStyle(color: Colors.brown[400], fontSize: 11, fontWeight: FontWeight.bold));
                }),
              ],
            ),
            const SizedBox(height: 8),
            // نربطه بـ controller.stockCtrl اللي هنعرفه حالا في خطوة 2
            _buildField(controller.stockCtrl, 'مثال: 10 أو 25.5', Icons.inventory_2_rounded, isNumber: true),

            const SizedBox(height: 20),

            const Text('التصنيف داخل المنيو:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildCustomSelector(),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: controller.addProduct,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: Colors.brown[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              child: const Text('إضافة للمخزن',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }  // أزرار الاختيار المخصصة لتحديد فئة الصنف الجديد
  Widget _buildCustomSelector() {
    final categories = ['بن', 'مشروب', 'أكل سريع / أخرى'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((cat) {
        return Obx(() {
          bool isSelected = controller.selectedCategory.value == cat;
          return GestureDetector(
            onTap: () => controller.changeCategory(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.brown[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? Colors.brown : Colors.grey.shade300),
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