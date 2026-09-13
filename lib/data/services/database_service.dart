import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product_model.dart';

class DatabaseService {
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'calorie_tracker.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        calories REAL NOT NULL,
        proteins REAL NOT NULL,
        carbs REAL NOT NULL,
        fats REAL NOT NULL,
        sugar REAL NOT NULL,
        fiber REAL,
        countryOrigin TEXT,
        category TEXT,
        barcode TEXT,
        imageUrl TEXT,
        createdAt INTEGER,
        updatedAt INTEGER
      )
    ''');

    await db.execute('CREATE INDEX idx_products_name ON products(name)');
    await db
        .execute('CREATE INDEX idx_products_category ON products(category)');
    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
  }

  Future<List<ProductModel>> searchProducts(String query) async {
    final db = await database;
    if (query.isEmpty) return [];

    final results = await db.query(
      'products',
      where: 'name LIKE ? OR category LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );

    return results.map((map) => ProductModel.fromMap(map)).toList();
  }

  Future<ProductModel?> getProductByBarcode(String barcode) async {
    final db = await database;
    final results = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return ProductModel.fromMap(results.first);
  }

  Future<ProductModel?> getProductById(int id) async {
    final db = await database;
    final results = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return ProductModel.fromMap(results.first);
  }

  Future<int> saveProduct(ProductModel product) async {
    final db = await database;
    final map = product.toMap();
    map.remove('id');
    return await db.insert('products', map);
  }

  Future<int> updateProduct(ProductModel product) async {
    final db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<bool> deleteProduct(int id) async {
    final db = await database;
    final count = await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('products');
  }

  Future<List<ProductModel>> getProductsByCategory(String category) async {
    final db = await database;
    final results = await db.query(
      'products',
      where: 'category = ?',
      whereArgs: [category],
    );
    return results.map((map) => ProductModel.fromMap(map)).toList();
  }

  Future<List<ProductModel>> getAllProducts() async {
    final db = await database;
    final results = await db.query('products');
    return results.map((map) => ProductModel.fromMap(map)).toList();
  }
}
