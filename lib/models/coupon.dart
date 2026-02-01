class Coupon {
  final String id;
  final String couponCode;
  final String imgUrl;
  final bool isUniversal;
  final double amount;
  final String description;
  final int expiryTimestamp;
  final bool freeShipping;
  final double minimumAmount;
  final double maximumDiscountAmountLimit;

  Coupon({
    required this.id,
    required this.couponCode,
    required this.imgUrl,
    required this.isUniversal,
    required this.amount,
    required this.description,
    required this.expiryTimestamp,
    required this.freeShipping,
    required this.minimumAmount,
    required this.maximumDiscountAmountLimit,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: json['id'] ?? '',
      couponCode: json['coupon_code'] ?? '',
      imgUrl: json['img_url'] ?? '',
      isUniversal: json['is_universal'] ?? false,
      amount: double.tryParse(json['amount']?.toString() ?? '0.0') ?? 0.0,
      description: json['description'] ?? '',
      expiryTimestamp: json['expiry_timestamp'] ?? 0,
      freeShipping: json['free_shipping'] ?? false,
      minimumAmount:
          double.tryParse(json['minimum_amount']?.toString() ?? '0.0') ?? 0.0,
      maximumDiscountAmountLimit:
          double.tryParse(
            json['maximum_discount_amount_limit']?.toString() ?? '0.0',
          ) ??
          0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coupon_code': couponCode,
      'img_url': imgUrl,
      'is_universal': isUniversal,
      'amount': amount.toStringAsFixed(2),
      'description': description,
      'expiry_timestamp': expiryTimestamp,
      'free_shipping': freeShipping,
      'minimum_amount': minimumAmount.toStringAsFixed(2),
      'maximum_discount_amount_limit': maximumDiscountAmountLimit
          .toStringAsFixed(2),
    };
  }
}
