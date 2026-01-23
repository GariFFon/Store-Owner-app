class Store {
  final String id;
  final String storeName;
  final String categoryId;
  final String category;
  final String fulfillmentSpeed;
  final String city;
  final String area;
  final String? weburl;
  final double averageRating;
  final int ratingCount;
  final String storeCityLocation;
  final String achievementText;
  final String offerTypeText;
  final String offerText;
  final String offerConditionText;
  final String bottomOfferTitle;
  final String bottomOfferSubtitle;
  final String bottomOfferImg;
  final bool isSponsored;
  final bool isFeatured;
  final String storeLogoImgUrl;
  final String storeBannerImgUrl;

  Store({
    required this.id,
    required this.storeName,
    required this.categoryId,
    required this.category,
    required this.fulfillmentSpeed,
    required this.city,
    required this.area,
    this.weburl,
    required this.averageRating,
    required this.ratingCount,
    required this.storeCityLocation,
    required this.achievementText,
    required this.offerTypeText,
    required this.offerText,
    required this.offerConditionText,
    required this.bottomOfferTitle,
    required this.bottomOfferSubtitle,
    required this.bottomOfferImg,
    required this.isSponsored,
    required this.isFeatured,
    required this.storeLogoImgUrl,
    required this.storeBannerImgUrl,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] ?? '',
      storeName: json['store_name'] ?? '',
      categoryId: json['cartegory_id'] ?? '', // Note typo in API response
      category: json['category'] ?? '',
      fulfillmentSpeed: json['fulfillment_speed'] ?? '',
      city: json['city'] ?? '',
      area: json['area'] ?? '',
      weburl: json['weburl'] == 'undefined' ? null : json['weburl'],
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] ?? 0,
      storeCityLocation: json['store_city_location'] ?? '',
      achievementText: json['achievement_text'] ?? '',
      offerTypeText: json['offer_type_text'] ?? '',
      offerText: json['offer_text'] ?? '',
      offerConditionText: json['offer_condition_text'] ?? '',
      bottomOfferTitle: json['bottom_offer_title'] ?? '',
      bottomOfferSubtitle: json['bottom_offer_subtitle'] ?? '',
      bottomOfferImg: json['bottom_offer_img'] ?? '',
      isSponsored: json['is_sponsored'] ?? false,
      isFeatured: json['is_featured'] ?? false,
      storeLogoImgUrl: json['store_logo_img_url'] ?? '',
      storeBannerImgUrl: json['store_banner_img_url'] ?? '',
    );
  }
}
