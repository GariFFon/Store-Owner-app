import 'package:flutter/material.dart';
import 'package:exanor/services/analytics_service.dart';

/// A wrapper widget that automatically tracks screen views and provides analytics functionality
class AnalyticsTracker extends StatefulWidget {
  final Widget child;
  final String screenName;
  final String? screenClass;
  final Map<String, dynamic>? screenParameters;
  final bool autoTrackScreenView;

  const AnalyticsTracker({
    super.key,
    required this.child,
    required this.screenName,
    this.screenClass,
    this.screenParameters,
    this.autoTrackScreenView = true,
  });

  @override
  State<AnalyticsTracker> createState() => _AnalyticsTrackerState();
}

class _AnalyticsTrackerState extends State<AnalyticsTracker> {
  final AnalyticsService _analytics = AnalyticsService();

  @override
  void initState() {
    super.initState();

    // Track screen view automatically if enabled
    if (widget.autoTrackScreenView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _trackScreenView();
      });
    }
  }

  void _trackScreenView() {
    _analytics.logScreenView(
      screenName: widget.screenName,
      screenClass: widget.screenClass,
      parameters: widget.screenParameters,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnalyticsProvider(
      analytics: _analytics,
      screenName: widget.screenName,
      child: widget.child,
    );
  }
}

/// Provides analytics service through InheritedWidget
class AnalyticsProvider extends InheritedWidget {
  final AnalyticsService analytics;
  final String screenName;

  const AnalyticsProvider({
    super.key,
    required this.analytics,
    required this.screenName,
    required super.child,
  });

  /// Get analytics service from context
  static AnalyticsService? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AnalyticsProvider>()
        ?.analytics;
  }

  /// Get current screen name from context
  static String? screenNameOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AnalyticsProvider>()
        ?.screenName;
  }

  @override
  bool updateShouldNotify(AnalyticsProvider oldWidget) {
    return analytics != oldWidget.analytics ||
        screenName != oldWidget.screenName;
  }
}

/// Mixin for widgets that need analytics functionality
mixin AnalyticsMixin<T extends StatefulWidget> on State<T> {
  AnalyticsService? get analytics => AnalyticsProvider.of(context);
  String? get currentScreenName => AnalyticsProvider.screenNameOf(context);

  /// Track an event with automatic screen context
  Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
  }) async {
    final enrichedParams = <String, dynamic>{
      if (currentScreenName != null) 'screen_name': currentScreenName!,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      ...?parameters,
    };

    await analytics?.logEvent(eventName: eventName, parameters: enrichedParams);
  }

  /// Track user engagement with automatic context
  Future<void> trackEngagement(
    String action, {
    String? targetId,
    String? targetType,
    Map<String, dynamic>? additionalParams,
  }) async {
    await analytics?.logUserEngagement(
      action: action,
      targetId: targetId,
      targetType: targetType,
      additionalParams: {
        if (currentScreenName != null) 'screen_name': currentScreenName!,
        ...?additionalParams,
      },
    );
  }

  /// Track profile click with context
  Future<void> trackProfileClick({
    required String profileId,
    required String profileType,
    required String profileName,
    int? listPosition,
  }) async {
    await analytics?.logProfileClicked(
      profileId: profileId,
      profileType: profileType,
      profileName: profileName,
      listPosition: listPosition,
      source: currentScreenName,
    );
  }

  /// Track subcategory click with context
  Future<void> trackSubcategoryClick({
    required String subcategoryId,
    required String subcategoryName,
    required String parentCategory,
  }) async {
    await analytics?.logSubcategoryClicked(
      subcategoryId: subcategoryId,
      subcategoryName: subcategoryName,
      parentCategory: parentCategory,
    );
  }
}
