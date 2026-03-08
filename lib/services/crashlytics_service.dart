import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'package:exanor/utils/platform_helper.dart';

// Conditionally import firebase_crashlytics only on supported platforms
// On unsupported platforms, all methods become no-ops
import 'package:firebase_crashlytics/firebase_crashlytics.dart'
    if (dart.library.io) 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// A comprehensive service for Firebase Crashlytics integration
/// Provides easy access to all Crashlytics features throughout the app.
/// On unsupported platforms (Windows, Linux), all methods are no-ops.
class CrashlyticsService {
  static final CrashlyticsService _instance = CrashlyticsService._internal();
  static CrashlyticsService get instance => _instance;

  CrashlyticsService._internal();

  /// Whether Crashlytics is enabled (only in release mode AND on supported platforms)
  bool get isEnabled => !kDebugMode && PlatformHelper.isFirebaseSupported;

  /// Initialize the Crashlytics service
  /// This should be called after Firebase Core initialization
  Future<void> initialize() async {
    if (!PlatformHelper.isFirebaseSupported) {
      developer.log(
        '⚠️ Crashlytics not supported on ${defaultTargetPlatform.name} - skipping initialization',
        name: 'CrashlyticsService',
      );
      return;
    }

    try {
      // Enable crashlytics collection in release mode, disable in debug mode
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        kReleaseMode,
      );

      developer.log(
        '✅ Crashlytics Service initialized successfully',
        name: 'CrashlyticsService',
      );
    } catch (e) {
      developer.log(
        '❌ Crashlytics Service initialization failed: $e',
        name: 'CrashlyticsService',
      );
    }
  }

  /// Set user identifier for crash reports
  Future<void> setUserIdentifier(String identifier) async {
    if (!isEnabled || !PlatformHelper.isFirebaseSupported) return;

    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(identifier);
      developer.log(
        '👤 User identifier set: $identifier',
        name: 'CrashlyticsService',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to set user identifier: $e',
        name: 'CrashlyticsService',
      );
    }
  }

  /// Set custom key-value pairs for crash reports
  Future<void> setCustomKey(String key, dynamic value) async {
    if (!isEnabled || !PlatformHelper.isFirebaseSupported) return;

    try {
      if (value is String) {
        await FirebaseCrashlytics.instance.setCustomKey(key, value);
      } else if (value is int) {
        await FirebaseCrashlytics.instance.setCustomKey(key, value);
      } else if (value is double) {
        await FirebaseCrashlytics.instance.setCustomKey(key, value);
      } else if (value is bool) {
        await FirebaseCrashlytics.instance.setCustomKey(key, value);
      } else {
        await FirebaseCrashlytics.instance.setCustomKey(key, value.toString());
      }
      developer.log(
        '🔑 Custom key set: $key = $value',
        name: 'CrashlyticsService',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to set custom key: $e',
        name: 'CrashlyticsService',
      );
    }
  }

  /// Set multiple custom keys at once
  Future<void> setCustomKeys(Map<String, dynamic> keyValuePairs) async {
    if (!isEnabled || !PlatformHelper.isFirebaseSupported) return;

    for (final entry in keyValuePairs.entries) {
      await setCustomKey(entry.key, entry.value);
    }
  }

  /// Log a custom message that will appear in crash reports
  Future<void> log(String message) async {
    if (!isEnabled || !PlatformHelper.isFirebaseSupported) return;

    try {
      await FirebaseCrashlytics.instance.log(message);
      developer.log('📝 Crashlytics log: $message', name: 'CrashlyticsService');
    } catch (e) {
      developer.log('❌ Failed to log message: $e', name: 'CrashlyticsService');
    }
  }

  /// Record a non-fatal error
  Future<void> recordError(
    dynamic exception,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {
    if (!isEnabled || !PlatformHelper.isFirebaseSupported) {
      // On desktop, just log the error
      developer.log(
        '💥 Error (desktop, not sent to Crashlytics): $exception',
        name: 'CrashlyticsService',
      );
      return;
    }

    try {
      await FirebaseCrashlytics.instance.recordError(
        exception,
        stackTrace,
        reason: reason,
        fatal: fatal,
        information: information,
      );
      developer.log(
        '💥 Error recorded: $exception',
        name: 'CrashlyticsService',
      );
    } catch (e) {
      developer.log('❌ Failed to record error: $e', name: 'CrashlyticsService');
    }
  }

  /// Record a Flutter error
  Future<void> recordFlutterError(FlutterErrorDetails errorDetails) async {
    if (!isEnabled || !PlatformHelper.isFirebaseSupported) {
      developer.log(
        '💥 Flutter error (desktop): ${errorDetails.exception}',
        name: 'CrashlyticsService',
      );
      return;
    }

    try {
      await FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
      developer.log(
        '💥 Flutter error recorded: ${errorDetails.exception}',
        name: 'CrashlyticsService',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to record Flutter error: $e',
        name: 'CrashlyticsService',
      );
    }
  }

  /// Record a fatal Flutter error
  Future<void> recordFlutterFatalError(FlutterErrorDetails errorDetails) async {
    if (!isEnabled || !PlatformHelper.isFirebaseSupported) {
      developer.log(
        '💥 Fatal Flutter error (desktop): ${errorDetails.exception}',
        name: 'CrashlyticsService',
      );
      return;
    }

    try {
      await FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
      developer.log(
        '💥 Fatal Flutter error recorded: ${errorDetails.exception}',
        name: 'CrashlyticsService',
      );
    } catch (e) {
      developer.log(
        '❌ Failed to record fatal Flutter error: $e',
        name: 'CrashlyticsService',
      );
    }
  }

  /// Check if crash reporting is enabled
  bool isCrashlyticsCollectionEnabled() {
    if (!PlatformHelper.isFirebaseSupported) return false;

    try {
      return FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled;
    } catch (e) {
      developer.log(
        '❌ Failed to check crashlytics collection status: $e',
        name: 'CrashlyticsService',
      );
      return false;
    }
  }

  /// Force a crash for testing purposes (only in debug mode)
  void forceCrash() {
    if (!PlatformHelper.isFirebaseSupported) {
      developer.log(
        '⚠️ Force crash not supported on desktop',
        name: 'CrashlyticsService',
      );
      return;
    }

    if (kDebugMode) {
      developer.log('💥 Forcing crash for testing', name: 'CrashlyticsService');
      FirebaseCrashlytics.instance.crash();
    } else {
      developer.log(
        '⚠️ Force crash is only available in debug mode',
        name: 'CrashlyticsService',
      );
    }
  }

  /// Set up crash reporting for API calls
  Future<void> setupApiErrorReporting() async {
    await setCustomKey('feature', 'api_service');
    await log('API Service initialized with crash reporting');
  }

  /// Set up crash reporting for authentication
  Future<void> setupAuthErrorReporting(String? userId) async {
    if (userId != null) {
      await setUserIdentifier(userId);
    }
    await setCustomKey('feature', 'authentication');
    await log('Authentication service initialized with crash reporting');
  }

  /// Set up crash reporting for translation service
  Future<void> setupTranslationErrorReporting(String languageCode) async {
    await setCustomKey('feature', 'translation');
    await setCustomKey('language', languageCode);
    await log('Translation service initialized with crash reporting');
  }

  /// Set up crash reporting for ads service
  Future<void> setupAdsErrorReporting() async {
    await setCustomKey('feature', 'ads');
    await log('Ads service initialized with crash reporting');
  }

  /// Set up crash reporting for messaging service
  Future<void> setupMessagingErrorReporting() async {
    await setCustomKey('feature', 'messaging');
    await log('Messaging service initialized with crash reporting');
  }

  /// Helper method to wrap async operations with crash reporting
  Future<T> wrapAsyncOperation<T>(
    Future<T> Function() operation,
    String operationName,
  ) async {
    try {
      await log('Starting operation: $operationName');
      final result = await operation();
      await log('Completed operation: $operationName');
      return result;
    } catch (e, stackTrace) {
      await recordError(
        e,
        stackTrace,
        reason: 'Failed operation: $operationName',
        fatal: false,
      );
      rethrow;
    }
  }

  /// Helper method to wrap synchronous operations with crash reporting
  T wrapSyncOperation<T>(T Function() operation, String operationName) {
    try {
      log('Starting sync operation: $operationName');
      final result = operation();
      log('Completed sync operation: $operationName');
      return result;
    } catch (e, stackTrace) {
      recordError(
        e,
        stackTrace,
        reason: 'Failed sync operation: $operationName',
        fatal: false,
      );
      rethrow;
    }
  }
}
