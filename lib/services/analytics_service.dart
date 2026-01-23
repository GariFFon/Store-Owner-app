import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  late final FirebaseAnalytics _analytics;
  late final FirebaseAnalyticsObserver _observer;

  // Initialize the analytics service
  void initialize() {
    _analytics = FirebaseAnalytics.instance;
    _observer = FirebaseAnalyticsObserver(analytics: _analytics);

    // Set default event parameters
    _setDefaultEventParameters();

    if (kDebugMode) {
      print('🔥 Analytics Service initialized');
    }
  }

  // Getters for external access
  FirebaseAnalytics get analytics => _analytics;
  FirebaseAnalyticsObserver get observer => _observer;

  // Set default event parameters
  Future<void> _setDefaultEventParameters() async {
    try {
      if (!kIsWeb) {
        await _analytics.setDefaultEventParameters(<String, dynamic>{
          'app_version': '1.0.0', // Replace with actual app version
          'platform': 'flutter',
          'debug_mode': kDebugMode,
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error setting default event parameters: $e');
      }
    }
  }

  // Set user properties
  Future<void> setUserId(String userId) async {
    try {
      await _analytics.setUserId(id: userId);
      if (kDebugMode) {
        print('📊 User ID set: $userId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error setting user ID: $e');
      }
    }
  }

  Future<void> setUserProperty(String name, String? value) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
      if (kDebugMode) {
        print('📊 User property set: $name = $value');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error setting user property: $e');
      }
    }
  }

  // Screen tracking events
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
        parameters: _cleanParameters(parameters),
      );
      if (kDebugMode) {
        print('📱 Screen viewed: $screenName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error logging screen view: $e');
      }
    }
  }

  // Helper method to clean parameters for Firebase Analytics
  Map<String, Object>? _cleanParameters(Map<String, dynamic>? params) {
    if (params == null) return null;

    final cleanedParams = <String, Object>{};
    params.forEach((key, value) {
      if (value != null) {
        cleanedParams[key] = value;
      }
    });

    return cleanedParams.isEmpty ? null : cleanedParams;
  }

  // Custom event tracking
  Future<void> logEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    try {
      await _analytics.logEvent(
        name: eventName,
        parameters: _cleanParameters(parameters),
      );
      if (kDebugMode) {
        print('🎯 Event logged: $eventName with params: $parameters');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error logging event: $e');
      }
    }
  }

  // Specific screen opened events
  Future<void> logSubscriptionPageOpened() async {
    await logEvent(
      eventName: 'subscription_page_opened',
      parameters: {
        'screen_name': 'subscription_page',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> logMyProfileScreenOpened() async {
    await logEvent(
      eventName: 'my_profile_screen_opened',
      parameters: {
        'screen_name': 'my_profile_screen',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> logUserProfileScreenOpened({
    required String userId,
    required String profileType,
  }) async {
    await logEvent(
      eventName: 'user_profile_screen_opened',
      parameters: {
        'screen_name': 'user_profile_screen',
        'profile_user_id': userId,
        'profile_type': profileType,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> logUserProfileEditableScreenOpened() async {
    await logEvent(
      eventName: 'user_profile_editable_screen_opened',
      parameters: {
        'screen_name': 'user_profile_editable_screen',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Interaction events
  Future<void> logSubcategoryClicked({
    required String subcategoryId,
    required String subcategoryName,
    required String parentCategory,
  }) async {
    await logEvent(
      eventName: 'subcategory_clicked',
      parameters: {
        'subcategory_id': subcategoryId,
        'subcategory_name': subcategoryName,
        'parent_category': parentCategory,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> logProfileClicked({
    required String profileId,
    required String profileType,
    required String profileName,
    int? listPosition,
    String? source,
  }) async {
    await logEvent(
      eventName: 'profile_clicked',
      parameters: {
        'profile_id': profileId,
        'profile_type': profileType,
        'profile_name': profileName,
        'list_position': listPosition,
        'source': source ?? 'unknown',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // User engagement events
  Future<void> logUserEngagement({
    required String action,
    String? targetId,
    String? targetType,
    Map<String, dynamic>? additionalParams,
  }) async {
    final params = <String, dynamic>{
      'engagement_action': action,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (targetId != null) params['target_id'] = targetId;
    if (targetType != null) params['target_type'] = targetType;
    if (additionalParams != null) params.addAll(additionalParams);

    await logEvent(eventName: 'user_engagement', parameters: params);
  }

  // Search and filter events
  Future<void> logSearchPerformed({
    required String searchTerm,
    String? category,
    int? resultsCount,
  }) async {
    await logEvent(
      eventName: 'search_performed',
      parameters: {
        'search_term': searchTerm,
        'category': category,
        'results_count': resultsCount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> logFilterApplied({
    required String filterType,
    required String filterValue,
    int? resultsCount,
  }) async {
    await logEvent(
      eventName: 'filter_applied',
      parameters: {
        'filter_type': filterType,
        'filter_value': filterValue,
        'results_count': resultsCount,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Business events
  Future<void> logSubscriptionEvent({
    required String action, // 'viewed', 'started', 'completed', 'cancelled'
    String? planType,
    double? price,
    String? currency,
  }) async {
    await logEvent(
      eventName: 'subscription_$action',
      parameters: {
        'action': action,
        'plan_type': planType,
        'price': price,
        'currency': currency ?? 'INR',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Error tracking
  Future<void> logError({
    required String errorType,
    required String errorMessage,
    String? screenName,
    String? userId,
  }) async {
    await logEvent(
      eventName: 'app_error',
      parameters: {
        'error_type': errorType,
        'error_message': errorMessage,
        'screen_name': screenName,
        'user_id': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Performance tracking
  Future<void> logPerformanceEvent({
    required String eventName,
    required int durationMs,
    String? additionalInfo,
  }) async {
    await logEvent(
      eventName: 'performance_$eventName',
      parameters: {
        'duration_ms': durationMs,
        'additional_info': additionalInfo,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Session events
  Future<void> logSessionStart() async {
    await logEvent(
      eventName: 'session_start',
      parameters: {'timestamp': DateTime.now().millisecondsSinceEpoch},
    );
  }

  Future<void> logSessionEnd({int? sessionDurationMs}) async {
    await logEvent(
      eventName: 'session_end',
      parameters: {
        'session_duration_ms': sessionDurationMs,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  // Batch event logging for better performance
  final List<Map<String, dynamic>> _eventQueue = [];

  void queueEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) {
    _eventQueue.add({
      'eventName': eventName,
      'parameters': parameters,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> flushEventQueue() async {
    if (_eventQueue.isEmpty) return;

    for (final event in _eventQueue) {
      await logEvent(
        eventName: event['eventName'],
        parameters: event['parameters'],
      );
    }

    _eventQueue.clear();

    if (kDebugMode) {
      print('🔄 Event queue flushed');
    }
  }

  // Disable analytics (for GDPR compliance)
  Future<void> disableAnalytics() async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(false);
      if (kDebugMode) {
        print('🚫 Analytics disabled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error disabling analytics: $e');
      }
    }
  }

  // Enable analytics
  Future<void> enableAnalytics() async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(true);
      if (kDebugMode) {
        print('✅ Analytics enabled');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error enabling analytics: $e');
      }
    }
  }

  // Reset analytics data
  Future<void> resetAnalyticsData() async {
    try {
      await _analytics.resetAnalyticsData();
      if (kDebugMode) {
        print('🔄 Analytics data reset');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error resetting analytics data: $e');
      }
    }
  }
}
