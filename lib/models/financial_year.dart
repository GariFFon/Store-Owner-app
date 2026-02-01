class FinancialYear {
  final String id;
  final String store;
  final String storeName;
  final String startDate;
  final String endDate;
  final bool isActive;
  final bool isLocked;
  final bool isCurrentFy;
  final String createdAt;

  FinancialYear({
    required this.id,
    required this.store,
    required this.storeName,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.isLocked,
    required this.isCurrentFy,
    required this.createdAt,
  });

  factory FinancialYear.fromJson(Map<String, dynamic> json) {
    return FinancialYear(
      id: json['id'] ?? '',
      store: json['store'] ?? '',
      storeName: json['store_name'] ?? '',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      isActive: json['is_active'] ?? false,
      isLocked: json['is_locked'] ?? false,
      isCurrentFy: json['is_current_fy'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }

  // Helper to get formatted duration text
  String get durationText {
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final days = end.difference(start).inDays;
      return '$days days';
    } catch (e) {
      return '';
    }
  }

  // Helper to get formatted FY name (e.g., FY 2026)
  String get displayName {
    try {
      final end = DateTime.parse(endDate);
      return 'FY ${end.year}';
    } catch (e) {
      return 'FY';
    }
  }
}
