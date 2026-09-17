import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/recipe_model.dart';

class RecipeService {
  static Database? _database;
  static Future<Database>? _databaseOpening;
  static final RecipeService _instance = RecipeService._internal();

  factory RecipeService() => _instance;
  RecipeService._internal();

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    final opening = _databaseOpening ??= _initDatabase();
    return _database ??= await opening;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'recipes.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE recipes(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        ingredients TEXT NOT NULL,
        instructions TEXT NOT NULL,
        calories INTEGER NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,
        localImagePath TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> saveRecipe(RecipeModel recipe) async {
    final db = await database;
    await db.insert(
      'recipes',
      recipe.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RecipeModel>> getAllRecipes() async {
    final db = await database;
    final results = await db.query('recipes', orderBy: 'createdAt DESC');
    return results.map((map) => RecipeModel.fromJson(map)).toList();
  }

  Future<RecipeModel?> getRecipeById(String id) async {
    final db = await database;
    final results = await db.query(
      'recipes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return RecipeModel.fromJson(results.first);
  }

  Future<int> deleteRecipe(String id) async {
    final db = await database;
    return await db.delete(
      'recipes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateRecipe(RecipeModel recipe) async {
    final db = await database;
    await db.update(
      'recipes',
      recipe.toJson(),
      where: 'id = ?',
      whereArgs: [recipe.id],
    );
  }
}
