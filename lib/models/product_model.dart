class Product {
  final String id;
  final String productName;
  final int quantity;
  final List<dynamic> productVariantInCart;
  final double? priceStartsFrom;
  final double? lowestAvailablePrice;
  final String foodPreference;
  final double averageRating;
  final int ratingCount;
  final String imgUrl;
  final String description;
  final double ranking;
  final bool isFeatured;
  final bool isSponsored;
  final String parentCategory;
  final String childCategory;
  final String productTemplateId;
  final String parentCategoryId;
  final String childCategoryId;
  final bool isAccessibleOnline;
  final bool isAccessiblePos;

  Product({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.productVariantInCart,
    this.priceStartsFrom,
    this.lowestAvailablePrice,
    required this.foodPreference,
    required this.averageRating,
    required this.ratingCount,
    required this.imgUrl,
    required this.description,
    required this.ranking,
    required this.isFeatured,
    required this.isSponsored,
    required this.parentCategory,
    required this.childCategory,
    required this.productTemplateId,
    required this.parentCategoryId,
    required this.childCategoryId,
    required this.isAccessibleOnline,
    required this.isAccessiblePos,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] ?? '',
      productName: json['product_name'] ?? '',
      quantity: json['quantity'] ?? 0,
      productVariantInCart: json['product_variant_in_cart'] ?? [],
      priceStartsFrom: json['price_starts_from'] != null
          ? (json['price_starts_from'] as num).toDouble()
          : null,
      lowestAvailablePrice: json['lowest_available_price'] != null
          ? (json['lowest_available_price'] as num).toDouble()
          : null,
      foodPreference: json['food_preference'] ?? '',
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] ?? 0,
      imgUrl: json['img_url'] ?? '',
      description: json['description'] ?? '',
      ranking: (json['ranking'] as num?)?.toDouble() ?? 0.0,
      isFeatured: json['is_featured'] ?? false,
      isSponsored: json['is_sponsored'] ?? false,
      parentCategory: json['parent_category'] ?? '',
      childCategory: json['child_category'] ?? '',
      productTemplateId: json['product_template_id'] ?? '',
      parentCategoryId: json['parent_category_id'] ?? '',
      childCategoryId: json['child_category_id'] ?? '',
      isAccessibleOnline: json['is_accessible_online'] ?? false,
      isAccessiblePos: json['is_accessible_pos'] ?? false,
    );
  }

  // Create a copy with updated quantity
  Product copyWith({int? quantity}) {
    return Product(
      id: id,
      productName: productName,
      quantity: quantity ?? this.quantity,
      productVariantInCart: productVariantInCart,
      priceStartsFrom: priceStartsFrom,
      lowestAvailablePrice: lowestAvailablePrice,
      foodPreference: foodPreference,
      averageRating: averageRating,
      ratingCount: ratingCount,
      imgUrl: imgUrl,
      description: description,
      ranking: ranking,
      isFeatured: isFeatured,
      isSponsored: isSponsored,
      parentCategory: parentCategory,
      childCategory: childCategory,
      productTemplateId: productTemplateId,
      parentCategoryId: parentCategoryId,
      childCategoryId: childCategoryId,
      isAccessibleOnline: isAccessibleOnline,
      isAccessiblePos: isAccessiblePos,
    );
  }
}
