import 'package:flutter/material.dart';
import 'package:exanor/services/performance_service.dart';
import 'dart:developer' as developer;

/// Extension to add route names to MaterialPageRoute for better performance tracking
extension RouteNaming on MaterialPageRoute {
  /// Create a MaterialPageRoute with a custom name for performance tracking
  static MaterialPageRoute<T> withName<T>(
    String name,
    Widget Function(BuildContext) builder, {
    RouteSettings? settings,
  }) {
    return MaterialPageRoute<T>(
      builder: builder,
      settings: RouteSettings(name: name, arguments: settings?.arguments),
    );
  }
}

/// Widget that tracks navigation performance
class NavigationPerformanceTracker extends StatefulWidget {
  final Widget child;
  final String screenName;
  final Map<String, String>? additionalAttributes;

  const NavigationPerformanceTracker({
    Key? key,
    required this.child,
    required this.screenName,
    this.additionalAttributes,
  }) : super(key: key);

  @override
  State<NavigationPerformanceTracker> createState() =>
      _NavigationPerformanceTrackerState();
}

class _NavigationPerformanceTrackerState
    extends State<NavigationPerformanceTracker> {
  late final String _traceId;
  bool _hasStartedTrace = false;

  @override
  void initState() {
    super.initState();
    _traceId = 'exanor_screen_${widget.screenName}';
    _startScreenTrace();
  }

  Future<void> _startScreenTrace() async {
    try {
      await PerformanceService.instance.startTrace(_traceId);
      await PerformanceService.instance.addTraceAttribute(
        _traceId,
        'screen_name',
        widget.screenName,
      );
      await PerformanceService.instance.addTraceAttribute(
        _traceId,
        'category',
        'screen_load',
      );

      // Add additional attributes if provided
      if (widget.additionalAttributes != null) {
        for (final entry in widget.additionalAttributes!.entries) {
          await PerformanceService.instance.addTraceAttribute(
            _traceId,
            entry.key,
            entry.value,
          );
        }
      }

      setState(() {
        _hasStartedTrace = true;
      });

      developer.log(
        '📊 Started screen trace: ${widget.screenName}',
        name: 'NavigationPerformance',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to start screen trace: $e',
        name: 'NavigationPerformance',
      );
    }
  }

  @override
  void dispose() {
    _stopScreenTrace();
    super.dispose();
  }

  Future<void> _stopScreenTrace() async {
    if (_hasStartedTrace) {
      try {
        await PerformanceService.instance.addTraceAttribute(
          _traceId,
          'screen_disposed',
          'true',
        );
        await PerformanceService.instance.stopTrace(_traceId);

        developer.log(
          '📊 Stopped screen trace: ${widget.screenName}',
          name: 'NavigationPerformance',
        );
      } catch (e) {
        developer.log(
          '❌ Failed to stop screen trace: $e',
          name: 'NavigationPerformance',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Mixin that provides navigation performance tracking capabilities
mixin NavigationPerformanceMixin<T extends StatefulWidget> on State<T> {
  final PerformanceService _performanceService = PerformanceService.instance;

  /// Track navigation between screens
  Future<void> trackNavigation(String fromScreen, String toScreen) async {
    await _performanceService.traceScreenNavigation(fromScreen, toScreen);
  }

  /// Track screen transition with custom attributes
  Future<void> trackScreenTransition(
    String fromScreen,
    String toScreen, {
    Map<String, String>? attributes,
  }) async {
    final traceName = 'exanor_transition_${fromScreen}_to_$toScreen';
    await _performanceService.traceOperation(
      traceName,
      () async {
        // Transition timing is handled automatically by the trace
        await Future.delayed(Duration.zero);
      },
      attributes: {
        'from_screen': fromScreen,
        'to_screen': toScreen,
        'category': 'navigation',
        'app': 'exanor',
        if (attributes != null) ...attributes,
      },
    );
  }

  /// Track route performance
  Future<T?> trackRoute<T extends Object?>(
    String routeName,
    Future<T?> Function() navigationOperation,
  ) async {
    return await _performanceService.traceOperation(
      'route_$routeName',
      navigationOperation,
      attributes: {'route_name': routeName, 'category': 'navigation'},
    );
  }
}

/// Navigator observer that tracks navigation performance
class NavigationPerformanceObserver extends NavigatorObserver {
  final PerformanceService _performanceService = PerformanceService.instance;
  final Map<Route<dynamic>, String> _routeTraces = {};

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackRouteNavigation(route, previousRoute, 'push');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _trackRouteNavigation(route, previousRoute, 'pop');
    _cleanupRouteTrace(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null && oldRoute != null) {
      _trackRouteNavigation(newRoute, oldRoute, 'replace');
    }
    if (oldRoute != null) {
      _cleanupRouteTrace(oldRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _cleanupRouteTrace(route);
  }

  void _trackRouteNavigation(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
    String operation,
  ) {
    final routeName = _getRouteName(route);
    final previousRouteName = previousRoute != null
        ? _getRouteName(previousRoute)
        : 'none';

    // Start trace for the route with cleaner naming
    final cleanRouteName = _cleanRouteName(routeName);
    final traceId = 'exanor_${operation}_$cleanRouteName';
    _routeTraces[route] = traceId;

    _performanceService
        .traceOperation(
          traceId,
          () async {
            await Future.delayed(Duration.zero);
          },
          attributes: {
            'route_name': routeName,
            'previous_route': previousRouteName,
            'operation': operation,
            'category': 'navigation',
            'app': 'exanor',
          },
        )
        .catchError((error) {
          developer.log(
            '❌ Failed to track navigation: $error',
            name: 'NavigationPerformance',
          );
        });

    developer.log(
      '📊 Navigation tracked: $operation from $previousRouteName to $routeName',
      name: 'NavigationPerformance',
    );
  }

  void _cleanupRouteTrace(Route<dynamic> route) {
    final traceId = _routeTraces.remove(route);
    if (traceId != null) {
      // The trace should already be completed by the traceOperation method
      developer.log(
        '🧹 Cleaned up trace for route: ${_getRouteName(route)}',
        name: 'NavigationPerformance',
      );
    }
  }

  String _getRouteName(Route<dynamic> route) {
    // First check if the route has a name
    if (route.settings.name != null) {
      return route.settings.name!.replaceAll('/', '');
    }

    // Try to extract screen name from MaterialPageRoute
    if (route is MaterialPageRoute) {
      try {
        // Get the widget type from the route
        final String routeStr = route.toString();

        // Try to extract screen name from the route string
        // Look for patterns like "MaterialPageRoute<dynamic>(builder: (context) => ScreenName()"
        final RegExp screenNameRegex = RegExp(r'(\w+Screen|\w+Page)');
        final Match? match = screenNameRegex.firstMatch(routeStr);

        if (match != null) {
          return match.group(1)!;
        }
      } catch (e) {
        developer.log(
          '⚠️ Could not extract screen name from MaterialPageRoute: $e',
          name: 'NavigationPerformance',
        );
      }
    }

    // Try to extract from route arguments if available
    if (route.settings.arguments != null) {
      try {
        final args = route.settings.arguments;
        if (args is Map<String, dynamic> && args.containsKey('screenName')) {
          return args['screenName'].toString();
        }
      } catch (e) {
        developer.log(
          '⚠️ Could not extract screen name from route arguments: $e',
          name: 'NavigationPerformance',
        );
      }
    }

    // Fallback to a simplified version of the route type
    final String routeType = route.runtimeType.toString();
    return routeType.replaceAll('<dynamic>', '').replaceAll('Route', '');
  }

  String _cleanRouteName(String routeName) {
    // Remove common prefixes and suffixes to make trace names cleaner
    String cleaned = routeName
        .replaceAll('Screen', '')
        .replaceAll('Page', '')
        .replaceAll('Route', '')
        .replaceAll('_', '')
        .toLowerCase();

    // Handle special cases for your app's screens
    final Map<String, String> screenMappings = {
      'splashscreen': 'splash',
      'onboardingscreen': 'onboarding',
      'phoneregistrationscreen': 'phone_register',
      'otpverificationscreen': 'otp_verify',
      'userdetailsscreen': 'user_details',
      'notificationpermissionscreen': 'notification_permission',
      'myprofilescreen': 'my_profile',
      'chatscreen': 'chat',
      'subscriptiondetailsscreen': 'subscription',
      'mybusinessesscreen': 'my_businesses',
      'referandearnscreen': 'refer_earn',
      'myemployeeprofileonboardingscreen': 'employee_onboarding',
      'myprofessionalprofileonboardingscreen': 'professional_onboarding',
      'mybusinessprofileonboardingscreen': 'business_onboarding',
      'userprofileeditablescreen': 'profile_edit',
      'homescreen': 'home',
      'searchscreen': 'search',
      'materialpage': 'unknown_page',
    };

    return screenMappings[cleaned] ?? cleaned;
  }
}

/// Extension on Navigator to add performance tracking
extension NavigatorPerformanceExtension on NavigatorState {
  /// Push with performance tracking
  Future<T?> pushWithPerformanceTracking<T extends Object?>(
    Route<T> route, {
    String? customName,
  }) async {
    final routeName = customName ?? route.settings.name ?? 'unknown_route';

    return await PerformanceService.instance.traceOperation(
      'navigation_push_$routeName',
      () async {
        return await push(route);
      },
      attributes: {
        'route_name': routeName,
        'operation': 'push',
        'category': 'navigation',
      },
    );
  }

  /// Push named with performance tracking
  Future<T?> pushNamedWithPerformanceTracking<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) async {
    return await PerformanceService.instance.traceOperation(
      'navigation_push_named_$routeName',
      () async {
        return await pushNamed<T>(routeName, arguments: arguments);
      },
      attributes: {
        'route_name': routeName,
        'operation': 'push_named',
        'category': 'navigation',
        'has_arguments': arguments != null ? 'true' : 'false',
      },
    );
  }

  /// Push replacement with performance tracking
  Future<T?> pushReplacementWithPerformanceTracking<
    T extends Object?,
    TO extends Object?
  >(Route<T> newRoute, {TO? result, String? customName}) async {
    final routeName = customName ?? newRoute.settings.name ?? 'unknown_route';

    return await PerformanceService.instance.traceOperation(
      'navigation_push_replacement_$routeName',
      () async {
        return await pushReplacement(newRoute, result: result);
      },
      attributes: {
        'route_name': routeName,
        'operation': 'push_replacement',
        'category': 'navigation',
      },
    );
  }

  /// Push and remove until with performance tracking
  Future<T?> pushNamedAndRemoveUntilWithPerformanceTracking<T extends Object?>(
    String newRouteName,
    RoutePredicate predicate, {
    Object? arguments,
  }) async {
    return await PerformanceService.instance.traceOperation(
      'navigation_push_and_remove_until_$newRouteName',
      () async {
        return await pushNamedAndRemoveUntil<T>(
          newRouteName,
          predicate,
          arguments: arguments,
        );
      },
      attributes: {
        'route_name': newRouteName,
        'operation': 'push_and_remove_until',
        'category': 'navigation',
        'has_arguments': arguments != null ? 'true' : 'false',
      },
    );
  }
}

/// Utility class for navigation performance tracking
class NavigationPerformanceUtils {
  static final PerformanceService _performanceService =
      PerformanceService.instance;

  /// Track custom navigation event
  static Future<void> trackCustomNavigation(
    String eventName, {
    Map<String, String>? attributes,
  }) async {
    await _performanceService.traceOperation(
      'custom_navigation_$eventName',
      () async {
        await Future.delayed(Duration.zero);
      },
      attributes: {
        'event_name': eventName,
        'category': 'navigation',
        if (attributes != null) ...attributes,
      },
    );
  }

  /// Track modal or dialog performance
  static Future<T?> trackModalNavigation<T>(
    String modalName,
    Future<T?> Function() showModalOperation,
  ) async {
    return await _performanceService.traceOperation(
      'exanor_modal_$modalName',
      showModalOperation,
      attributes: {
        'modal_name': modalName,
        'category': 'navigation',
        'type': 'modal',
      },
    );
  }

  /// Track bottom sheet performance
  static Future<T?> trackBottomSheetNavigation<T>(
    String bottomSheetName,
    Future<T?> Function() showBottomSheetOperation,
  ) async {
    return await _performanceService.traceOperation(
      'exanor_bottomsheet_$bottomSheetName',
      showBottomSheetOperation,
      attributes: {
        'bottom_sheet_name': bottomSheetName,
        'category': 'navigation',
        'type': 'bottom_sheet',
      },
    );
  }

  /// Track tab navigation performance
  static Future<void> trackTabNavigation(String fromTab, String toTab) async {
    await _performanceService.traceOperation(
      'exanor_tab_${fromTab}_to_$toTab',
      () async {
        await Future.delayed(Duration.zero);
      },
      attributes: {
        'from_tab': fromTab,
        'to_tab': toTab,
        'category': 'navigation',
        'type': 'tab',
      },
    );
  }
}
