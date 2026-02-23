import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/services/performance_service.dart';
import 'package:firebase_performance/firebase_performance.dart'
    as firebase_perf;

// HTTP Methods enum for better type safety
enum HttpMethod { get, post, put, delete, patch }

class ApiService {
  // Default URLs (fallback values)
  static const String _defaultBaseUrl =
      'https://development.api.exanor.com/api/v1';
  static const String _defaultBareBaseUrl =
      'https://development.api.exanor.com';
  static const int _defaultTimeoutSeconds = 30;

  // Cached values (initialized once)
  static String? _cachedBaseUrl;
  static String? _cachedBareBaseUrl;
  static int? _cachedTimeoutSeconds;
  static bool _isConfigurationCached = false;

  // Secure storage instance
  static const _secureStorage = FlutterSecureStorage();

  /// Initialize API configuration (call once during app startup)
  static Future<void> initializeConfiguration() async {
    try {
      _log('🔧 Initializing API configuration...');

      // Try to get values from Firebase Remote Config
      if (FirebaseRemoteConfigService.isInitialized) {
        _log('🔥 Using Firebase Remote Config values...');
        _cachedBaseUrl = FirebaseRemoteConfigService.getBaseUrl();
        _cachedBareBaseUrl = FirebaseRemoteConfigService.getBareBaseUrl();
        _cachedTimeoutSeconds = FirebaseRemoteConfigService.getApiTimeout();

        _log('📍 Firebase Remote Config values:');
        _log('   📍 Base URL: $_cachedBaseUrl');
        _log('   📍 Bare Base URL: $_cachedBareBaseUrl');
        _log('   ⏰ Timeout: ${_cachedTimeoutSeconds}s');
      } else {
        _log('⚠️ Firebase Remote Config not initialized, using default values');
        _cachedBaseUrl = _defaultBaseUrl;
        _cachedBareBaseUrl = _defaultBareBaseUrl;
        _cachedTimeoutSeconds = _defaultTimeoutSeconds;

        _log('📍 Using default values:');
        _log('   📍 Base URL: $_cachedBaseUrl');
        _log('   📍 Bare Base URL: $_cachedBareBaseUrl');
        _log('   ⏰ Timeout: ${_cachedTimeoutSeconds}s');
      }

      _isConfigurationCached = true;
      _log('✅ API configuration initialized successfully');
    } catch (e) {
      _log('❌ Error initializing API configuration: $e');
      // Fallback to defaults
      _cachedBaseUrl = _defaultBaseUrl;
      _cachedBareBaseUrl = _defaultBareBaseUrl;
      _cachedTimeoutSeconds = _defaultTimeoutSeconds;
      _isConfigurationCached = true;

      _log('📍 Fallback to default values due to error');
    }
  }

  /// Refresh cached configuration
  static Future<void> refreshConfiguration() async {
    _log('🔄 Refreshing API configuration...');
    _isConfigurationCached = false;
    await initializeConfiguration();
  }

  /// Fallback initialization (synchronous, uses defaults)
  static void _initializeFallback() {
    if (!_isConfigurationCached) {
      _log('🚨 Emergency fallback initialization - using defaults');
      _cachedBaseUrl = _defaultBaseUrl;
      _cachedBareBaseUrl = _defaultBareBaseUrl;
      _cachedTimeoutSeconds = _defaultTimeoutSeconds;
      _isConfigurationCached = true;
    }
  }

  // Get base URL from cache
  static String get _baseUrl {
    if (!_isConfigurationCached) {
      _log(
        '⚠️ Configuration not cached, using default baseUrl: $_defaultBaseUrl',
      );
      // Try to initialize synchronously as fallback
      _initializeFallback();
      return _defaultBaseUrl;
    }
    return _cachedBaseUrl ?? _defaultBaseUrl;
  }

  // Get bare base URL from cache
  static String get _bareBaseUrl {
    if (!_isConfigurationCached) {
      _log(
        '⚠️ Configuration not cached, using default bareBaseUrl: $_defaultBareBaseUrl',
      );
      // Try to initialize synchronously as fallback
      _initializeFallback();
      return _defaultBareBaseUrl;
    }
    return _cachedBareBaseUrl ?? _defaultBareBaseUrl;
  }

  // Get timeout duration from cache
  static Duration get _timeout {
    if (!_isConfigurationCached) {
      // Try to initialize synchronously as fallback
      _initializeFallback();
      return const Duration(seconds: _defaultTimeoutSeconds);
    }
    final seconds = _cachedTimeoutSeconds ?? _defaultTimeoutSeconds;
    return Duration(seconds: seconds);
  }

  // Helper method for conditional logging
  static void _log(String message) {
    // Only log in debug mode
    assert(() {
      developer.log(message, name: 'ApiService');
      return true;
    }());
  }

  // Helper method to convert custom HttpMethod to Firebase Performance HttpMethod
  static firebase_perf.HttpMethod _convertHttpMethod(HttpMethod method) {
    switch (method) {
      case HttpMethod.get:
        return firebase_perf.HttpMethod.Get;
      case HttpMethod.post:
        return firebase_perf.HttpMethod.Post;
      case HttpMethod.put:
        return firebase_perf.HttpMethod.Put;
      case HttpMethod.delete:
        return firebase_perf.HttpMethod.Delete;
      case HttpMethod.patch:
        return firebase_perf.HttpMethod.Patch;
    }
  }

  /// Convert endpoint URL to clean metric name
  static String _createCleanEndpointName(String endpoint, HttpMethod method) {
    // Remove leading slash and trailing slash
    String cleanEndpoint = endpoint.replaceAll(RegExp(r'^/+|/+$'), '');

    // Replace slashes with underscores
    cleanEndpoint = cleanEndpoint.replaceAll('/', '_');

    // Remove common patterns and clean up
    cleanEndpoint = cleanEndpoint
        .replaceAll('-', '_')
        .replaceAll('__', '_')
        .toLowerCase();

    // Handle special endpoint mappings for common exanor endpoints
    final Map<String, String> endpointMappings = {
      'get_user_profile': 'user_profile',
      'update_user_profile': 'update_profile',
      'create_notification_token': 'register_fcm',
      'get_professional_categories': 'professional_categories',
      'get_business_categories': 'business_categories',
      'get_employee_categories': 'employee_categories',
      'get_subscription': 'get_subscription',
      'create_subscription': 'create_subscription',
      'get_messages': 'get_messages',
      'send_message': 'send_message',
      'upload_image': 'upload_image',
      'upload_file': 'upload_file',
      'phone_registration': 'phone_register',
      'verify_otp': 'verify_otp',
      'refresh_token': 'refresh_token',
      'get_businesses': 'get_businesses',
      'create_business': 'create_business',
      'update_business': 'update_business',
      'search_users': 'search_users',
      'get_user_details': 'user_details',
    };

    // Apply mapping if available
    final mappedEndpoint = endpointMappings[cleanEndpoint] ?? cleanEndpoint;

    // Create final metric name with method and app prefix
    return 'exanor_${method.name}_$mappedEndpoint';
  }

  /// Generic API call method
  /// [endpoint] - API endpoint (without base URL)
  /// [method] - HTTP method (GET, POST, PUT, DELETE, PATCH)
  /// [body] - Optional request body (for POST, PUT, PATCH)
  /// [headers] - Optional custom headers
  /// [useBearerToken] - Whether to include Bearer token in headers
  static Future<Map<String, dynamic>> makeRequest({
    required String endpoint,
    required HttpMethod method,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool useBearerToken = false,
  }) async {
    // Construct full URL (declare outside try block for error logging)
    final String fullUrl = '$_baseUrl$endpoint';

    // Create clean endpoint name for performance tracking
    final String cleanEndpointName = _createCleanEndpointName(endpoint, method);

    // Create Firebase Performance HTTP metric
    final performanceMetric = PerformanceService.instance.createHttpMetric(
      fullUrl,
      _convertHttpMethod(method),
    );

    try {
      // Start performance monitoring
      await performanceMetric.start();

      // Add endpoint attributes for better tracking
      performanceMetric.putAttribute('endpoint', endpoint);
      performanceMetric.putAttribute('clean_name', cleanEndpointName);
      performanceMetric.putAttribute('method', method.name.toUpperCase());
      performanceMetric.putAttribute('app', 'exanor');
      performanceMetric.putAttribute('category', 'api');
      performanceMetric.putAttribute(
        'use_bearer_token',
        useBearerToken.toString(),
      );

      if (body != null) {
        performanceMetric.putAttribute('has_body', 'true');
        performanceMetric.requestPayloadSize = jsonEncode(body).length;
      } else {
        performanceMetric.putAttribute('has_body', 'false');
      }

      final Uri uri = Uri.parse(fullUrl);

      // Default headers
      final Map<String, String> defaultHeaders = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      // Add Bearer token if requested
      if (useBearerToken) {
        final accessToken = await _getAccessToken();
        if (accessToken != null) {
          defaultHeaders['Authorization'] = 'Bearer $accessToken';
        }
      }

      // Merge with custom headers if provided
      final Map<String, String> requestHeaders = {
        ...defaultHeaders,
        if (headers != null) ...headers,
      };

      // Debug: Log request information
      _log(
        '🌐 API REQUEST DEBUG:\n📍 URL: $fullUrl\n🔧 Method: ${method.name.toUpperCase()}\n📋 Headers: $requestHeaders\n📦 Request Body: ${body != null ? jsonEncode(body) : 'null'}\n⏰ Timeout: ${_timeout.inSeconds}s\n---',
      );

      late http.Response response;

      // Execute request based on method
      switch (method) {
        case HttpMethod.get:
          response = await http
              .get(uri, headers: requestHeaders)
              .timeout(_timeout);
          break;
        case HttpMethod.post:
          response = await http
              .post(
                uri,
                headers: requestHeaders,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(_timeout);
          break;
        case HttpMethod.put:
          response = await http
              .put(
                uri,
                headers: requestHeaders,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(_timeout);
          break;
        case HttpMethod.delete:
          // For DELETE requests with a body, we need to use a custom request
          if (body != null) {
            final request = http.Request('DELETE', uri);
            request.headers.addAll(requestHeaders);
            request.body = jsonEncode(body);
            final streamedResponse = await http.Client()
                .send(request)
                .timeout(_timeout);
            response = await http.Response.fromStream(streamedResponse);
          } else {
            response = await http
                .delete(uri, headers: requestHeaders)
                .timeout(_timeout);
          }
          break;
        case HttpMethod.patch:
          response = await http
              .patch(
                uri,
                headers: requestHeaders,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(_timeout);
          break;
      }

      return await _handleResponse(
        response,
        endpoint,
        method,
        body,
        headers,
        useBearerToken,
        performanceMetric,
      );
    } catch (e) {
      // Add error information to performance metric
      performanceMetric.putAttribute('error', e.runtimeType.toString());
      performanceMetric.putAttribute('error_message', e.toString());

      _log(
        '❌ API REQUEST ERROR:\n📍 URL: $fullUrl\n🔧 Method: ${method.name.toUpperCase()}\n💥 Error: ${e.toString()}\n---',
      );

      // Complete performance metric with error
      await performanceMetric.stop();

      throw ApiException('Network error: ${e.toString()}');
    }
  }

  /// Handle HTTP response
  static Future<Map<String, dynamic>> _handleResponse(
    http.Response response,
    String endpoint,
    HttpMethod method,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool useBearerToken,
    firebase_perf.HttpMetric performanceMetric,
  ) async {
    // Set response metrics
    performanceMetric.httpResponseCode = response.statusCode;
    performanceMetric.responseContentType = response.headers['content-type'];
    performanceMetric.responsePayloadSize =
        response.contentLength ?? response.body.length;

    final Map<String, dynamic> data = {
      'statusCode': response.statusCode,
      'headers': response.headers,
    };

    try {
      if (response.body.isNotEmpty) {
        data['data'] = jsonDecode(response.body);
      }
    } catch (e) {
      data['data'] = {'raw': response.body};
    }

    // Debug: Log response information
    final responseBody = response.body.length > 1000
        ? '${response.body.substring(0, 1000)}...[truncated]'
        : response.body;
    final parsedDataStr = (data['data'] != null && data['data'] is Map)
        ? '\n🎯 Parsed Data: ${data['data']}'
        : '';
    _log(
      '📥 API RESPONSE DEBUG:\n🔢 Status Code: ${response.statusCode}\n📋 Response Headers: ${response.headers}\n📦 Response Body: $responseBody$parsedDataStr\n⏱️ Response Size: ${response.body.length} bytes\n---',
    );

    // Add success/failure attributes to performance metric
    performanceMetric.putAttribute(
      'success',
      response.statusCode < 400 ? 'true' : 'false',
    );
    performanceMetric.putAttribute('endpoint', endpoint);
    performanceMetric.putAttribute('method', method.name.toUpperCase());

    // Check for success status codes
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Special case: HTTP 200 but internal status 403 (subscription required)
      if (response.statusCode == 200 &&
          data['data'] != null &&
          data['data'] is Map &&
          data['data']['status'] == 403) {
        _log(
          '🔒 API SERVICE RESPONSE: HTTP 200 with internal status 403 - Subscription required',
        );
        performanceMetric.putAttribute('subscription_required', 'true');
        await performanceMetric.stop();
        _handleSubscriptionRequired(data['data']);
        return data;
      }

      performanceMetric.putAttribute('result', 'success');
      await performanceMetric.stop();
      _log('✅ API RESPONSE SUCCESS\n---');
      return data;
    } else if (response.statusCode == 401 && useBearerToken) {
      // Handle unauthorized response with token refresh
      _log('🔄 401 Unauthorized - Attempting token refresh...');
      performanceMetric.putAttribute('auth_refresh_attempted', 'true');

      // If we're already navigating to auth, don't attempt refresh or navigate again
      if (_isNavigatingToAuth) {
        _log('⚠️ Auth navigation already in progress - skipping refresh');
        performanceMetric.putAttribute(
          'auth_refresh_result',
          'skipped_navigating',
        );
        await performanceMetric.stop();
        throw ApiAuthException(
          'Authentication required',
          statusCode: 401,
          response: data,
          requiresRegistration: true,
        );
      }

      try {
        // Check token availability with detailed logging
        final currentAccessToken = await _getAccessToken();
        final currentRefreshToken = await _getRefreshToken();

        _log('🔍 Token Status Check:');
        _log(
          '   Access Token: ${currentAccessToken != null ? "Present (${currentAccessToken.length} chars)" : "Missing"}',
        );
        _log(
          '   Refresh Token: ${currentRefreshToken != null ? "Present (${currentRefreshToken.length} chars)" : "Missing"}',
        );

        // Check if we have a refresh token (access token being expired is expected)
        if (currentRefreshToken == null) {
          _log('❌ No refresh token available - cannot refresh');
          _log('💡 User needs to re-authenticate');
          performanceMetric.putAttribute(
            'auth_refresh_result',
            'no_refresh_token',
          );
          await performanceMetric.stop();
          await _clearTokens();
          await _navigateToPhoneRegistration();
          throw ApiAuthException(
            'Authentication required',
            statusCode: 401,
            response: data,
            requiresRegistration: true,
          );
        }

        _log('🔑 Refresh token found - Attempting token refresh...');
        final refreshSuccess = await _refreshTokens();

        if (refreshSuccess) {
          _log('✅ Token refresh successful - Retrying original request...');
          performanceMetric.putAttribute('auth_refresh_result', 'success');
          await performanceMetric.stop();
          // Retry the original request with new token
          return await makeRequest(
            endpoint: endpoint,
            method: method,
            body: body,
            headers: headers,
            useBearerToken: useBearerToken,
          );
        } else {
          _log('❌ Token refresh failed - Clearing session...');
          performanceMetric.putAttribute('auth_refresh_result', 'failed');
          await performanceMetric.stop();
          // _clearTokens already done inside _refreshTokens for 401 case
          await _navigateToPhoneRegistration();
          throw ApiAuthException(
            'Authentication required',
            statusCode: 401,
            response: data,
            requiresRegistration: true,
          );
        }
      } catch (e) {
        if (e is ApiAuthException) rethrow;
        _log('❌ Token refresh error: $e');
        performanceMetric.putAttribute('auth_refresh_error', e.toString());
        await performanceMetric.stop();
        await _clearTokens();
        await _navigateToPhoneRegistration();
        throw ApiAuthException(
          'Authentication required',
          statusCode: 401,
          response: data,
          requiresRegistration: true,
        );
      }
    } else {
      performanceMetric.putAttribute('result', 'error');
      performanceMetric.putAttribute('error_type', 'http_error');
      performanceMetric.putAttribute(
        'http_status',
        response.statusCode.toString(),
      );
      await performanceMetric.stop();

      _log(
        '❌ API RESPONSE ERROR:\n🔢 Status Code: ${response.statusCode}\n📝 Error Message: ${_getErrorMessage(response.statusCode)}\n---',
      );
      throw ApiException(
        'HTTP ${response.statusCode}: ${_getErrorMessage(response.statusCode)}',
        statusCode: response.statusCode,
        response: data,
      );
    }
  }

  /// Get user-friendly error message
  static String _getErrorMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found';
      case 429:
        return 'Too Many Requests';
      case 500:
        return 'Internal Server Error';
      case 502:
        return 'Bad Gateway';
      case 503:
        return 'Service Unavailable';
      default:
        return 'Request Failed';
    }
  }

  // Convenience methods for common operations

  /// GET request
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
    bool useBearerToken = false,
  }) {
    return makeRequest(
      endpoint: endpoint,
      method: HttpMethod.get,
      headers: headers,
      useBearerToken: useBearerToken,
    );
  }

  /// POST request
  static Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool useBearerToken = false,
  }) {
    return makeRequest(
      endpoint: endpoint,
      method: HttpMethod.post,
      body: body,
      headers: headers,
      useBearerToken: useBearerToken,
    );
  }

  /// PUT request
  static Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool useBearerToken = false,
  }) {
    return makeRequest(
      endpoint: endpoint,
      method: HttpMethod.put,
      body: body,
      headers: headers,
      useBearerToken: useBearerToken,
    );
  }

  /// DELETE request
  static Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool useBearerToken = false,
  }) {
    return makeRequest(
      endpoint: endpoint,
      method: HttpMethod.delete,
      body: body,
      headers: headers,
      useBearerToken: useBearerToken,
    );
  }

  /// PATCH request
  static Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    bool useBearerToken = false,
  }) {
    return makeRequest(
      endpoint: endpoint,
      method: HttpMethod.patch,
      body: body,
      headers: headers,
      useBearerToken: useBearerToken,
    );
  }

  /// Upload file with multipart/form-data
  static Future<Map<String, dynamic>> uploadFile(
    String endpoint, {
    required File file,
    required String fieldName,
    Map<String, String>? additionalFields,
    bool useBearerToken = false,
  }) async {
    final String fullUrl = '$_baseUrl$endpoint';

    // Create clean endpoint name for performance tracking
    final String cleanEndpointName = _createCleanEndpointName(
      endpoint,
      HttpMethod.put,
    );

    // Create Firebase Performance HTTP metric for file upload
    final performanceMetric = PerformanceService.instance.createHttpMetric(
      fullUrl,
      firebase_perf.HttpMethod.Put,
    );

    try {
      // Start performance monitoring
      await performanceMetric.start();

      // Add upload-specific attributes
      performanceMetric.putAttribute('operation', 'file_upload');
      performanceMetric.putAttribute('endpoint', endpoint);
      performanceMetric.putAttribute('clean_name', cleanEndpointName);
      performanceMetric.putAttribute('method', 'PUT');
      performanceMetric.putAttribute('app', 'exanor');
      performanceMetric.putAttribute('category', 'api');
      performanceMetric.putAttribute('field_name', fieldName);
      performanceMetric.putAttribute(
        'use_bearer_token',
        useBearerToken.toString(),
      );

      // Create multipart request
      final request = http.MultipartRequest('PUT', Uri.parse(fullUrl));

      // Add headers
      request.headers['Accept'] = 'application/json';

      // Add Bearer token if requested
      if (useBearerToken) {
        final accessToken = await _getAccessToken();
        if (accessToken != null) {
          request.headers['Authorization'] = 'Bearer $accessToken';
        }
      }

      // Add file
      final multipartFile = await http.MultipartFile.fromPath(
        fieldName,
        file.path,
      );
      request.files.add(multipartFile);

      // Add additional fields if provided
      if (additionalFields != null) {
        request.fields.addAll(additionalFields);
      }

      // Get file information for debugging and performance tracking
      final fileSize = await file.length();
      final fileSizeKB = (fileSize / 1024).toStringAsFixed(2);
      final fileName = file.path.split('/').last;

      // Add file size to performance metric
      performanceMetric.requestPayloadSize = fileSize;
      performanceMetric.putAttribute('file_size_kb', fileSizeKB);
      performanceMetric.putAttribute('file_name', fileName);

      // Debug: Log request information
      _log(
        '🌐 FILE UPLOAD REQUEST DEBUG:\n📍 URL: $fullUrl\n🔧 Method: PUT\n📋 Headers: ${request.headers}\n📁 File Path: ${file.path}\n📁 File Name: $fileName\n📁 File Size: $fileSize bytes ($fileSizeKB KB)\n📁 Field Name: $fieldName\n📦 Additional Fields: $additionalFields\n⏰ Timeout: ${_timeout.inSeconds}s\n---',
      );

      _log('📤 Starting file upload...');
      final uploadStartTime = DateTime.now();

      // Send request
      final streamedResponse = await request.send().timeout(_timeout);

      final uploadEndTime = DateTime.now();
      final uploadDuration = uploadEndTime.difference(uploadStartTime);

      _log('⏱️ Upload stream completed in: ${uploadDuration.inMilliseconds}ms');
      _log('📥 Converting stream to response...');

      final response = await http.Response.fromStream(streamedResponse);

      final totalDuration = DateTime.now().difference(uploadStartTime);
      _log(
        '⏱️ Total upload process completed in: ${totalDuration.inMilliseconds}ms',
      );

      // Set response metrics
      performanceMetric.httpResponseCode = response.statusCode;
      performanceMetric.responseContentType = response.headers['content-type'];
      performanceMetric.responsePayloadSize =
          response.contentLength ?? response.body.length;
      performanceMetric.putAttribute(
        'upload_duration_ms',
        uploadDuration.inMilliseconds.toString(),
      );
      performanceMetric.putAttribute(
        'total_duration_ms',
        totalDuration.inMilliseconds.toString(),
      );
      performanceMetric.putAttribute(
        'success',
        response.statusCode < 400 ? 'true' : 'false',
      );

      return await _handleResponse(
        response,
        endpoint,
        HttpMethod.put,
        null,
        null,
        useBearerToken,
        performanceMetric,
      );
    } catch (e) {
      // Add error information to performance metric
      performanceMetric.putAttribute('error', e.runtimeType.toString());
      performanceMetric.putAttribute('error_message', e.toString());
      await performanceMetric.stop();

      _log(
        '❌ FILE UPLOAD ERROR:\n📍 URL: $fullUrl\n🔧 Method: PUT\n💥 Error: ${e.toString()}\n---',
      );
      throw ApiException('File upload error: ${e.toString()}');
    }
  }

  /// Upload image with multipart/form-data
  static Future<Map<String, dynamic>> uploadImage(
    String endpoint, {
    required File imageFile,
    required String fieldName,
    Map<String, String>? additionalFields,
    bool useBearerToken = false,
  }) async {
    final String fullUrl = '$_baseUrl$endpoint';

    // Create clean endpoint name for performance tracking
    final String cleanEndpointName = _createCleanEndpointName(
      endpoint,
      HttpMethod.post,
    );

    // Create Firebase Performance HTTP metric for image upload
    final performanceMetric = PerformanceService.instance.createHttpMetric(
      fullUrl,
      firebase_perf.HttpMethod.Post,
    );

    try {
      // Start performance monitoring
      await performanceMetric.start();

      // Add upload-specific attributes
      performanceMetric.putAttribute('operation', 'image_upload');
      performanceMetric.putAttribute('endpoint', endpoint);
      performanceMetric.putAttribute('clean_name', cleanEndpointName);
      performanceMetric.putAttribute('method', 'POST');
      performanceMetric.putAttribute('app', 'exanor');
      performanceMetric.putAttribute('category', 'api');
      performanceMetric.putAttribute('field_name', fieldName);
      performanceMetric.putAttribute(
        'use_bearer_token',
        useBearerToken.toString(),
      );

      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(fullUrl));

      // Add headers
      request.headers['Accept'] = 'application/json';

      // Add Bearer token if requested
      if (useBearerToken) {
        final accessToken = await _getAccessToken();
        if (accessToken != null) {
          request.headers['Authorization'] = 'Bearer $accessToken';
        }
      }

      // Add file
      final multipartFile = await http.MultipartFile.fromPath(
        fieldName,
        imageFile.path,
        filename: imageFile.path.split('/').last,
      );
      request.files.add(multipartFile);

      // Add additional fields if provided
      if (additionalFields != null) {
        request.fields.addAll(additionalFields);
      }

      // Get file information for debugging and performance tracking
      final fileSize = await imageFile.length();
      final fileSizeKB = (fileSize / 1024).toStringAsFixed(2);
      final fileName = imageFile.path.split('/').last;

      // Add file size to performance metric
      performanceMetric.requestPayloadSize = fileSize;
      performanceMetric.putAttribute('file_size_kb', fileSizeKB);
      performanceMetric.putAttribute('file_name', fileName);

      // Debug: Log request information
      _log(
        '🌐 IMAGE UPLOAD REQUEST DEBUG:\n📍 URL: $fullUrl\n🔧 Method: POST\n📋 Headers: ${request.headers}\n📁 File Path: ${imageFile.path}\n📁 File Name: $fileName\n📁 File Size: $fileSize bytes ($fileSizeKB KB)\n📁 Field Name: $fieldName\n📦 Additional Fields: $additionalFields\n⏰ Timeout: ${_timeout.inSeconds}s\n---',
      );

      _log('📤 Starting image upload...');
      final uploadStartTime = DateTime.now();

      // Send request
      final streamedResponse = await request.send().timeout(_timeout);

      final uploadEndTime = DateTime.now();
      final uploadDuration = uploadEndTime.difference(uploadStartTime);

      _log('⏱️ Upload stream completed in: ${uploadDuration.inMilliseconds}ms');
      _log('📥 Converting stream to response...');

      final response = await http.Response.fromStream(streamedResponse);

      final totalDuration = DateTime.now().difference(uploadStartTime);
      _log(
        '⏱️ Total upload process completed in: ${totalDuration.inMilliseconds}ms',
      );

      // Set response metrics
      performanceMetric.httpResponseCode = response.statusCode;
      performanceMetric.responseContentType = response.headers['content-type'];
      performanceMetric.responsePayloadSize =
          response.contentLength ?? response.body.length;
      performanceMetric.putAttribute(
        'upload_duration_ms',
        uploadDuration.inMilliseconds.toString(),
      );
      performanceMetric.putAttribute(
        'total_duration_ms',
        totalDuration.inMilliseconds.toString(),
      );
      performanceMetric.putAttribute(
        'success',
        response.statusCode < 400 ? 'true' : 'false',
      );

      return await _handleResponse(
        response,
        endpoint,
        HttpMethod.post,
        null,
        null,
        useBearerToken,
        performanceMetric,
      );
    } catch (e) {
      // Add error information to performance metric
      performanceMetric.putAttribute('error', e.runtimeType.toString());
      performanceMetric.putAttribute('error_message', e.toString());
      await performanceMetric.stop();

      _log(
        '❌ IMAGE UPLOAD ERROR:\n📍 URL: $fullUrl\n🔧 Method: POST\n💥 Error: ${e.toString()}\n---',
      );
      throw ApiException('Image upload error: ${e.toString()}');
    }
  }

  // Token management methods

  /// Get access token from storage
  static Future<String?> _getAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('access_token');
    } catch (e) {
      _log('❌ Error getting access token: $e');
      return null;
    }
  }

  /// Get refresh token from storage
  static Future<String?> _getRefreshToken() async {
    try {
      final token = await _secureStorage.read(key: 'refresh_token');
      if (token != null) {
        _log(
          '🔑 Refresh token retrieved from secure storage (${token.length} chars)',
        );
      } else {
        _log('⚠️ No refresh token found in secure storage');
      }
      return token;
    } catch (e) {
      _log('❌ Error getting refresh token: $e');
      return null;
    }
  }

  /// Clear all tokens from storage
  static Future<void> _clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('csrf_token');
      await _secureStorage.delete(key: 'refresh_token');
      _log('🗑️ All tokens cleared from storage');
    } catch (e) {
      _log('❌ Error clearing tokens: $e');
    }
  }

  /// Update access and refresh tokens
  static Future<void> _updateTokens(
    String accessToken,
    String? refreshToken,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', accessToken);

      if (refreshToken != null) {
        await _secureStorage.write(key: 'refresh_token', value: refreshToken);
      }

      _log('🔄 Tokens updated successfully');
    } catch (e) {
      _log('❌ Error updating tokens: $e');
    }
  }

  /// Public method to store tokens (e.g. from sign up/login)
  static Future<void> storeTokens({
    required String accessToken,
    required String? refreshToken,
    String? csrfToken,
  }) async {
    try {
      _log('💾 Storing tokens...');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', accessToken);
      _log('   ✅ Access token stored (${accessToken.length} chars)');

      if (csrfToken != null) {
        await prefs.setString('csrf_token', csrfToken);
        _log('   ✅ CSRF token stored');
      }

      if (refreshToken != null) {
        await _secureStorage.write(key: 'refresh_token', value: refreshToken);
        _log(
          '   ✅ Refresh token stored in secure storage (${refreshToken.length} chars)',
        );

        // Verify the refresh token was actually written
        final verifyRefreshToken = await _secureStorage.read(
          key: 'refresh_token',
        );
        if (verifyRefreshToken != null) {
          _log('   ✅ Refresh token verified in storage');
        } else {
          _log(
            '   ⚠️ WARNING: Refresh token verification failed - token not found after write!',
          );
        }
      } else {
        _log('   ⚠️ No refresh token provided to store');
      }

      _log('✅ Token storage completed');
    } catch (e) {
      _log('❌ Error storing tokens: $e');
      rethrow; // Re-throw to let caller know storage failed
    }
  }

  // Completer-based lock to prevent multiple simultaneous refresh attempts
  static Completer<bool>? _refreshCompleter;

  /// Refresh access token using refresh token
  /// Uses a lock so only one refresh runs at a time; concurrent callers
  /// share the same result.
  static Future<bool> _refreshTokens() async {
    // If a refresh is already in progress, wait for its result
    if (_refreshCompleter != null) {
      _log('🔄 Token refresh already in progress - waiting for result...');
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await _getRefreshToken();
      if (refreshToken == null) {
        _log('❌ No refresh token available');
        _refreshCompleter!.complete(false);
        _refreshCompleter = null;
        return false;
      }

      _log('🔄 Refreshing tokens...');

      // Make refresh request without Bearer token to avoid infinite loop
      _log('📤 Sending refresh token request to $_baseUrl/auth/refresh/');

      final body = {'is_app': true, 'refresh_token': refreshToken};

      _log('📦 Request body: ${jsonEncode(body)}');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/refresh/'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      _log(
        '📥 REFRESH TOKEN RESPONSE:\n🔢 Status Code: ${response.statusCode}\n📦 Response Body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final newAccessToken = responseData['access'];
        final newRefreshToken =
            responseData['refresh_token']; // Changed from 'refresh'

        _log('🔑 New Access Token: ${newAccessToken?.substring(0, 20)}...');
        if (newRefreshToken != null) {
          _log('🔑 New Refresh Token: ${newRefreshToken.substring(0, 20)}...');
        }

        if (newAccessToken != null) {
          await _updateTokens(newAccessToken, newRefreshToken);
          _log('✅ Tokens refreshed successfully');
          _refreshCompleter!.complete(true);
          _refreshCompleter = null;
          return true;
        } else {
          _log('❌ Invalid refresh response format - missing access token');
          _refreshCompleter!.complete(false);
          _refreshCompleter = null;
          return false;
        }
      } else if (response.statusCode == 401) {
        _log('❌ Refresh token expired or invalid - Status code 401');
        // Only clear tokens here; navigation is handled by the caller
        await _clearTokens();
        _refreshCompleter!.complete(false);
        _refreshCompleter = null;
        return false;
      } else {
        _log('❌ Refresh token request failed: ${response.statusCode}');
        _refreshCompleter!.complete(false);
        _refreshCompleter = null;
        return false;
      }
    } catch (e) {
      _log('❌ Token refresh error: $e');
      _refreshCompleter?.complete(false);
      _refreshCompleter = null;
      return false;
    }
  }

  /// Public method to manually refresh tokens
  static Future<bool> refreshTokens() async {
    _log('🔄 Manual token refresh requested');
    return await _refreshTokens();
  }

  /// Check if user is logged in (has valid tokens)
  static Future<bool> isLoggedIn() async {
    final accessToken = await _getAccessToken();
    final refreshToken = await _getRefreshToken();
    return accessToken != null && refreshToken != null;
  }

  /// Debug method to check and log current token status
  /// Useful for troubleshooting authentication issues
  static Future<Map<String, dynamic>> getTokenStatus() async {
    final accessToken = await _getAccessToken();
    final refreshToken = await _getRefreshToken();

    final status = {
      'hasAccessToken': accessToken != null,
      'hasRefreshToken': refreshToken != null,
      'accessTokenLength': accessToken?.length ?? 0,
      'refreshTokenLength': refreshToken?.length ?? 0,
      'isLoggedIn': accessToken != null && refreshToken != null,
    };

    _log('📊 Token Status:');
    final hasAccessToken = status['hasAccessToken'] as bool;
    final hasRefreshToken = status['hasRefreshToken'] as bool;
    _log(
      '   Access Token: ${hasAccessToken ? "Present (${status['accessTokenLength']} chars)" : "Missing"}',
    );
    _log(
      '   Refresh Token: ${hasRefreshToken ? "Present (${status['refreshTokenLength']} chars)" : "Missing"}',
    );
    _log('   Logged In: ${status['isLoggedIn']}');

    return status;
  }

  // Global navigator key for navigation from services
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // Authentication state callback
  static Function? onAuthenticationFailed;

  // Flag to prevent multiple simultaneous auth navigation attempts
  static bool _isNavigatingToAuth = false;

  /// Set callback for authentication failure
  static void setAuthFailureCallback(Function callback) {
    onAuthenticationFailed = callback;
    _log('✅ Auth failure callback set');
  }

  /// Reset auth navigation flag (call this when auth screen is mounted)
  static void resetAuthNavigationFlag() {
    _isNavigatingToAuth = false;
    _log('🔄 Auth navigation flag reset');
  }

  /// Navigate to phone registration screen when auth fails
  /// The flag stays set permanently until AuthLandingScreen calls resetAuthNavigationFlag().
  static Future<void> _navigateToPhoneRegistration() async {
    // Prevent multiple simultaneous navigation attempts
    if (_isNavigatingToAuth) {
      _log(
        '⚠️ Already navigating to auth screen, skipping duplicate navigation',
      );
      return;
    }

    _isNavigatingToAuth = true;
    _log('🔒 Auth navigation started - blocking duplicate navigations');

    try {
      // First try using the navigator key with currentState (more reliable)
      if (navigatorKey.currentState != null) {
        _log('🔑 Using navigatorKey.currentState for navigation');
        // Try auth_landing first, then fall back to phone_registration
        try {
          navigatorKey.currentState!.pushNamedAndRemoveUntil(
            '/auth_landing',
            (route) => false,
          );
          _log('✅ Navigated to auth landing screen using navigatorKey');
          // Flag stays set; AuthLandingScreen.build() calls resetAuthNavigationFlag()
          return;
        } catch (e) {
          _log('⚠️ Auth landing route failed, trying phone_registration: $e');
          navigatorKey.currentState!.pushNamedAndRemoveUntil(
            '/phone_registration',
            (route) => false,
          );
          _log('✅ Navigated to phone registration screen using navigatorKey');
          return;
        }
      }

      // Try using navigatorKey.currentContext as fallback
      if (navigatorKey.currentContext != null) {
        _log('🔑 Using navigatorKey.currentContext for navigation');
        Navigator.of(
          navigatorKey.currentContext!,
          rootNavigator: true,
        ).pushNamedAndRemoveUntil('/auth_landing', (route) => false);
        _log('✅ Navigated to auth landing screen using context');
        return;
      }

      // If navigator key doesn't work, try using the callback
      if (onAuthenticationFailed != null) {
        _log('🔄 Using auth failure callback to navigate');
        onAuthenticationFailed!();
        return;
      }

      // If all approaches fail, log the error and reset flag
      _log('❌ Unable to navigate: No valid context or callback available');
      _log('💡 Setup options:');
      _log(
        '   1. Set ApiService.navigatorKey as the navigatorKey in your MaterialApp',
      );
      _log(
        '   2. Call ApiService.setAuthFailureCallback() with a navigation function',
      );
      _isNavigatingToAuth = false;
    } catch (e) {
      _log('❌ Navigation error: $e');
      _isNavigatingToAuth = false;
    }
  }

  /// Handle subscription required response (HTTP 200 with internal status 409)
  static Future<void> _handleSubscriptionRequired(
    Map<String, dynamic> responseData,
  ) async {
    try {
      _log('🔒 Handling subscription required response');
      _log('📦 Full response data: $responseData');

      // Extract required subscription IDs
      final List<dynamic> requiredSubscriptions =
          responseData['required_subscription_ids'] ?? [];
      final String serviceName =
          responseData['service_name'] ?? 'Premium Service';
      final String subscriptionProfile =
          responseData['subscription_profile'] ?? 'default';

      _log('📋 Required subscriptions: $requiredSubscriptions');
      _log('📋 Service name: $serviceName');
      _log('📋 Subscription profile: $subscriptionProfile');

      if (requiredSubscriptions.isEmpty) {
        _log('⚠️ No required subscriptions found in response');
        return;
      }

      // Fetch subscription details for each required ID
      List<Map<String, dynamic>> subscriptionsData = [];
      for (int i = 0; i < requiredSubscriptions.length; i++) {
        final String subscriptionId = requiredSubscriptions[i].toString();
        _log(
          '🔍 [${i + 1}/${requiredSubscriptions.length}] Fetching subscription ID: $subscriptionId',
        );

        try {
          final response = await post(
            '/get-subscription/',
            body: {'id': subscriptionId},
            useBearerToken: true,
          );

          if (response['data'] != null && response['data']['status'] == 200) {
            final List<dynamic> subscriptions = response['data']['data'] ?? [];
            _log(
              '✅ Successfully fetched ${subscriptions.length} subscription(s) for ID $subscriptionId',
            );
            subscriptionsData.addAll(
              subscriptions.cast<Map<String, dynamic>>(),
            );
          } else {
            _log(
              '❌ Failed to fetch subscription $subscriptionId: ${response['data']?['message'] ?? 'Unknown error'}',
            );
          }
        } catch (e) {
          _log('❌ Error fetching subscription $subscriptionId: $e');
        }
      }

      _log('📊 Total subscriptions collected: ${subscriptionsData.length}');

      // Navigate to subscription screen
      if (navigatorKey.currentContext != null) {
        _log('🚀 Navigating to subscription screen');
        await Navigator.of(
          navigatorKey.currentContext!,
          rootNavigator: true,
        ).pushNamed(
          '/subscription',
          arguments: {
            'service': serviceName,
            'subscriptionProfile': subscriptionProfile,
            'subscriptionsData': subscriptionsData,
            'requiredSubscriptionIds': requiredSubscriptions.cast<String>(),
          },
        );
        _log('✅ Navigation to subscription screen completed');
      } else {
        _log('❌ Unable to navigate: No valid context available');
      }
    } catch (e) {
      _log('❌ Error handling subscription required: $e');
    }
  }

  /// Get current API configuration for debugging
  static Map<String, dynamic> getCurrentConfiguration() {
    return {
      'baseUrl': _baseUrl,
      'bareBaseUrl': _bareBaseUrl,
      'timeout': _timeout.inSeconds,
      'isConfigurationCached': _isConfigurationCached,
      'cachedBaseUrl': _cachedBaseUrl,
      'cachedBareBaseUrl': _cachedBareBaseUrl,
      'cachedTimeoutSeconds': _cachedTimeoutSeconds,
    };
  }

  /// Log current API configuration
  static void logCurrentConfiguration() {
    final config = getCurrentConfiguration();
    _log('🔧 CURRENT API CONFIGURATION:');
    _log('📍 Base URL: ${config['baseUrl']}');
    _log('📍 Bare Base URL: ${config['bareBaseUrl']}');
    _log('⏰ Timeout: ${config['timeout']}s');
    _log('💾 Configuration Cached: ${config['isConfigurationCached']}');
    if (_isConfigurationCached) {
      _log('📦 Cached Values:');
      _log('   📍 Base URL: ${config['cachedBaseUrl']}');
      _log('   📍 Bare Base URL: ${config['cachedBareBaseUrl']}');
      _log('   ⏰ Timeout: ${config['cachedTimeoutSeconds']}s');
    }
    _log('---');
  }
}

/// Custom exception for API errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? response;

  const ApiException(this.message, {this.statusCode, this.response});

  @override
  String toString() => 'ApiException: $message';
}

/// Custom exception for authentication errors
class ApiAuthException extends ApiException {
  final bool requiresRegistration;

  const ApiAuthException(
    String message, {
    int? statusCode,
    Map<String, dynamic>? response,
    this.requiresRegistration = false,
  }) : super(message, statusCode: statusCode, response: response);

  @override
  String toString() => 'ApiAuthException: $message';
}
