import '../database_helper.dart';
import '../models/product_model.dart';

class ProductsRepository {
  final dbHelper = DatabaseHelper.instance;

  Future<List<Product>> getAllProducts() async {
    final db = await dbHelper.database;
    final result = await db.query(
      'products',
      orderBy: 'name ASC',
    );
    return result.map((e) => Product.fromMap(e)).toList();
  }

  Future<void> addProduct({
    required String name,
    required String category,
    required String unit,
    required double price,
    double initialStock = 0.0, // 👈 إضافة الحقل الجديد هنا
  }) async {
    final db = await dbHelper.database;
    await db.insert('products', {
      'name': name,
      'category': category,
      'unit': unit,
      'price': price,
      'initial_stock': initialStock, // 👈 حفظ في الداتابيز
    });
  }

  Future<void> updateProduct(Product product) async {
    final db = await dbHelper.database;
    await db.update(
      'products',
      {
        'name': product.name,
        'category': product.category,
        'unit': product.unit,
        'price': product.price,
        'initial_stock': product.initialStock, // 👈 تحديث الحقل الجديد هنا
      },
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> updateProductPrice(int productId, double newPrice) async {
    final db = await dbHelper.database;
    await db.update(
      'products',
      {'price': newPrice},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<void> deleteProduct(int id) async {
    final db = await dbHelper.database;
    await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getProductsByCategory(String category) async {
    final db = await dbHelper.database;
    return await db.query(
      'products',
      where: 'category = ?',
      whereArgs: [category],
    );
  }
}