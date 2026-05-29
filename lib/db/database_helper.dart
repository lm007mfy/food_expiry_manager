import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/food.dart';
import '../models/food_history.dart';
import '../models/category.dart';
import '../models/merchant.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'food_expiry.db');

    return await openDatabase(
      path,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE category (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE merchant (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE food (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        image_path TEXT,
        production_date TEXT,
        quantity INTEGER DEFAULT 0,
        expiry_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        notification_dismissed INTEGER DEFAULT 0,
        category_id INTEGER,
        shelf_life_days INTEGER,
        merchant_id INTEGER,
        is_deleted INTEGER DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES category(id) ON DELETE SET NULL,
        FOREIGN KEY (merchant_id) REFERENCES merchant(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE food_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        food_id INTEGER NOT NULL,
        food_name TEXT NOT NULL,
        production_date TEXT,
        quantity INTEGER DEFAULT 0,
        expiry_date TEXT,
        days_remaining INTEGER,
        recorded_at TEXT NOT NULL,
        merchant_name TEXT,
        shelf_life_days INTEGER,
        FOREIGN KEY (food_id) REFERENCES food(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE announcement_dismiss (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        food_id INTEGER NOT NULL,
        history_id INTEGER,
        dismissed_at TEXT NOT NULL,
        FOREIGN KEY (food_id) REFERENCES food(id) ON DELETE CASCADE
      )
    ''');

    // Insert default categories
    await db.insert('category', {'name': '未分类', 'icon': '📦'});
    await db.insert('category', {'name': '饮料', 'icon': '🥤'});
    await db.insert('category', {'name': '零食', 'icon': '🍪'});
    await db.insert('category', {'name': '调味品', 'icon': '🧂'});
    await db.insert('category', {'name': '乳制品', 'icon': '🥛'});
    await db.insert('category', {'name': '冷冻食品', 'icon': '🧊'});
    await db.insert('category', {'name': '主食', 'icon': '🍞'});
    await db.insert('category', {'name': '水果', 'icon': '🍎'});
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS category (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          icon TEXT
        )
      ''');
      try {
        await db.execute('ALTER TABLE food ADD COLUMN category_id INTEGER REFERENCES category(id)');
      } catch (_) {}
    }
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS category (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            icon TEXT
          )
        ''');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE food ADD COLUMN category_id INTEGER REFERENCES category(id)');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      // v2.0: merchant table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS merchant (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          created_at TEXT NOT NULL
        )
      ''');
      // v2.0: announcement_dismiss table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS announcement_dismiss (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          food_id INTEGER NOT NULL,
          history_id INTEGER,
          dismissed_at TEXT NOT NULL,
          FOREIGN KEY (food_id) REFERENCES food(id) ON DELETE CASCADE
        )
      ''');
      // v2.0: food table new columns
      try { await db.execute('ALTER TABLE food ADD COLUMN shelf_life_days INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE food ADD COLUMN merchant_id INTEGER REFERENCES merchant(id)'); } catch (_) {}
      try { await db.execute('ALTER TABLE food ADD COLUMN is_deleted INTEGER DEFAULT 0'); } catch (_) {}
      // v2.0: food_history table new columns
      try { await db.execute('ALTER TABLE food_history ADD COLUMN merchant_name TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE food_history ADD COLUMN shelf_life_days INTEGER'); } catch (_) {}
    }
    if (oldVersion < 5) {
      // v2.4: announcement_dismiss add history_id for per-record dismiss
      try { await db.execute('ALTER TABLE announcement_dismiss ADD COLUMN history_id INTEGER'); } catch (_) {}
    }
    if (oldVersion < 6) {
      // v2.5: Ensure history_id column exists (safety net for v2.4 bug)
      try { await db.execute('ALTER TABLE announcement_dismiss ADD COLUMN history_id INTEGER'); } catch (_) {}
    }
  }

  /// v2.5: Defensive check — ensure history_id column exists.
  /// Called before any query that references announcement_dismiss.history_id.
  bool _historyIdEnsured = false;
  Future<void> _ensureHistoryIdColumn() async {
    if (_historyIdEnsured) return;
    final db = await database;
    try {
      await db.execute('ALTER TABLE announcement_dismiss ADD COLUMN history_id INTEGER');
    } catch (_) {}
    _historyIdEnsured = true;
  }

  // ========== Food CRUD ==========

  Future<int> insertFood(Food food) async {
    final db = await database;
    return await db.insert('food', food.toMap());
  }

  Future<int> updateFood(Food food) async {
    final db = await database;
    return await db.update(
      'food',
      food.toMap(),
      where: 'id = ?',
      whereArgs: [food.id],
    );
  }

  /// Soft delete: mark as deleted
  Future<int> softDeleteFood(int id) async {
    final db = await database;
    return await db.update(
      'food',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// v2.6: Hard delete — permanently remove food and ALL related records.
  /// Deletes: announcement_dismiss, food_history, then food itself.
  Future<void> hardDeleteFood(int foodId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('announcement_dismiss', where: 'food_id = ?', whereArgs: [foodId]);
      await txn.delete('food_history', where: 'food_id = ?', whereArgs: [foodId]);
      await txn.delete('food', where: 'id = ?', whereArgs: [foodId]);
    });
  }

  /// Restore soft-deleted food
  Future<int> restoreFood(int id) async {
    final db = await database;
    return await db.update(
      'food',
      {'is_deleted': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteFood(int id) async {
    final db = await database;
    return await db.delete('food', where: 'id = ?', whereArgs: [id]);
  }

  Future<Food?> getFood(int id) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT f.*, m.name as merchant_name
      FROM food f
      LEFT JOIN merchant m ON f.merchant_id = m.id
      WHERE f.id = ?
    ''', [id]);
    if (maps.isEmpty) return null;
    return Food.fromMap(maps.first);
  }

  Future<List<Food>> getAllFoods({bool includeDeleted = false}) async {
    final db = await database;
    final where = includeDeleted ? null : 'f.is_deleted = 0';
    final maps = await db.rawQuery('''
      SELECT f.*, m.name as merchant_name
      FROM food f
      LEFT JOIN merchant m ON f.merchant_id = m.id
      ${where != null ? 'WHERE $where' : ''}
      ORDER BY f.name COLLATE NOCASE ASC
    ''');
    return maps.map((m) => Food.fromMap(m)).toList();
  }

  Future<List<Food>> getDeletedFoods() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT f.*, m.name as merchant_name
      FROM food f
      LEFT JOIN merchant m ON f.merchant_id = m.id
      WHERE f.is_deleted = 1
      ORDER BY f.name COLLATE NOCASE ASC
    ''');
    return maps.map((m) => Food.fromMap(m)).toList();
  }

  Future<List<Food>> searchFoods(String query) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT f.*, m.name as merchant_name
      FROM food f
      LEFT JOIN merchant m ON f.merchant_id = m.id
      WHERE f.is_deleted = 0 AND (f.name LIKE ? OR m.name LIKE ?)
      ORDER BY f.name COLLATE NOCASE ASC
    ''', ['%$query%', '%$query%']);
    return maps.map((m) => Food.fromMap(m)).toList();
  }

  Future<List<Food>> getFoodsByCategory(int categoryId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT f.*, m.name as merchant_name
      FROM food f
      LEFT JOIN merchant m ON f.merchant_id = m.id
      WHERE f.is_deleted = 0 AND f.category_id = ?
      ORDER BY f.name COLLATE NOCASE ASC
    ''', [categoryId]);
    return maps.map((m) => Food.fromMap(m)).toList();
  }

  Future<List<Food>> getFoodsByMerchant(int merchantId) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT f.*, m.name as merchant_name
      FROM food f
      LEFT JOIN merchant m ON f.merchant_id = m.id
      WHERE f.is_deleted = 0 AND f.merchant_id = ?
      ORDER BY f.name COLLATE NOCASE ASC
    ''', [merchantId]);
    return maps.map((m) => Food.fromMap(m)).toList();
  }

  Future<void> updateFoodExpiry(int foodId) async {
    // Recalculate expiry_date from the latest history record
    final histories = await getHistoryByFoodId(foodId);
    if (histories.isEmpty) return;
    final latest = histories.first;
    String? expiryDate;
    if (latest.productionDate != null && latest.shelfLifeDays != null && latest.shelfLifeDays! > 0) {
      final prod = DateTime.tryParse(latest.productionDate!);
      if (prod != null) {
        expiryDate = prod.add(Duration(days: latest.shelfLifeDays!)).toIso8601String();
      }
    }
    final db = await database;
    await db.update(
      'food',
      {'expiry_date': expiryDate, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [foodId],
    );
  }

  Future<int> getHistoryCount(int foodId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM food_history WHERE food_id = ?',
      [foodId],
    );
    return (result.first['cnt'] as num?)?.toInt() ?? 0;
  }

  // ========== Announcement Dismiss ==========

  Future<void> dismissAnnouncement(int foodId, {int? historyId}) async {
    await _ensureHistoryIdColumn(); // v2.5 safety
    final db = await database;
    // BUG-2: Prevent duplicate dismiss entries
    await db.rawInsert(
      'INSERT OR IGNORE INTO announcement_dismiss (food_id, history_id, dismissed_at) VALUES (?, ?, ?)',
      [foodId, historyId, DateTime.now().toIso8601String()],
    );
  }

  Future<void> restoreAnnouncement(int foodId) async {
    final db = await database;
    await db.delete('announcement_dismiss', where: 'food_id = ?', whereArgs: [foodId]);
  }

  Future<void> restoreAnnouncementByHistoryId(int historyId) async {
    final db = await database;
    await db.delete('announcement_dismiss', where: 'history_id = ?', whereArgs: [historyId]);
  }

  Future<void> clearAllDismissals() async {
    final db = await database;
    await db.delete('announcement_dismiss');
  }

  Future<Set<int>> getDismissedFoodIds() async {
    final db = await database;
    final maps = await db.query('announcement_dismiss');
    return maps.map((m) => (m['food_id'] as num).toInt()).toSet();
  }

  Future<Set<int>> getDismissedHistoryIds() async {
    await _ensureHistoryIdColumn(); // v2.5 safety
    final db = await database;
    final maps = await db.query('announcement_dismiss');
    return maps
        .where((m) => m['history_id'] != null)
        .map((m) => (m['history_id'] as num).toInt())
        .toSet();
  }

  /// Get all food_history records that are expiring (or expired) and not dismissed.
  /// Includes expired records. Computes daysRemaining in real-time from expiry_date (BUG-3/4 fix).
  Future<List<FoodHistory>> getExpiringHistoryRecords(int thresholdDays) async {
    await _ensureHistoryIdColumn(); // v2.5 safety
    final db = await database;

    // PERF-1: Single query using NOT EXISTS instead of 3 separate queries
    final maps = await db.rawQuery('''
      SELECT h.*, f.is_deleted
      FROM food_history h
      INNER JOIN food f ON h.food_id = f.id
      WHERE h.expiry_date IS NOT NULL
        AND f.is_deleted = 0
        AND NOT EXISTS (
          SELECT 1 FROM announcement_dismiss ad
          WHERE ad.history_id = h.id
        )
        AND NOT EXISTS (
          SELECT 1 FROM announcement_dismiss ad
          WHERE ad.history_id IS NULL AND ad.food_id = h.food_id
        )
      ORDER BY CAST(julianday(h.expiry_date) - julianday('now', 'localtime') AS INTEGER) ASC
    ''');

    // DEFECT-2/BUG-3: Filter in Dart with real-time calculation from expiry_date
    final now = DateTime.now();
    return maps
        .where((m) {
          final expiryStr = m['expiry_date'] as String?;
          if (expiryStr == null) return false;
          final expiry = DateTime.tryParse(expiryStr);
          if (expiry == null) return false;
          final realDaysRemaining = expiry.difference(now).inDays;
          return realDaysRemaining <= thresholdDays;
        })
        .map((m) => FoodHistory.fromMap(m))
        .toList();
  }

  /// Get all foods that have at least one history record linked to the given merchant name.
  Future<List<Food>> getFoodsByMerchantName(String merchantName) async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT DISTINCT f.*, m.name as merchant_name
      FROM food f
      LEFT JOIN merchant m ON f.merchant_id = m.id
      INNER JOIN food_history h ON f.id = h.food_id
      WHERE h.merchant_name = ? AND f.is_deleted = 0
      ORDER BY f.name COLLATE NOCASE ASC
    ''', [merchantName]);
    return maps.map((m) => Food.fromMap(m)).toList();
  }

  /// DEFECT-1: Get food count per merchant via food_history table (accurate for v2.4).
  Future<Map<String, int>> getMerchantFoodCounts() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT merchant_name, COUNT(DISTINCT food_id) as cnt
      FROM food_history
      WHERE merchant_name IS NOT NULL AND merchant_name != ''
      GROUP BY merchant_name
    ''');
    return {for (var m in maps) m['merchant_name'] as String: (m['cnt'] as num).toInt()};
  }

  /// Get dismissed foods (only non-deleted) — legacy backward-compatible.
  /// DEFECT-3: Exclude records that have history_id (handled by getDismissedHistoryRecords).
  Future<List<Food>> getDismissedFoods() async {
    await _ensureHistoryIdColumn(); // v2.5 safety
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT DISTINCT f.*, m.name as merchant_name
      FROM food f
      LEFT JOIN merchant m ON f.merchant_id = m.id
      INNER JOIN announcement_dismiss ad ON f.id = ad.food_id
      WHERE f.is_deleted = 0 AND ad.history_id IS NULL
      ORDER BY f.name COLLATE NOCASE ASC
    ''');
    return maps.map((m) => Food.fromMap(m)).toList();
  }

  /// Get dismissed history records for restore section (v2.4).
  /// Returns food_history records that were dismissed via history_id.
  Future<List<FoodHistory>> getDismissedHistoryRecords() async {
    await _ensureHistoryIdColumn(); // v2.5 safety
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT h.*, f.name as food_name
      FROM food_history h
      INNER JOIN announcement_dismiss ad ON h.id = ad.history_id
      INNER JOIN food f ON h.food_id = f.id
      WHERE f.is_deleted = 0
      ORDER BY h.days_remaining ASC
    ''');
    return maps.map((m) => FoodHistory.fromMap(m)).toList();
  }

  Future<int> insertHistory(FoodHistory history) async {
    final db = await database;
    return await db.insert('food_history', history.toMap());
  }

  Future<int> updateHistory(FoodHistory history) async {
    final db = await database;
    return await db.update(
      'food_history',
      history.toMap(),
      where: 'id = ?',
      whereArgs: [history.id],
    );
  }

  Future<int> deleteHistory(int id) async {
    final db = await database;
    return await db.delete('food_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<FoodHistory?> getHistory(int id) async {
    final db = await database;
    final maps = await db.query('food_history', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return FoodHistory.fromMap(maps.first);
  }

  Future<List<FoodHistory>> getHistoryByFoodId(int foodId) async {
    final db = await database;
    final maps = await db.query(
      'food_history',
      where: 'food_id = ?',
      whereArgs: [foodId],
      orderBy: 'recorded_at DESC',
    );
    return maps.map((m) => FoodHistory.fromMap(m)).toList();
  }

  Future<List<FoodHistory>> getHistoryByFoodIdAndMerchant(int foodId, String merchantName) async {
    final db = await database;
    final maps = await db.query(
      'food_history',
      where: 'food_id = ? AND merchant_name = ?',
      whereArgs: [foodId, merchantName],
      orderBy: 'recorded_at DESC',
    );
    return maps.map((m) => FoodHistory.fromMap(m)).toList();
  }

  /// Get the history record with the nearest (soonest) expiry date for a food.
  /// Returns null if no records with valid expiry exist.
  Future<FoodHistory?> getNearestExpiryRecord(int foodId) async {
    final db = await database;
    // Prefer non-expired records first (days_remaining >= 0), ordered by expiry ascending.
    // If all are expired, fall back to the one with the largest days_remaining (closest to 0).
    final maps = await db.rawQuery('''
      SELECT * FROM food_history
      WHERE food_id = ? AND expiry_date IS NOT NULL
      ORDER BY
        CASE WHEN expiry_date >= datetime('now') THEN 0 ELSE 1 END,
        expiry_date ASC
      LIMIT 1
    ''', [foodId]);
    if (maps.isEmpty) return null;
    return FoodHistory.fromMap(maps.first);
  }

  Future<List<FoodHistory>> getAllHistory() async {
    final db = await database;
    final maps = await db.query('food_history', orderBy: 'recorded_at DESC');
    return maps.map((m) => FoodHistory.fromMap(m)).toList();
  }

  // ========== Category CRUD ==========

  Future<int> insertCategory(FoodCategory category) async {
    final db = await database;
    return await db.insert('category', category.toMap());
  }

  Future<List<FoodCategory>> getAllCategories() async {
    final db = await database;
    final maps = await db.query('category', orderBy: 'id ASC');
    return maps.map((m) => FoodCategory.fromMap(m)).toList();
  }

  Future<int> updateCategory(FoodCategory category) async {
    final db = await database;
    return await db.update(
      'category',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    await db.update('food', {'category_id': null}, where: 'category_id = ?', whereArgs: [id]);
    return await db.delete('category', where: 'id = ?', whereArgs: [id]);
  }

  // ========== Merchant CRUD ==========

  Future<int> insertMerchant(Merchant merchant) async {
    final db = await database;
    return await db.insert('merchant', merchant.toMap());
  }

  Future<List<Merchant>> getAllMerchants() async {
    final db = await database;
    final maps = await db.query('merchant', orderBy: 'name COLLATE NOCASE ASC');
    return maps.map((m) => Merchant.fromMap(m)).toList();
  }

  Future<Merchant?> getMerchant(int id) async {
    final db = await database;
    final maps = await db.query('merchant', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Merchant.fromMap(maps.first);
  }

  Future<int> updateMerchant(Merchant merchant) async {
    final db = await database;
    return await db.update(
      'merchant',
      merchant.toMap(),
      where: 'id = ?',
      whereArgs: [merchant.id],
    );
  }

  Future<int> deleteMerchant(int id) async {
    final db = await database;
    await db.update('food', {'merchant_id': null}, where: 'merchant_id = ?', whereArgs: [id]);
    return await db.delete('merchant', where: 'id = ?', whereArgs: [id]);
  }

  // ========== Backup / Restore ==========

  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;
    final foods = await db.query('food');
    final histories = await db.query('food_history');
    final categories = await db.query('category');
    final merchants = await db.query('merchant');
    final dismisses = await db.query('announcement_dismiss');
    return {
      'foods': foods,
      'histories': histories,
      'categories': categories,
      'merchants': merchants,
      'dismisses': dismisses,
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importAllData(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('announcement_dismiss');
      await txn.delete('food_history');
      await txn.delete('food');
      await txn.delete('merchant');
      await txn.delete('category');

      // Import categories
      final categories = data['categories'] as List<dynamic>?;
      if (categories != null) {
        for (final cat in categories) {
          await txn.insert('category', Map<String, dynamic>.from(cat as Map));
        }
      }

      // Import merchants
      final merchants = data['merchants'] as List<dynamic>?;
      if (merchants != null) {
        for (final m in merchants) {
          await txn.insert('merchant', Map<String, dynamic>.from(m as Map));
        }
      }

      // Import foods
      final foods = data['foods'] as List<dynamic>?;
      if (foods != null) {
        for (final food in foods) {
          await txn.insert('food', Map<String, dynamic>.from(food as Map));
        }
      }

      // Import histories
      final histories = data['histories'] as List<dynamic>?;
      if (histories != null) {
        for (final h in histories) {
          await txn.insert('food_history', Map<String, dynamic>.from(h as Map));
        }
      }

      // Import dismisses
      final dismisses = data['dismisses'] as List<dynamic>?;
      if (dismisses != null) {
        for (final d in dismisses) {
          await txn.insert('announcement_dismiss', Map<String, dynamic>.from(d as Map));
        }
      }
    });
  }
}
