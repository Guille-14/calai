import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product_model.dart';

class DatabaseService {
  static String _dayKey(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  static Database? _database;
  static Future<Database>? _databaseOpening;
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) return existing;
    final opening = _databaseOpening ??= _initDatabase();
    return _database ??= await opening;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'calorie_tracker.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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

    await _createFoodEntriesTable(db);
    await _createWorkoutSessionsTable(db);
    await _createHealthDailyMetricsTable(db);
  }

  /// v1 -> v2: añade las tablas de registro de comidas y sesiones de
  /// entrenamiento. Antes el registro diario de comidas vivía entero en
  /// SharedPreferences como JSON por día (food_log_YYYY-MM-DD), sin índice,
  /// lo que obligaba a leer ~30 claves por pantalla y impedía cruzar los
  /// datos de comida con los de entrenamiento.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createFoodEntriesTable(db);
      await _createWorkoutSessionsTable(db);
    }
    if (oldVersion < 3) {
      await _upgradeWorkoutSessionsWithImportMetadata(db);
    }
    if (oldVersion < 4) {
      await _upgradeHealthAndWorkoutMetrics(db);
    }
  }

  Future<void> _upgradeWorkoutSessionsWithImportMetadata(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(workout_sessions)');
    final names = columns.map((row) => row['name']?.toString()).toSet();
    if (!names.contains('source')) {
      await db.execute(
          "ALTER TABLE workout_sessions ADD COLUMN source TEXT NOT NULL DEFAULT 'native'");
    }
    if (!names.contains('external_id')) {
      await db.execute(
          'ALTER TABLE workout_sessions ADD COLUMN external_id TEXT');
    }
    if (!names.contains('imported_at')) {
      await db.execute(
          'ALTER TABLE workout_sessions ADD COLUMN imported_at INTEGER');
    }
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_workout_sessions_source ON workout_sessions(source)');
    await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_workout_sessions_external_id ON workout_sessions(source, external_id) WHERE external_id IS NOT NULL');
  }

  Future<void> _upgradeHealthAndWorkoutMetrics(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(workout_sessions)');
    final names = columns.map((row) => row['name']?.toString()).toSet();
    for (final column in const [
      'calories_burned',
      'distance_meters',
      'steps',
      'activity_name',
    ]) {
      if (!names.contains(column)) {
        final type = column == 'activity_name' ? 'TEXT' : 'REAL';
        await db.execute('ALTER TABLE workout_sessions ADD COLUMN $column $type');
      }
    }
    await _createHealthDailyMetricsTable(db);
    final healthColumns = await db.rawQuery('PRAGMA table_info(health_daily_metrics)');
    final healthNames = healthColumns.map((row) => row['name']?.toString()).toSet();
    if (!healthNames.contains('other_metrics')) {
      await db.execute('ALTER TABLE health_daily_metrics ADD COLUMN other_metrics TEXT');
    }
  }

  Future<void> _createHealthDailyMetricsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS health_daily_metrics(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date INTEGER NOT NULL,
        source TEXT NOT NULL,
        steps INTEGER NOT NULL DEFAULT 0,
        active_calories REAL NOT NULL DEFAULT 0,
        basal_calories REAL NOT NULL DEFAULT 0,
        distance_meters REAL NOT NULL DEFAULT 0,
        weight_kg REAL,
        sleep_minutes REAL NOT NULL DEFAULT 0,
        sleep_sessions INTEGER NOT NULL DEFAULT 0,
        heart_rate_avg REAL,
        heart_rate_min REAL,
        heart_rate_max REAL,
        heart_rate_samples INTEGER NOT NULL DEFAULT 0,
        workouts INTEGER NOT NULL DEFAULT 0,
        other_metrics TEXT,
        imported_at INTEGER NOT NULL,
        UNIQUE(date, source)
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_health_daily_date ON health_daily_metrics(date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_health_daily_source ON health_daily_metrics(source)');
  }

  Future<void> _createFoodEntriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS food_entries(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        calories REAL NOT NULL,
        protein REAL NOT NULL,
        carbs REAL NOT NULL,
        fat REAL NOT NULL,
        sugar REAL NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        image_url TEXT,
        confidence_score REAL,
        ai_model TEXT,
        ingredients TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_food_entries_timestamp ON food_entries(timestamp)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_food_entries_name ON food_entries(name)');
  }

  Future<void> _createWorkoutSessionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS workout_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date INTEGER NOT NULL,
        total_tonnage REAL NOT NULL,
        duration_minutes INTEGER NOT NULL,
        muscle_group_tonnage TEXT,
        xp_earned REAL,
        source TEXT NOT NULL DEFAULT 'native',
        external_id TEXT,
        imported_at INTEGER,
        calories_burned REAL,
        distance_meters REAL,
        steps REAL,
        activity_name TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_workout_sessions_date ON workout_sessions(date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_workout_sessions_source ON workout_sessions(source)');
    await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_workout_sessions_external_id ON workout_sessions(source, external_id) WHERE external_id IS NOT NULL');
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

  // ------------------------------------------------------------------
  // food_entries: registro de comidas (migrado desde SharedPreferences)
  // ------------------------------------------------------------------

  /// Devuelve las filas de food_entries dentro de un rango de fechas
  /// (inclusivo en ambos extremos, en días), ordenadas por timestamp.
  Future<List<Map<String, dynamic>>> getFoodEntriesBetween(
    DateTime startInclusive,
    DateTime endInclusive,
  ) async {
    final db = await database;
    final startMs = DateTime(startInclusive.year, startInclusive.month,
            startInclusive.day)
        .millisecondsSinceEpoch;
    final endMs = DateTime(endInclusive.year, endInclusive.month,
            endInclusive.day)
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch -
        1;
    return db.query(
      'food_entries',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startMs, endMs],
      orderBy: 'timestamp ASC',
    );
  }

  /// Últimas [limit] comidas registradas (cualquier fecha).
  Future<List<Map<String, dynamic>>> getRecentFoodEntries(int limit) async {
    final db = await database;
    return db.query(
      'food_entries',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  Future<int> insertFoodEntry(Map<String, dynamic> entry) async {
    final db = await database;
    return db.insert(
      'food_entries',
      entry,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Inserción en lote (migración) dentro de una sola transacción.
  Future<void> insertFoodEntries(List<Map<String, dynamic>> entries) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final entry in entries) {
        await txn.insert(
          'food_entries',
          entry,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<int> deleteFoodEntry(String id) async {
    final db = await database;
    return db.delete('food_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countFoodEntries() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS n FROM food_entries');
    return (result.first['n'] as int?) ?? 0;
  }

  /// ¿Hay al menos una comida registrada en ese día?
  Future<bool> hasFoodOnDate(DateTime date) async {
    final rows = await getFoodEntriesBetween(date, date);
    return rows.isNotEmpty;
  }

  /// Devuelve solo los días con comidas, evitando cargar todos los campos de
  /// cada comida cuando se calcula una racha o un resumen.
  Future<Set<String>> getFoodDateKeysBetween(
    DateTime startInclusive,
    DateTime endInclusive,
  ) async {
    final db = await database;
    final startMs = DateTime(startInclusive.year, startInclusive.month,
            startInclusive.day)
        .millisecondsSinceEpoch;
    final endMs = DateTime(endInclusive.year, endInclusive.month,
            endInclusive.day)
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch -
        1;
    final rows = await db.query(
      'food_entries',
      columns: const ['timestamp'],
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [startMs, endMs],
    );
    return {
      for (final row in rows)
        _dayKey(DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int)),
    };
  }

  // ------------------------------------------------------------------
  // workout_sessions: historial consultable de entrenamientos Symmetry
  // ------------------------------------------------------------------

  Future<int> insertWorkoutSession({
    required DateTime date,
    required double totalTonnage,
    required int durationMinutes,
    required Map<String, double> muscleGroupTonnage,
    double xpEarned = 0.0,
    String source = 'native',
    String? externalId,
    DateTime? importedAt,
    double? caloriesBurned,
    double? distanceMeters,
    double? steps,
    String? activityName,
  }) async {
    final db = await database;
    return db.insert(
      'workout_sessions',
      {
        'date': DateTime(date.year, date.month, date.day)
            .millisecondsSinceEpoch,
        'total_tonnage': totalTonnage,
        'duration_minutes': durationMinutes,
        'muscle_group_tonnage': jsonEncode(muscleGroupTonnage),
        'xp_earned': xpEarned,
        'source': source,
        'external_id': externalId,
        'imported_at': importedAt?.millisecondsSinceEpoch,
        'calories_burned': caloriesBurned,
        'distance_meters': distanceMeters,
        'steps': steps,
        'activity_name': activityName,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getWorkoutSessionsBetween(
    DateTime startInclusive,
    DateTime endInclusive,
  ) async {
    final db = await database;
    final startMs = DateTime(startInclusive.year, startInclusive.month,
            startInclusive.day)
        .millisecondsSinceEpoch;
    final endMs = DateTime(endInclusive.year, endInclusive.month,
            endInclusive.day)
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch -
        1;
    return db.query(
      'workout_sessions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startMs, endMs],
      orderBy: 'date DESC',
    );
  }

  Future<bool> hasWorkoutOnDate(DateTime date) async {
    final rows = await getWorkoutSessionsBetween(date, date);
    return rows.isNotEmpty;
  }

  Future<Set<String>> getWorkoutDateKeysBetween(
    DateTime startInclusive,
    DateTime endInclusive,
  ) async {
    final db = await database;
    final startMs = DateTime(startInclusive.year, startInclusive.month,
            startInclusive.day)
        .millisecondsSinceEpoch;
    final endMs = DateTime(endInclusive.year, endInclusive.month,
            endInclusive.day)
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch -
        1;
    final rows = await db.query(
      'workout_sessions',
      columns: const ['date'],
      where: 'date >= ? AND date <= ?',
      whereArgs: [startMs, endMs],
    );
    return {
      for (final row in rows)
        _dayKey(DateTime.fromMillisecondsSinceEpoch(row['date'] as int)),
    };
  }

  Future<bool> hasWorkoutExternalId(String source, String externalId) async {
    final db = await database;
    final rows = await db.query(
      'workout_sessions',
      columns: const ['id'],
      where: 'source = ? AND external_id = ?',
      whereArgs: [source, externalId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Consulta los identificadores ya importados en lotes para no hacer una
  /// consulta SQLite por cada sesión de Health Connect.
  Future<Set<String>> getExistingWorkoutExternalIds(
    String source,
    Iterable<String> externalIds,
  ) async {
    final ids = externalIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) return <String>{};

    final db = await database;
    final found = <String>{};
    // SQLite limita el número de parámetros de una sentencia; 900 deja
    // margen para el parámetro de source en dispositivos con límite 999.
    for (var offset = 0; offset < ids.length; offset += 900) {
      final end = offset + 900 < ids.length ? offset + 900 : ids.length;
      final chunk = ids.sublist(offset, end);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.rawQuery(
        'SELECT external_id FROM workout_sessions '
        'WHERE source = ? AND external_id IN ($placeholders)',
        [source, ...chunk],
      );
      for (final row in rows) {
        final id = row['external_id']?.toString();
        if (id != null) found.add(id);
      }
    }
    return found;
  }

  Future<List<Map<String, dynamic>>> getRecentWorkoutSessions(
      {int limit = 50}) async {
    final db = await database;
    return db.query(
      'workout_sessions',
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
  }

  Future<Map<String, int>> getWorkoutSourceCounts() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT source, COUNT(*) AS n FROM workout_sessions GROUP BY source');
    return {
      for (final row in rows)
        row['source']?.toString() ?? 'unknown': (row['n'] as num).toInt(),
    };
  }

  Future<int> countWorkoutSessions() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS n FROM workout_sessions');
    return (result.first['n'] as int?) ?? 0;
  }

  Future<void> upsertHealthDailyMetric({
    required DateTime date,
    required String source,
    required int steps,
    required double activeCalories,
    required double basalCalories,
    required double distanceMeters,
    double? weightKg,
    required double sleepMinutes,
    required int sleepSessions,
    double? heartRateAverage,
    double? heartRateMin,
    double? heartRateMax,
    required int heartRateSamples,
    required int workouts,
    Map<String, dynamic> otherMetrics = const {},
    required DateTime importedAt,
  }) async {
    final db = await database;
    await db.insert(
      'health_daily_metrics',
      {
        'date': DateTime(date.year, date.month, date.day).millisecondsSinceEpoch,
        'source': source,
        'steps': steps,
        'active_calories': activeCalories,
        'basal_calories': basalCalories,
        'distance_meters': distanceMeters,
        'weight_kg': weightKg,
        'sleep_minutes': sleepMinutes,
        'sleep_sessions': sleepSessions,
        'heart_rate_avg': heartRateAverage,
        'heart_rate_min': heartRateMin,
        'heart_rate_max': heartRateMax,
        'heart_rate_samples': heartRateSamples,
        'workouts': workouts,
        'other_metrics': jsonEncode(otherMetrics),
        'imported_at': importedAt.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getHealthDailyMetricsBetween(
    DateTime startInclusive,
    DateTime endInclusive,
  ) async {
    final db = await database;
    final startMs = DateTime(startInclusive.year, startInclusive.month,
            startInclusive.day)
        .millisecondsSinceEpoch;
    final endMs = DateTime(endInclusive.year, endInclusive.month,
            endInclusive.day)
        .add(const Duration(days: 1))
        .millisecondsSinceEpoch -
        1;
    return db.query(
      'health_daily_metrics',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startMs, endMs],
      orderBy: 'date DESC, source ASC',
    );
  }

  Future<Map<String, dynamic>?> getHealthDailyMetric(DateTime date) async {
    final rows = await getHealthDailyMetricsBetween(date, date);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> countHealthDailyMetrics() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM health_daily_metrics');
    return (result.first['n'] as int?) ?? 0;
  }
}
