class FoodHistory {
  final int? id;
  final int foodId;
  final String foodName;
  final String? productionDate;
  final int quantity;
  final String? expiryDate;
  final int? daysRemaining;
  final String recordedAt;
  // v2.0 new fields
  final String? merchantName;
  final int? shelfLifeDays;

  FoodHistory({
    this.id,
    required this.foodId,
    required this.foodName,
    this.productionDate,
    this.quantity = 0,
    this.expiryDate,
    this.daysRemaining,
    required this.recordedAt,
    this.merchantName,
    this.shelfLifeDays,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'food_id': foodId,
      'food_name': foodName,
      'production_date': productionDate,
      'quantity': quantity,
      'expiry_date': expiryDate,
      'days_remaining': daysRemaining,
      'recorded_at': recordedAt,
      'merchant_name': merchantName,
      'shelf_life_days': shelfLifeDays,
    };
  }

  factory FoodHistory.fromMap(Map<String, dynamic> map) {
    return FoodHistory(
      id: map['id'] as int?,
      foodId: (map['food_id'] as num).toInt(),
      foodName: map['food_name'] as String,
      productionDate: map['production_date'] as String?,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      expiryDate: map['expiry_date'] as String?,
      daysRemaining: (map['days_remaining'] as num?)?.toInt(),
      recordedAt: map['recorded_at'] as String,
      merchantName: map['merchant_name'] as String?,
      shelfLifeDays: (map['shelf_life_days'] as num?)?.toInt(),
    );
  }

  FoodHistory copyWith({
    int? id,
    int? foodId,
    String? foodName,
    String? productionDate,
    int? quantity,
    String? expiryDate,
    int? daysRemaining,
    String? recordedAt,
    String? merchantName,
    int? shelfLifeDays,
  }) {
    return FoodHistory(
      id: id ?? this.id,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      productionDate: productionDate ?? this.productionDate,
      quantity: quantity ?? this.quantity,
      expiryDate: expiryDate ?? this.expiryDate,
      daysRemaining: daysRemaining ?? this.daysRemaining,
      recordedAt: recordedAt ?? this.recordedAt,
      merchantName: merchantName ?? this.merchantName,
      shelfLifeDays: shelfLifeDays ?? this.shelfLifeDays,
    );
  }

  /// Format remaining time snapshot
  String get remainingText {
    // BUG-3: Always use real-time calculation from expiryDate when available
    final d = realDaysRemaining ?? daysRemaining;
    if (d == null) return '—';
    if (d < 0) return '已过期 ${d.abs()}天';
    final years = d ~/ 365;
    final months = (d % 365) ~/ 30;
    final remainingDays = d - years * 365 - months * 30;
    if (years > 0) return '$years年${months}个月${remainingDays}天';
    if (months > 0) return '$months个月${remainingDays}天';
    return '$d天';
  }

  /// BUG-3: Real-time days remaining computed from expiryDate.
  /// Returns null if no expiryDate is set.
  int? get realDaysRemaining {
    if (expiryDate == null) return null;
    final expiry = DateTime.tryParse(expiryDate!);
    if (expiry == null) return null;
    return expiry.difference(DateTime.now()).inDays;
  }
}
