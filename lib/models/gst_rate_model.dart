class GstRate {
  final String id;
  final String hsnCode;
  final String hsnDescription;
  final String cgstPercent;
  final String sgstPercent;
  final String igstPercent;
  final String cessPercent;
  final String effectiveFrom;
  final String effectiveTo;
  final bool isActive;
  final String createdAt;

  GstRate({
    required this.id,
    required this.hsnCode,
    required this.hsnDescription,
    required this.cgstPercent,
    required this.sgstPercent,
    required this.igstPercent,
    required this.cessPercent,
    required this.effectiveFrom,
    required this.effectiveTo,
    required this.isActive,
    required this.createdAt,
  });

  factory GstRate.fromJson(Map<String, dynamic> json) {
    return GstRate(
      id: json['id'] ?? '',
      hsnCode: json['hsn_code'] ?? '',
      hsnDescription: json['hsn_description'] ?? '',
      cgstPercent: json['cgst_percent'] ?? '0.00',
      sgstPercent: json['sgst_percent'] ?? '0.00',
      igstPercent: json['igst_percent'] ?? '0.00',
      cessPercent: json['cess_percent'] ?? '0.00',
      effectiveFrom: json['effective_from'] ?? '',
      effectiveTo: json['effective_to'] ?? '',
      isActive: json['is_active'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class GstResponse {
  final int status;
  final List<GstRate> rates;
  final int count;
  final int limit;
  final int offset;

  GstResponse({
    required this.status,
    required this.rates,
    required this.count,
    required this.limit,
    required this.offset,
  });

  factory GstResponse.fromJson(Map<String, dynamic> json) {
    return GstResponse(
      status: json['status'] ?? 0,
      rates:
          (json['response'] as List<dynamic>?)
              ?.map((e) => GstRate.fromJson(e))
              .toList() ??
          [],
      count: json['count'] ?? 0,
      limit: json['limit'] ?? 50,
      offset: json['offset'] ?? 0,
    );
  }
}
