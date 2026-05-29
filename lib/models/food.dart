class Food {
  final int? id;
  final String name;
  final String? imagePath;
  final String? productionDate;
  final int quantity;
  final String? expiryDate;
  final String createdAt;
  final String updatedAt;
  final int notificationDismissed;
  final int? categoryId;
  // v2.0 new fields
  final int? shelfLifeDays;
  final int? merchantId;
  final int isDeleted;
  // Runtime-only field for merchant name (joined query)
  final String? merchantName;

  Food({
    this.id,
    required this.name,
    this.imagePath,
    this.productionDate,
    this.quantity = 0,
    this.expiryDate,
    required this.createdAt,
    required this.updatedAt,
    this.notificationDismissed = 0,
    this.categoryId,
    this.shelfLifeDays,
    this.merchantId,
    this.isDeleted = 0,
    this.merchantName,
  });

  /// Auto-calculate expiry date from production date + shelf life days
  static String? calcExpiryDate(String? productionDate, int? shelfLifeDays) {
    if (productionDate == null || shelfLifeDays == null || shelfLifeDays <= 0) return null;
    final prod = DateTime.tryParse(productionDate);
    if (prod == null) return null;
    return prod.add(Duration(days: shelfLifeDays)).toIso8601String();
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'image_path': imagePath,
      'production_date': productionDate,
      'quantity': quantity,
      'expiry_date': expiryDate,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'notification_dismissed': notificationDismissed,
      'category_id': categoryId,
      'shelf_life_days': shelfLifeDays,
      'merchant_id': merchantId,
      'is_deleted': isDeleted,
    };
  }

  factory Food.fromMap(Map<String, dynamic> map) {
    return Food(
      id: map['id'] as int?,
      name: map['name'] as String,
      imagePath: map['image_path'] as String?,
      productionDate: map['production_date'] as String?,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      expiryDate: map['expiry_date'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      notificationDismissed: (map['notification_dismissed'] as num?)?.toInt() ?? 0,
      categoryId: map['category_id'] as int?,
      shelfLifeDays: (map['shelf_life_days'] as num?)?.toInt(),
      merchantId: (map['merchant_id'] as num?)?.toInt(),
      isDeleted: (map['is_deleted'] as num?)?.toInt() ?? 0,
      merchantName: map['merchant_name'] as String?,
    );
  }

  Food copyWith({
    int? id,
    String? name,
    String? imagePath,
    String? productionDate,
    int? quantity,
    String? expiryDate,
    String? createdAt,
    String? updatedAt,
    int? notificationDismissed,
    int? categoryId,
    int? shelfLifeDays,
    int? merchantId,
    int? isDeleted,
    String? merchantName,
  }) {
    return Food(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      productionDate: productionDate ?? this.productionDate,
      quantity: quantity ?? this.quantity,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notificationDismissed: notificationDismissed ?? this.notificationDismissed,
      categoryId: categoryId ?? this.categoryId,
      shelfLifeDays: shelfLifeDays ?? this.shelfLifeDays,
      merchantId: merchantId ?? this.merchantId,
      isDeleted: isDeleted ?? this.isDeleted,
      merchantName: merchantName ?? this.merchantName,
    );
  }

  /// Calculate days remaining until expiry. Returns null if no expiry date set.
  int? get daysRemaining {
    if (expiryDate == null) return null;
    final expiry = DateTime.tryParse(expiryDate!);
    if (expiry == null) return null;
    return expiry.difference(DateTime.now()).inDays;
  }

  /// Format remaining time as human-readable string
  String get remainingText {
    if (expiryDate == null) return '—';
    final expiry = DateTime.tryParse(expiryDate!);
    if (expiry == null) return '—';
    final now = DateTime.now();
    final diff = expiry.difference(now);

    if (diff.isNegative) {
      return '已过期 ${diff.inDays.abs()}天';
    }

    final days = diff.inDays;
    final years = days ~/ 365;
    final months = (days % 365) ~/ 30;
    final remainingDays = days - years * 365 - months * 30;

    if (years > 0) {
      return '$years年${months}个月${remainingDays}天';
    } else if (months > 0) {
      return '$months个月${remainingDays}天';
    } else {
      return '$days天';
    }
  }
}
