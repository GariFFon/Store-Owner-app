import 'package:exanor/services/api_service.dart';

class StoreAnalyticsService {
  /// Fetch revenue analytics
  static Future<List<Map<String, dynamic>>> getRevenueAnalytics({
    required String storeId,
    required String startDate,
    required String endDate,
    String? year,
    String? month,
    String type = 'custom',
    String orderStatus = 'order_placed',
  }) async {
    try {
      final body = {
        'store_id': storeId,
        'store_access': true,
        'type': type,
        'order_status': orderStatus,
        'start_date': startDate,
        'end_date': endDate,
        if (year != null) 'year': int.tryParse(year) ?? year,
        if (month != null) 'month': month,
      };

      final response = await ApiService.post(
        '/store-analytics-revenue/',
        body: body,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          return List<Map<String, dynamic>>.from(data['response']);
        }
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch revenue analytics: $e');
    }
  }

  /// Fetch order count analytics
  static Future<List<Map<String, dynamic>>> getOrderCountAnalytics({
    required String storeId,
    required String startDate,
    required String endDate,
    String? year,
    String? month,
    String type = 'custom',
    String orderStatus = 'order_placed',
  }) async {
    try {
      final body = {
        'store_id': storeId,
        'store_access': true,
        'type': type,
        'order_status': orderStatus,
        'start_date': startDate,
        'end_date': endDate,
        if (year != null) 'year': int.tryParse(year) ?? year,
        if (month != null) 'month': month,
      };

      final response = await ApiService.post(
        '/store-analytics-order-count/',
        body: body,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          return List<Map<String, dynamic>>.from(data['response']);
        }
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch order count analytics: $e');
    }
  }

  /// Fetch sentiment analytics
  static Future<List<dynamic>> getSentimentAnalytics({
    required String storeId,
    required String startDate,
    required String endDate,
    String? year,
    String? month,
    String type = 'custom',
    String orderStatus = 'order_placed',
  }) async {
    try {
      final body = {
        'store_id': storeId,
        'store_access': true,
        'type': type,
        'order_status': orderStatus,
        'start_date': startDate,
        'end_date': endDate,
        if (year != null) 'year': int.tryParse(year) ?? year,
        if (month != null) 'month': month,
      };

      final response = await ApiService.post(
        '/store-analytics-sentiment/',
        body: body,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          return List<dynamic>.from(data['response']);
        }
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch sentiment analytics: $e');
    }
  }

  /// Fetch order method analytics
  static Future<List<Map<String, dynamic>>> getOrderMethodAnalytics({
    required String storeId,
    required String startDate,
    required String endDate,
    String? year,
    String? month,
    int? week,
    int? day,
    String type = 'custom',
  }) async {
    try {
      final body = {
        'store_id': storeId,
        'store_access': true,
        'type': type,
        'start_date': startDate,
        'end_date': endDate,
        if (year != null) 'year': int.tryParse(year) ?? year,
        if (month != null) 'month': int.tryParse(month) ?? month,
        if (week != null) 'week': week,
        if (day != null) 'day': day,
      };

      final response = await ApiService.post(
        '/store-analytics-order-method/',
        body: body,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          return List<Map<String, dynamic>>.from(data['response']);
        }
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch order method analytics: $e');
    }
  }

  /// Fetch payment method analytics
  static Future<List<Map<String, dynamic>>> getPaymentMethodAnalytics({
    required String storeId,
    required String startDate,
    required String endDate,
    String? year,
    String? month,
    int? week,
    int? day,
    String type = 'custom',
  }) async {
    try {
      final body = {
        'store_id': storeId,
        'store_access': true,
        'type': type,
        'start_date': startDate,
        'end_date': endDate,
        if (year != null) 'year': int.tryParse(year) ?? year,
        if (month != null) 'month': int.tryParse(month) ?? month,
        if (week != null) 'week': week,
        if (day != null) 'day': day,
      };

      final response = await ApiService.post(
        '/store-analytics-payment-method/',
        body: body,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          return List<Map<String, dynamic>>.from(data['response']);
        }
      }
      return [];
    } catch (e) {
      throw Exception('Failed to fetch payment method analytics: $e');
    }
  }
}
