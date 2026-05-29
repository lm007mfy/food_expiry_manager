class FoodCategory {
  final int? id;
  final String name;
  final String? icon;

  FoodCategory({
    this.id,
    required this.name,
    this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'icon': icon,
    };
  }

  factory FoodCategory.fromMap(Map<String, dynamic> map) {
    return FoodCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String?,
    );
  }
}
