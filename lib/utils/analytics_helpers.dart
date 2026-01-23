import 'package:exanor/services/analytics_service.dart';

/// Analytics helper functions for common tracking scenarios
class AnalyticsHelpers {
  static final AnalyticsService _analytics = AnalyticsService();

  /// Track subcategory click - use this in any subcategory click handler
  ///
  /// Example usage:
  /// ```dart
  /// onTap: () {
  ///   AnalyticsHelpers.trackSubcategoryClick(
  ///     subcategoryId: subcategory['id'].toString(),
  ///     subcategoryName: subcategory['name'],
  ///     parentCategory: parentCategory['name'],
  ///   );
  ///   // Your existing navigation code here
  /// }
  /// ```
  static Future<void> trackSubcategoryClick({
    required String subcategoryId,
    required String subcategoryName,
    required String parentCategory,
  }) async {
    await _analytics.logSubcategoryClicked(
      subcategoryId: subcategoryId,
      subcategoryName: subcategoryName,
      parentCategory: parentCategory,
    );
  }

  /// Track profile view from any location
  ///
  /// Example usage:
  /// ```dart
  /// AnalyticsHelpers.trackProfileView(
  ///   profileId: profile['id'].toString(),
  ///   profileType: 'professional', // or 'employee', 'business'
  ///   profileName: profile['name'],
  ///   source: 'search_results', // or 'category_list', 'featured', etc.
  /// );
  /// ```
  static Future<void> trackProfileView({
    required String profileId,
    required String profileType,
    required String profileName,
    String? source,
    int? listPosition,
  }) async {
    await _analytics.logProfileClicked(
      profileId: profileId,
      profileType: profileType,
      profileName: profileName,
      listPosition: listPosition,
      source: source,
    );
  }

  /// Track search performed
  ///
  /// Example usage:
  /// ```dart
  /// AnalyticsHelpers.trackSearch(
  ///   searchTerm: searchController.text,
  ///   category: selectedCategory,
  ///   resultsCount: searchResults.length,
  /// );
  /// ```
  static Future<void> trackSearch({
    required String searchTerm,
    String? category,
    int? resultsCount,
  }) async {
    await _analytics.logSearchPerformed(
      searchTerm: searchTerm,
      category: category,
      resultsCount: resultsCount,
    );
  }

  /// Track filter application
  ///
  /// Example usage:
  /// ```dart
  /// AnalyticsHelpers.trackFilter(
  ///   filterType: 'rating',
  ///   filterValue: '4_stars_and_above',
  ///   resultsCount: filteredResults.length,
  /// );
  /// ```
  static Future<void> trackFilter({
    required String filterType,
    required String filterValue,
    int? resultsCount,
  }) async {
    await _analytics.logFilterApplied(
      filterType: filterType,
      filterValue: filterValue,
      resultsCount: resultsCount,
    );
  }

  /// Track subscription interaction
  ///
  /// Example usage:
  /// ```dart
  /// AnalyticsHelpers.trackSubscription(
  ///   action: 'viewed', // 'started', 'completed', 'cancelled'
  ///   planType: 'premium_monthly',
  ///   price: 299.0,
  /// );
  /// ```
  static Future<void> trackSubscription({
    required String action,
    String? planType,
    double? price,
    String? currency,
  }) async {
    await _analytics.logSubscriptionEvent(
      action: action,
      planType: planType,
      price: price,
      currency: currency,
    );
  }

  /// Track user engagement
  ///
  /// Example usage:
  /// ```dart
  /// AnalyticsHelpers.trackEngagement(
  ///   action: 'share_profile',
  ///   targetId: profile['id'].toString(),
  ///   targetType: 'professional',
  /// );
  /// ```
  static Future<void> trackEngagement({
    required String action,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? additionalParams,
  }) async {
    await _analytics.logUserEngagement(
      action: action,
      targetId: targetId,
      targetType: targetType,
      additionalParams: additionalParams,
    );
  }

  /// Track error occurrence
  ///
  /// Example usage:
  /// ```dart
  /// AnalyticsHelpers.trackError(
  ///   errorType: 'api_error',
  ///   errorMessage: e.toString(),
  ///   screenName: 'profile_screen',
  /// );
  /// ```
  static Future<void> trackError({
    required String errorType,
    required String errorMessage,
    String? screenName,
    String? userId,
  }) async {
    await _analytics.logError(
      errorType: errorType,
      errorMessage: errorMessage,
      screenName: screenName,
      userId: userId,
    );
  }
}
