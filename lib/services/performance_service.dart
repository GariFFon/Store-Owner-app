import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';

/// Service to manage Firebase Performance monitoring
class PerformanceService {
  static PerformanceService? _instance;
  static PerformanceService get instance =>
      _instance ??= PerformanceService._internal();

  PerformanceService._internal();

  FirebasePerformance? _performance;
  bool _isInitialized = false;
  final Map<String, Trace> _activeTraces = {};
  final Map<String, HttpMetric> _activeHttpMetrics = {};
  final Map<String, DateTime> _screenStartTimes = {};

  // Screen rendering monitoring
  int _slowFrameCount = 0;
  int _frozenFrameCount = 0;
  bool _frameTimingEnabled = false;

  /// Get FirebasePerformance instance with lazy initialization
  FirebasePerformance? get _performanceInstance {
    if (!_isInitialized) {
      try {
        // Check if Firebase is initialized
        if (Firebase.apps.isNotEmpty) {
          _performance = FirebasePerformance.instance;
          _isInitialized = true;
        } else {
          developer.log(
            'Firebase not initialized yet, performance monitoring disabled',
            name: 'PerformanceService',
          );
          return null;
        }
      } catch (e) {
        developer.log(
          'Failed to initialize Firebase Performance: $e',
          name: 'PerformanceService',
        );
        return null;
      }
    }
    return _performance;
  }

  /// Check if performance monitoring is enabled
  bool get isEnabled {
    // Always enable in debug mode for testing, rely on Firebase settings in production
    return _performanceInstance != null;
  }

  /// Check if performance collection is enabled using Firebase API
  Future<bool> get isPerformanceCollectionEnabled async {
    try {
      if (_performanceInstance == null) return false;
      return await _performanceInstance!.isPerformanceCollectionEnabled();
    } catch (e) {
      developer.log(
        'Failed to check performance collection status: $e',
        name: 'PerformanceService',
      );
      return false;
    }
  }

  /// Toggle performance collection using Firebase API
  Future<void> togglePerformanceCollection() async {
    try {
      if (_performanceInstance == null) return;

      final currentStatus = await _performanceInstance!
          .isPerformanceCollectionEnabled();
      await _performanceInstance!.setPerformanceCollectionEnabled(
        !currentStatus,
      );

      final newStatus = await _performanceInstance!
          .isPerformanceCollectionEnabled();
      developer.log(
        'Performance collection toggled to: ${newStatus ? 'enabled' : 'disabled'}',
        name: 'PerformanceService',
      );
    } catch (e) {
      developer.log(
        'Failed to toggle performance collection: $e',
        name: 'PerformanceService',
      );
    }
  }

  /// Initialize the service (safe to call multiple times)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Ensure Firebase is initialized
      if (Firebase.apps.isEmpty) {
        developer.log(
          'Firebase not initialized, skipping performance service initialization',
          name: 'PerformanceService',
        );
        return;
      }

      _performance = FirebasePerformance.instance;
      _isInitialized = true;

      // Configure performance collection based on build mode
      if (kDebugMode) {
        // In debug mode, enable for testing but can be toggled
        await _performance!.setPerformanceCollectionEnabled(true);
        developer.log(
          'Debug mode: Performance collection enabled for testing',
          name: 'PerformanceService',
        );
      } else {
        // In production, always enable
        await _performance!.setPerformanceCollectionEnabled(true);
        developer.log(
          'Production mode: Performance collection enabled',
          name: 'PerformanceService',
        );
      }

      // Initialize screen rendering monitoring
      _initializeScreenRenderingMonitoring();

      developer.log(
        'Firebase Performance service initialized successfully',
        name: 'PerformanceService',
      );

      // Log performance collection status
      final isEnabled = await _performance!.isPerformanceCollectionEnabled();
      developer.log(
        'Performance collection enabled: $isEnabled',
        name: 'PerformanceService',
      );
    } catch (e) {
      developer.log(
        'Failed to initialize Firebase Performance service: $e',
        name: 'PerformanceService',
      );
      _performance = null;
      _isInitialized = false;
    }
  }

  /// Initialize screen rendering monitoring
  void _initializeScreenRenderingMonitoring() {
    if (!isEnabled) return;

    try {
      _frameTimingEnabled = true;
      // Use SchedulerBinding to monitor frame performance
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _startFrameMonitoring();
      });
    } catch (e) {
      developer.log(
        'Failed to initialize screen rendering monitoring: $e',
        name: 'PerformanceService',
      );
    }
  }

  /// Start frame monitoring using SchedulerBinding
  void _startFrameMonitoring() {
    if (!_frameTimingEnabled) return;

    // Simple frame monitoring - increment counters based on frame callback timing
    final frameStart = DateTime.now();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_frameTimingEnabled) {
        final frameDuration = DateTime.now()
            .difference(frameStart)
            .inMilliseconds;

        // Consider frames over 16ms as slow (60fps = 16.67ms per frame)
        if (frameDuration > 16) {
          _slowFrameCount++;

          // Consider frames over 100ms as frozen
          if (frameDuration > 100) {
            _frozenFrameCount++;
          }
        }

        // Continue monitoring
        _startFrameMonitoring();
      }
    });
  }

  // ==================== NETWORK REQUEST TRACES ====================

  /// Create and start HTTP metric for network requests
  Future<HttpMetric> startNetworkTrace(
    String url,
    HttpMethod method, {
    Map<String, String>? headers,
    int? requestSize,
  }) async {
    if (!isEnabled) {
      return _DummyHttpMetric(url, method);
    }

    try {
      final metric = _performanceInstance!.newHttpMetric(url, method);

      // Set request payload size if provided
      if (requestSize != null) {
        metric.requestPayloadSize = requestSize;
      }

      // Add custom attributes
      metric.putAttribute('url_pattern', _getUrlPattern(url));
      metric.putAttribute('method', method.name);

      await metric.start();
      _activeHttpMetrics[url] = metric;

      developer.log(
        'Started network trace: ${method.name} $url',
        name: 'PerformanceService',
      );

      return metric;
    } catch (e) {
      developer.log(
        'Failed to start network trace: $e',
        name: 'PerformanceService',
      );
      return _DummyHttpMetric(url, method);
    }
  }

  /// Complete network trace with response details
  Future<void> completeNetworkTrace(
    String url,
    int statusCode,
    int? responseSize,
    String? contentType,
  ) async {
    if (!isEnabled || !_activeHttpMetrics.containsKey(url)) return;

    try {
      final metric = _activeHttpMetrics.remove(url);
      if (metric != null) {
        metric.httpResponseCode = statusCode;
        metric.responsePayloadSize = responseSize;
        metric.responseContentType = contentType;

        // Add success/failure attribute
        metric.putAttribute('success', statusCode < 400 ? 'true' : 'false');

        // Add error category for failed requests
        if (statusCode >= 400) {
          if (statusCode >= 500) {
            metric.putAttribute('error_category', 'server_error');
          } else {
            metric.putAttribute('error_category', 'client_error');
          }
        }

        await metric.stop();

        developer.log(
          'Completed network trace: $url - Status: $statusCode',
          name: 'PerformanceService',
        );
      }
    } catch (e) {
      developer.log(
        'Failed to complete network trace: $e',
        name: 'PerformanceService',
      );
    }
  }

  /// Get URL pattern for grouping similar requests
  String _getUrlPattern(String url) {
    // Replace IDs and dynamic parts with placeholders
    String pattern = url;

    // Replace UUIDs
    pattern = pattern.replaceAll(
      RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'),
      '{uuid}',
    );

    // Replace numeric IDs
    pattern = pattern.replaceAll(RegExp(r'/\d+(/|$)'), '/{id}\$1');

    // Replace query parameters
    pattern = pattern.replaceAll(RegExp(r'\?.*'), '?{query}');

    return pattern;
  }

  // ==================== CUSTOM TRACES ====================

  /// Start a custom trace with enhanced attributes
  Future<void> startCustomTrace(
    String traceName, {
    String? category,
    Map<String, String>? attributes,
  }) async {
    if (!isEnabled || _activeTraces.containsKey(traceName)) return;

    try {
      final trace = _performanceInstance!.newTrace(traceName);

      // Add category if provided
      if (category != null) {
        trace.putAttribute('category', category);
      }

      // Add custom attributes
      if (attributes != null) {
        for (final entry in attributes.entries) {
          trace.putAttribute(entry.key, entry.value);
        }
      }

      await trace.start();
      _activeTraces[traceName] = trace;

      developer.log(
        'Started custom trace: $traceName',
        name: 'PerformanceService',
      );
    } catch (e) {
      developer.log(
        'Failed to start custom trace $traceName: $e',
        name: 'PerformanceService',
      );
    }
  }

  /// Complete custom trace with metrics
  Future<void> completeCustomTrace(
    String traceName, {
    Map<String, int>? metrics,
    Map<String, String>? finalAttributes,
  }) async {
    if (!isEnabled || !_activeTraces.containsKey(traceName)) return;

    try {
      final trace = _activeTraces.remove(traceName);
      if (trace != null) {
        // Add final attributes
        if (finalAttributes != null) {
          for (final entry in finalAttributes.entries) {
            trace.putAttribute(entry.key, entry.value);
          }
        }

        // Add metrics
        if (metrics != null) {
          for (final entry in metrics.entries) {
            trace.setMetric(entry.key, entry.value);
          }
        }

        await trace.stop();

        developer.log(
          'Completed custom trace: $traceName',
          name: 'PerformanceService',
        );
      }
    } catch (e) {
      developer.log(
        'Failed to complete custom trace $traceName: $e',
        name: 'PerformanceService',
      );
    }
  }

  /// Trace app startup with comprehensive metrics
  Future<void> traceAppStartup() async {
    if (!_isInitialized && Firebase.apps.isEmpty) {
      developer.log(
        'Deferring app startup trace until Firebase is initialized',
        name: 'PerformanceService',
      );
      return;
    }

    await startCustomTrace(
      'exanor_app_startup',
      category: 'lifecycle',
      attributes: {
        'app_version': '1.0.0', // You can get this from package_info
        'platform': defaultTargetPlatform.name,
      },
    );
  }

  /// Complete app startup trace with metrics
  Future<void> completeAppStartupTrace() async {
    await completeCustomTrace(
      'exanor_app_startup',
      finalAttributes: {
        'startup_complete': 'true',
        'initialization_status': 'success',
      },
    );
  }

  // ==================== SCREEN RENDERING TRACES ====================

  /// Start screen rendering trace
  Future<void> startScreenTrace(String screenName) async {
    if (!isEnabled) return;

    _screenStartTimes[screenName] = DateTime.now();

    await startCustomTrace(
      'screen_$screenName',
      category: 'screen_rendering',
      attributes: {'screen_name': screenName, 'screen_type': 'flutter_screen'},
    );
  }

  /// Complete screen rendering trace with performance metrics
  Future<void> completeScreenTrace(String screenName) async {
    if (!isEnabled || !_screenStartTimes.containsKey(screenName)) return;

    final startTime = _screenStartTimes.remove(screenName);
    if (startTime != null) {
      final loadTime = DateTime.now().difference(startTime).inMilliseconds;

      await completeCustomTrace(
        'screen_$screenName',
        metrics: {
          'load_time_ms': loadTime,
          'slow_frames': _slowFrameCount,
          'frozen_frames': _frozenFrameCount,
        },
        finalAttributes: {
          'performance_category': loadTime > 1000 ? 'slow' : 'fast',
        },
      );

      // Reset frame counters for next screen
      _slowFrameCount = 0;
      _frozenFrameCount = 0;
    }
  }

  /// Monitor screen navigation performance
  Future<void> traceScreenNavigation(String fromScreen, String toScreen) async {
    final traceName = 'navigation_${fromScreen}_to_$toScreen';

    await startCustomTrace(
      traceName,
      category: 'navigation',
      attributes: {
        'from_screen': fromScreen,
        'to_screen': toScreen,
        'navigation_type': 'push',
      },
    );

    // Complete after a short delay to capture navigation time
    Future.delayed(const Duration(milliseconds: 100), () {
      completeCustomTrace(
        traceName,
        finalAttributes: {'navigation_status': 'completed'},
      );
    });
  }

  // ==================== PREDEFINED OPERATION TRACES ====================

  /// Simple API call tracing (backward compatible)
  Future<T> traceApiCall<T>(
    String endpoint,
    Future<T> Function() apiCall,
  ) async {
    return await traceOperation(
      'api_call_$endpoint',
      apiCall,
      attributes: {'endpoint': endpoint, 'category': 'api'},
    );
  }

  /// Enhanced API call tracing with network metrics
  Future<T> traceApiCallWithMetrics<T>(
    String endpoint,
    HttpMethod method,
    Future<T> Function() apiCall, {
    Map<String, String>? headers,
    int? requestSize,
  }) async {
    final url = endpoint.startsWith('http')
        ? endpoint
        : 'https://api.example.com$endpoint';
    final metric = await startNetworkTrace(
      url,
      method,
      requestSize: requestSize,
    );

    try {
      final result = await apiCall();

      // Assume success if no exception
      await completeNetworkTrace(url, 200, null, 'application/json');

      return result;
    } catch (e) {
      // Handle different error types
      int statusCode = 500;
      if (e.toString().contains('401')) statusCode = 401;
      if (e.toString().contains('403')) statusCode = 403;
      if (e.toString().contains('404')) statusCode = 404;

      await completeNetworkTrace(url, statusCode, null, null);
      rethrow;
    }
  }

  /// Enhanced authentication tracing
  Future<T> traceAuthentication<T>(
    String authType,
    Future<T> Function() authOperation,
  ) async {
    await startCustomTrace(
      'auth_$authType',
      category: 'authentication',
      attributes: {'auth_type': authType, 'auth_method': authType},
    );

    try {
      final result = await authOperation();

      await completeCustomTrace(
        'auth_$authType',
        finalAttributes: {'auth_status': 'success'},
      );

      return result;
    } catch (e) {
      await completeCustomTrace(
        'auth_$authType',
        finalAttributes: {
          'auth_status': 'failed',
          'error_type': e.runtimeType.toString(),
        },
      );
      rethrow;
    }
  }

  /// Enhanced database operation tracing
  Future<T> traceDatabaseOperation<T>(
    String operation,
    Future<T> Function() dbOperation,
  ) async {
    await startCustomTrace(
      'db_$operation',
      category: 'database',
      attributes: {
        'operation': operation,
        'db_type': 'firestore', // or your database type
      },
    );

    try {
      final result = await dbOperation();

      await completeCustomTrace(
        'db_$operation',
        finalAttributes: {'db_status': 'success'},
      );

      return result;
    } catch (e) {
      await completeCustomTrace(
        'db_$operation',
        finalAttributes: {
          'db_status': 'failed',
          'error_type': e.runtimeType.toString(),
        },
      );
      rethrow;
    }
  }

  /// Trace image loading
  Future<T> traceImageLoad<T>(
    String imageUrl,
    Future<T> Function() loadOperation,
  ) async {
    return await traceOperation(
      'image_load',
      loadOperation,
      attributes: {
        'image_url': imageUrl.length > 100
            ? '${imageUrl.substring(0, 100)}...'
            : imageUrl,
        'category': 'media',
      },
    );
  }

  /// Trace translation operations
  Future<T> traceTranslation<T>(
    String fromLang,
    String toLang,
    Future<T> Function() translationOperation,
  ) async {
    return await traceOperation(
      'translation_${fromLang}_to_$toLang',
      translationOperation,
      attributes: {
        'from_language': fromLang,
        'to_language': toLang,
        'category': 'translation',
      },
    );
  }

  /// Trace an operation with automatic start/stop
  Future<T> traceOperation<T>(
    String traceName,
    Future<T> Function() operation, {
    String? category,
    Map<String, String>? attributes,
  }) async {
    if (!isEnabled) {
      // If performance monitoring is disabled, just run the operation
      return await operation();
    }

    await startCustomTrace(
      traceName,
      category: category,
      attributes: attributes,
    );

    try {
      final result = await operation();
      await completeCustomTrace(
        traceName,
        finalAttributes: {'status': 'success'},
      );
      return result;
    } catch (e) {
      await completeCustomTrace(
        traceName,
        finalAttributes: {
          'status': 'error',
          'error_type': e.runtimeType.toString(),
        },
      );
      rethrow;
    }
  }

  /// Start a basic trace (simpler version for backward compatibility)
  Future<void> startTrace(String traceName) async {
    await startCustomTrace(traceName);
  }

  /// Stop a basic trace (simpler version for backward compatibility)
  Future<void> stopTrace(String traceName) async {
    await completeCustomTrace(traceName);
  }

  /// Add attribute to a trace
  Future<void> addTraceAttribute(
    String traceName,
    String key,
    String value,
  ) async {
    if (!isEnabled || !_activeTraces.containsKey(traceName)) return;

    try {
      _activeTraces[traceName]?.putAttribute(key, value);
    } catch (e) {
      developer.log(
        'Failed to add attribute to trace $traceName: $e',
        name: 'PerformanceService',
      );
    }
  }

  /// Add metric to a trace
  Future<void> addTraceMetric(
    String traceName,
    String metricName,
    int value,
  ) async {
    if (!isEnabled || !_activeTraces.containsKey(traceName)) return;

    try {
      _activeTraces[traceName]?.setMetric(metricName, value);
    } catch (e) {
      developer.log(
        'Failed to add metric to trace $traceName: $e',
        name: 'PerformanceService',
      );
    }
  }

  /// Set metric on a trace (alias for addTraceMetric)
  Future<void> setTraceMetric(
    String traceName,
    String metricName,
    int value,
  ) async {
    await addTraceMetric(traceName, metricName, value);
  }

  /// Create HTTP metric for API calls
  HttpMetric createHttpMetric(String url, HttpMethod method) {
    if (!isEnabled) {
      return _DummyHttpMetric(url, method);
    }

    try {
      return _performanceInstance!.newHttpMetric(url, method);
    } catch (e) {
      developer.log(
        '❌ Failed to create HTTP metric for $url: $e',
        name: 'PerformanceService',
      );
      return _DummyHttpMetric(url, method);
    }
  }

  /// Monitor an HTTP request with automatic metrics
  Future<http.Response> monitorHttpRequest(
    Future<http.Response> Function() request,
    String url,
    HttpMethod method,
  ) async {
    if (!isEnabled) {
      return await request();
    }

    final metric = createHttpMetric(url, method);

    try {
      await metric.start();
      final response = await request();

      // Set response metrics
      metric.httpResponseCode = response.statusCode;
      metric.responsePayloadSize = response.contentLength;
      metric.responseContentType = response.headers['content-type'];

      // Add custom attributes
      metric.putAttribute(
        'success',
        response.statusCode < 400 ? 'true' : 'false',
      );

      developer.log(
        '🌐 HTTP request monitored: $url - Status: ${response.statusCode}',
        name: 'PerformanceService',
      );

      return response;
    } catch (e) {
      metric.putAttribute('error', e.runtimeType.toString());
      rethrow;
    } finally {
      await metric.stop();
    }
  }

  /// Get comprehensive performance summary
  Map<String, dynamic> getPerformanceSummary() {
    return {
      'active_traces': _activeTraces.keys.toList(),
      'active_http_metrics': _activeHttpMetrics.keys.toList(),
      'active_screen_traces': _screenStartTimes.keys.toList(),
      'trace_count': _activeTraces.length,
      'http_metric_count': _activeHttpMetrics.length,
      'screen_trace_count': _screenStartTimes.length,
      'slow_frame_count': _slowFrameCount,
      'frozen_frame_count': _frozenFrameCount,
      'is_enabled': isEnabled,
      'is_initialized': _isInitialized,
      'firebase_apps_count': Firebase.apps.length,
    };
  }

  /// Dispose of resources
  void dispose() {
    _frameTimingEnabled = false;
    _activeTraces.clear();
    _activeHttpMetrics.clear();
    _screenStartTimes.clear();
  }
}

/// Dummy trace for debug mode to avoid crashes
class _DummyTrace implements Trace {
  final String _name;
  final Map<String, String> _attributes = {};
  final Map<String, int> _metrics = {};

  _DummyTrace(this._name);

  @override
  Future<void> start() async {
    developer.log('Dummy trace started: $_name', name: 'PerformanceService');
  }

  @override
  Future<void> stop() async {
    developer.log('Dummy trace stopped: $_name', name: 'PerformanceService');
  }

  @override
  void putAttribute(String name, String value) {
    _attributes[name] = value;
    developer.log(
      'Dummy trace attribute: $_name.$name = $value',
      name: 'PerformanceService',
    );
  }

  @override
  String? getAttribute(String name) => _attributes[name];

  @override
  Map<String, String> getAttributes() => Map.from(_attributes);

  @override
  void removeAttribute(String name) {
    _attributes.remove(name);
    developer.log(
      'Dummy trace removed attribute: $_name.$name',
      name: 'PerformanceService',
    );
  }

  @override
  void setMetric(String name, int value) {
    _metrics[name] = value;
    developer.log(
      'Dummy trace metric: $_name.$name = $value',
      name: 'PerformanceService',
    );
  }

  @override
  int getMetric(String name) => _metrics[name] ?? 0;

  @override
  void incrementMetric(String name, int value) {
    _metrics[name] = (_metrics[name] ?? 0) + value;
    developer.log(
      'Dummy trace incremented metric: $_name.$name by $value',
      name: 'PerformanceService',
    );
  }
}

/// Dummy HTTP metric for debug mode to avoid crashes
class _DummyHttpMetric implements HttpMetric {
  final String _url;
  final HttpMethod _method;
  final Map<String, String> _attributes = {};

  int? _httpResponseCode;
  int? _requestPayloadSize;
  String? _responseContentType;
  int? _responsePayloadSize;

  _DummyHttpMetric(this._url, this._method);

  @override
  Future<void> start() async {
    developer.log(
      'Dummy HTTP metric started: ${_method.name} $_url',
      name: 'PerformanceService',
    );
  }

  @override
  Future<void> stop() async {
    developer.log(
      'Dummy HTTP metric stopped: ${_method.name} $_url',
      name: 'PerformanceService',
    );
  }

  @override
  void putAttribute(String name, String value) {
    _attributes[name] = value;
    developer.log(
      'Dummy HTTP metric attribute: $_url.$name = $value',
      name: 'PerformanceService',
    );
  }

  @override
  String? getAttribute(String name) => _attributes[name];

  @override
  Map<String, String> getAttributes() => Map.from(_attributes);

  @override
  void removeAttribute(String name) {
    _attributes.remove(name);
    developer.log(
      'Dummy HTTP metric removed attribute: $_url.$name',
      name: 'PerformanceService',
    );
  }

  @override
  int? get httpResponseCode => _httpResponseCode;

  @override
  set httpResponseCode(int? httpResponseCode) {
    _httpResponseCode = httpResponseCode;
    developer.log(
      'Dummy HTTP metric response code: $_url = $httpResponseCode',
      name: 'PerformanceService',
    );
  }

  @override
  int? get requestPayloadSize => _requestPayloadSize;

  @override
  set requestPayloadSize(int? requestPayloadSize) {
    _requestPayloadSize = requestPayloadSize;
    developer.log(
      'Dummy HTTP metric request size: $_url = $requestPayloadSize',
      name: 'PerformanceService',
    );
  }

  @override
  String? get responseContentType => _responseContentType;

  @override
  set responseContentType(String? responseContentType) {
    _responseContentType = responseContentType;
    developer.log(
      'Dummy HTTP metric content type: $_url = $responseContentType',
      name: 'PerformanceService',
    );
  }

  @override
  int? get responsePayloadSize => _responsePayloadSize;

  @override
  set responsePayloadSize(int? responsePayloadSize) {
    _responsePayloadSize = responsePayloadSize;
    developer.log(
      'Dummy HTTP metric response size: $_url = $responsePayloadSize',
      name: 'PerformanceService',
    );
  }
}

// Production-ready Firebase Performance Service - all test examples removed
