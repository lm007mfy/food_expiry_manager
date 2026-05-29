import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../db/database_helper.dart';
import '../../models/food.dart';
import '../../models/food_history.dart';
import '../../models/category.dart';
import '../../models/merchant.dart';

class AppState extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  List<Food> _foods = [];
  List<FoodCategory> _categories = [];
  List<Merchant> _merchants = [];
  List<FoodHistory> _expiringRecords = [];
  Map<String, int> _merchantFoodCounts = {}; // DEFECT-1
  int _thresholdDays = 30; // default 1 month
  String _searchQuery = '';
  Set<int> _dismissedFoodIds = {};
  Set<int> _dismissedHistoryIds = {};
  int _dismissVersion = 0; // BUG-1: Track dismissal changes
  Timer? _hourlyTimer; // BUG-4: Periodic refresh

  List<Food> get foods => _foods;
  List<FoodCategory> get categories => _categories;
  List<Merchant> get merchants => _merchants;
  List<FoodHistory> get expiringRecords => _expiringRecords;
  Map<String, int> get merchantFoodCounts => _merchantFoodCounts; // DEFECT-1
  int get thresholdDays => _thresholdDays;
  String get searchQuery => _searchQuery;
  Set<int> get dismissedFoodIds => _dismissedFoodIds;
  Set<int> get dismissedHistoryIds => _dismissedHistoryIds;
  int get dismissVersion => _dismissVersion; // BUG-1

  int get thresholdMonths {
    if (_thresholdDays <= 30) return 1;
    if (_thresholdDays <= 60) return 2;
    return 3;
  }

  Future<void> init() async {
    await _loadThreshold();
    await refreshFoods();
    await refreshCategories();
    await refreshMerchants();
    await refreshMerchantFoodCounts(); // DEFECT-1
    await _loadDismissedIds();
    await refreshExpiringRecords();
    _startHourlyRefresh(); // BUG-4
  }

  /// BUG-4: Start hourly timer to refresh expiring records (cross-day accuracy)
  void _startHourlyRefresh() {
    _hourlyTimer = Timer.periodic(const Duration(hours: 1), (_) async {
      await refreshExpiringRecords();
    });
  }

  @override
  void dispose() {
    _hourlyTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    _thresholdDays = prefs.getInt('threshold_days') ?? 30;
    notifyListeners();
  }

  Future<void> setThresholdMonths(int months) async {
    _thresholdDays = months * 30;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('threshold_days', _thresholdDays);
    await refreshExpiringRecords();
    notifyListeners();
  }

  Future<void> refreshFoods() async {
    _foods = await _db.getAllFoods();
    notifyListeners();
  }

  Future<void> refreshCategories() async {
    _categories = await _db.getAllCategories();
    notifyListeners();
  }

  Future<void> refreshMerchants() async {
    _merchants = await _db.getAllMerchants();
    notifyListeners();
  }

  /// DEFECT-1: Refresh merchant food counts from food_history table
  Future<void> refreshMerchantFoodCounts() async {
    _merchantFoodCounts = await _db.getMerchantFoodCounts();
    notifyListeners();
  }

  Future<void> _loadDismissedIds() async {
    _dismissedFoodIds = await _db.getDismissedFoodIds();
    _dismissedHistoryIds = await _db.getDismissedHistoryIds();
    notifyListeners();
  }

  // ========== Search ==========

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Food> get filteredFoods {
    if (_searchQuery.isEmpty) return _foods;
    final q = _searchQuery.toLowerCase();
    return _foods.where((f) {
      return f.name.toLowerCase().contains(q) ||
          (f.merchantName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ========== Announcement (v2.4 — per-record) ==========

  /// Refresh cached expiring records from DB (including expired)
  Future<void> refreshExpiringRecords() async {
    _expiringRecords = await _db.getExpiringHistoryRecords(_thresholdDays);
    notifyListeners();
  }

  /// Dismiss a specific announcement record by historyId (v2.4)
  Future<void> dismissAnnouncement(int foodId, {int? historyId}) async {
    await _db.dismissAnnouncement(foodId, historyId: historyId);
    if (historyId != null) {
      _dismissedHistoryIds.add(historyId);
    } else {
      _dismissedFoodIds.add(foodId);
    }
    _dismissVersion++; // BUG-1
    await refreshExpiringRecords();
    notifyListeners();
  }

  /// Restore a food-level dismissal (legacy backward-compatible)
  Future<void> restoreAnnouncement(int foodId) async {
    await _db.restoreAnnouncement(foodId);
    _dismissedFoodIds.remove(foodId);
    _dismissVersion++; // BUG-1
    await refreshExpiringRecords();
    notifyListeners();
  }

  /// Restore a specific history record dismissal (v2.4)
  Future<void> restoreAnnouncementByHistoryId(int historyId) async {
    await _db.restoreAnnouncementByHistoryId(historyId);
    _dismissedHistoryIds.remove(historyId);
    _dismissVersion++; // BUG-1
    await refreshExpiringRecords();
    notifyListeners();
  }

  /// Clear all dismissals and refresh (v2.4)
  Future<void> clearAllDismissals() async {
    await _db.clearAllDismissals();
    _dismissedFoodIds.clear();
    _dismissedHistoryIds.clear();
    _dismissVersion++; // BUG-1
    await refreshExpiringRecords();
    notifyListeners();
  }

  Future<List<FoodHistory>> getDismissedHistoryRecords() async {
    return await _db.getDismissedHistoryRecords();
  }

  Future<List<Food>> getDismissedFoods() async {
    return await _db.getDismissedFoods();
  }

  // ========== Food CRUD ==========

  Future<void> addFood(String name, {int? categoryId}) async {
    final now = DateTime.now().toIso8601String();
    final food = Food(
      name: name,
      createdAt: now,
      updatedAt: now,
      categoryId: categoryId,
    );
    await _db.insertFood(food);
    await refreshFoods();
  }

  Future<void> updateFood(Food food) async {
    final updated = food.copyWith(updatedAt: DateTime.now().toIso8601String());
    await _db.updateFood(updated);
    await refreshFoods();
  }

  Future<void> deleteFood(int id) async {
    await _db.softDeleteFood(id);
    await refreshFoods();
  }

  /// v2.6: Hard delete — permanently remove food and all related records
  Future<void> hardDeleteFood(int id) async {
    await _db.hardDeleteFood(id);
    await refreshFoods();
    await refreshExpiringRecords();
    await refreshMerchantFoodCounts();
  }

  /// Save a record (history) and update the food's expiry_date from latest history
  Future<void> saveRecord(Food food, FoodHistory history) async {
    final now = DateTime.now().toIso8601String();

    // Update food's latest info
    final updatedFood = food.copyWith(
      productionDate: history.productionDate,
      quantity: history.quantity,
      expiryDate: history.expiryDate,
      shelfLifeDays: history.shelfLifeDays,
      merchantId: null, // will be set if merchant name matches
      updatedAt: now,
    );

    // Try to find merchant by name
    if (history.merchantName != null && history.merchantName!.isNotEmpty) {
      final merchant = _merchants.where((m) => m.name == history.merchantName).firstOrNull;
      if (merchant != null) {
        // Update food with merchant_id
        final withMerchant = updatedFood.copyWith(merchantId: merchant.id);
        await _db.updateFood(withMerchant);
      } else {
        await _db.updateFood(updatedFood);
      }
    } else {
      await _db.updateFood(updatedFood);
    }

    // Insert history record
    await _db.insertHistory(history);

    // Recalculate food's expiry from latest history
    await _db.updateFoodExpiry(food.id!);

    await refreshFoods();
    await refreshExpiringRecords();
    await refreshMerchantFoodCounts(); // DEFECT-1
  }

  Future<void> updateRecord(FoodHistory history) async {
    await _db.updateHistory(history);

    // Also update the parent food's latest info from this record
    final food = await _db.getFood(history.foodId);
    if (food != null) {
      String? expiryDate;
      if (history.productionDate != null && history.shelfLifeDays != null && history.shelfLifeDays! > 0) {
        final prod = DateTime.tryParse(history.productionDate!);
        if (prod != null) {
          expiryDate = prod.add(Duration(days: history.shelfLifeDays!)).toIso8601String();
        }
      }

      int? merchantId;
      if (history.merchantName != null && history.merchantName!.isNotEmpty) {
        final merchant = _merchants.where((m) => m.name == history.merchantName).firstOrNull;
        merchantId = merchant?.id;
      }

      final updated = food.copyWith(
        productionDate: history.productionDate,
        quantity: history.quantity,
        expiryDate: expiryDate,
        shelfLifeDays: history.shelfLifeDays,
        merchantId: merchantId,
        updatedAt: DateTime.now().toIso8601String(),
      );
      await _db.updateFood(updated);
    }

    await refreshFoods();
    await refreshExpiringRecords();
    await refreshMerchantFoodCounts(); // DEFECT-1
  }

  Future<void> deleteRecord(int historyId, int foodId) async {
    await _db.deleteHistory(historyId);
    // Recalculate food's expiry from latest history
    await _db.updateFoodExpiry(foodId);
    await refreshFoods();
    await refreshExpiringRecords();
    await refreshMerchantFoodCounts(); // DEFECT-1
  }

  // ========== Merchant CRUD ==========

  Future<int> addMerchant(String name) async {
    final merchant = Merchant(
      name: name,
      createdAt: DateTime.now().toIso8601String(),
    );
    final id = await _db.insertMerchant(merchant);
    await refreshMerchants();
    return id;
  }

  Future<void> deleteMerchant(int id) async {
    await _db.deleteMerchant(id);
    await refreshMerchants();
    await refreshFoods();
  }

  // ========== Category CRUD ==========

  Future<void> addCategory(String name, String icon) async {
    final cat = FoodCategory(name: name, icon: icon);
    await _db.insertCategory(cat);
    await refreshCategories();
  }

  Future<void> deleteCategory(int id) async {
    await _db.deleteCategory(id);
    await refreshCategories();
    await refreshFoods();
  }

  // Re-export database helper for screens that need it
  DatabaseHelper get db => _db;
}
