class Category {
  final String id;
  final String categoryName;
  final String categoryIcon;
  final bool isEnabled;
  final bool isApproved;
  final String? parentOf;

  Category({
    required this.id,
    required this.categoryName,
    required this.categoryIcon,
    required this.isEnabled,
    required this.isApproved,
    this.parentOf,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '',
      categoryName: json['category_name'] ?? '',
      categoryIcon: json['category_icon'] ?? '',
      isEnabled: json['is_enabled'] ?? false,
      isApproved: json['is_approved'] ?? false,
      parentOf: json['parent_of'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_name': categoryName,
      'category_icon': categoryIcon,
      'is_enabled': isEnabled,
      'is_approved': isApproved,
      'parent_of': parentOf,
    };
  }

  @override
  String toString() {
    return 'Category{id: $id, categoryName: $categoryName, isEnabled: $isEnabled, isApproved: $isApproved}';
  }
}
