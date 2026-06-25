import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_config.dart';
import '../controllers/mangeController.dart';

class MangeScreen extends StatelessWidget {
  const MangeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // حقن الـ Controller في الشاشة
    final controller = Get.put(AttributesController());
    final textController = TextEditingController();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F5F2),
        appBar: AppBar(
          title: const Text(
            'إدارة الفئات والوحدات',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
          ),
          backgroundColor: AppConfig.system,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.red,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            unselectedLabelStyle: TextStyle(fontSize: 14),
            tabs: [
              Tab(icon: Icon(Icons.category_rounded), text: "الفئات والنشاطات"),
              Tab(icon: Icon(Icons.straighten_rounded), text: "وحدات القياس"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // التبويب الأول: الفئات
            Obx(() {
              if (controller.isCategoriesLoading.value) {
                return Center(child: CircularProgressIndicator(color: AppConfig.primaryColor));
              }
              if (controller.categories.isEmpty) {
                return _buildEmptyState("لا توجد فئات مضافة بعد، اضغط + لإضافة أول فئة");
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: controller.categories.length,
                itemBuilder: (context, index) {
                  final cat = controller.categories[index];
                  return _buildAttributeCard(
                    title: cat['name'].toString(),
                    icon: Icons.folder_open_rounded,
                    onDelete: () => controller.deleteCategory(cat['id'] as int),
                  );
                },
              );
            }),

            // التبويب الثاني: الوحدات
            Obx(() {
              if (controller.isUnitsLoading.value) {
                return Center(child: CircularProgressIndicator(color: AppConfig.primaryColor));
              }
              if (controller.units.isEmpty) {
                return _buildEmptyState("لا توجد وحدات مضافة بعد، اضغط + لإضافة أول وحدة مثل (كيلو، قطعة)");
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: controller.units.length,
                itemBuilder: (context, index) {
                  final unit = controller.units[index];
                  return _buildAttributeCard(
                    title: unit['name'].toString(),
                    icon: Icons.line_weight_rounded,
                    onDelete: () => controller.deleteUnit(unit['id'] as int),
                  );
                },
              );
            }),
          ],
        ),

        // الزر العائم الذكي
        floatingActionButton: Builder(
            builder: (context) {
              return FloatingActionButton(
                backgroundColor: AppConfig.system,
                foregroundColor: Colors.white,
                onPressed: () {
                  final currentTab = DefaultTabController.of(context).index;
                  _showAddBottomSheet(
                    context,
                    title: currentTab == 0 ? "إضافة فئة جديدة" : "إضافة وحدة قياس جديدة",
                    hint: currentTab == 0 ? "مثل: مشروبات، أدوية، بن، ملابس" : "مثل: كيلو، قطعة، علبة، متر",
                    textController: textController,
                    onSave: (value) {
                      if (currentTab == 0) {
                        controller.addCategory(value);
                      } else {
                        controller.addUnit(value);
                      }
                    },
                  );
                },
                child: const Icon(Icons.add, size: 28),
              );
            }
        ),
      ),
    );
  }

  // ودجت تصميم الكارت لكل عنصر داخل القائمة
  Widget _buildAttributeCard({required String title, required IconData icon, required VoidCallback onDelete}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppConfig.system.withValues(alpha: 0.08),
          child: Icon(icon, color: AppConfig.primaryColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
          onPressed: onDelete,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.layers_clear_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ✨ الدالة المعدلة لتوسيط شيت الإدخال في منتصف الشاشة تماماً ليتناسب مع الويندوز
  void _showAddBottomSheet(
      BuildContext context, {
        required String title,
        required String hint,
        required TextEditingController textController,
        required Function(String) onSave,
      }) {
    textController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // جعل الخلفية شفافة لعمل حواف مخصصة
      builder: (context) {
        return Center( // 🎯 التوسيط في منتصف الشاشة
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500), // 🛡️ تحديد حد أقصى للعرض عشان ما يفرشش في الشاشة
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16), // حواف دائرية كاملة من كل الجهات
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              top: 24,
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24, // التعامل مع كيبورد التاتش لو وُجد
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // يأخذ حجم المحتوى فقط
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: textController,
                  autofocus: true,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppConfig.primaryColor, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConfig.system,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      if (textController.text.trim().isNotEmpty) {
                        onSave(textController.text);
                        Navigator.pop(context);
                      }
                    },
                    child: const Text(
                      "حفظ التأكيد",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}