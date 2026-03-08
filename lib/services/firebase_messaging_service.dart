import 'dart:convert';
import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/utils/platform_helper.dart';

/// Firebase Cloud Messaging Service
/// Handles FCM token management, message receiving, and notifications
class FirebaseMessagingService {
  static FirebaseMessaging? _messaging;
  static bool _isInitialized = false;
  static String? _currentToken;
  static Function(RemoteMessage)? _onMessageReceived;
  static Function(RemoteMessage)? _onMessageOpenedApp;
  static Function(String)? _onTokenRefresh;

  /// Initialize Firebase Cloud Messaging
  static Future<void> initialize({
    Function(RemoteMessage)? onMessageReceived,
    Function(RemoteMessage)? onMessageOpenedApp,
    Function(String)? onTokenRefresh,
  }) async {
    try {
      if (!PlatformHelper.isPushNotificationSupported) {
        _log(
          '⚠️ FirebaseMessagingService: Push notifications not supported on ${defaultTargetPlatform.name}',
        );
        return;
      }

      _log('🔔 FirebaseMessagingService: Starting initialization...');

      // Store callbacks
      _onMessageReceived = onMessageReceived;
      _onMessageOpenedApp = onMessageOpenedApp;
      _onTokenRefresh = onTokenRefresh;

      // Get Firebase Messaging instance
      _messaging = FirebaseMessaging.instance;
      _log('✅ FirebaseMessagingService: Instance obtained successfully');

      // Request notification permissions
      await _requestPermissions();

      // Get initial token
      await _getAndStoreToken();

      // Set up message handlers
      await _setupMessageHandlers();

      // Set up token refresh listener
      _setupTokenRefreshListener();

      _isInitialized = true;
      _log('✅ FirebaseMessagingService: Initialization completed successfully');
    } catch (e) {
      _log('❌ FirebaseMessagingService: Initialization failed: $e');
      _log('📝 Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Request notification permissions
  static Future<void> _requestPermissions() async {
    try {
      _log(
        '🔐 FirebaseMessagingService: Requesting notification permissions...',
      );

      final NotificationSettings settings = await _messaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: true, // Allows user to choose notification types later
        sound: true,
      );

      _log(
        '📋 FirebaseMessagingService: Permission status: ${settings.authorizationStatus}',
      );

      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
          _log('✅ FirebaseMessagingService: Notifications authorized');
          break;
        case AuthorizationStatus.provisional:
          _log(
            '⚠️ FirebaseMessagingService: Provisional authorization granted',
          );
          break;
        case AuthorizationStatus.denied:
          _log('❌ FirebaseMessagingService: Notifications denied');
          break;
        case AuthorizationStatus.notDetermined:
          _log('❓ FirebaseMessagingService: Authorization not determined');
          break;
      }

      // For iOS, ensure APNS token is available
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        _log('🍎 FirebaseMessagingService: Waiting for APNS token...');
        final apnsToken = await _messaging!.getAPNSToken();
        if (apnsToken != null) {
          _log('✅ FirebaseMessagingService: APNS token available');
        } else {
          _log('⚠️ FirebaseMessagingService: APNS token not available yet');
        }
      }
    } catch (e) {
      _log('❌ FirebaseMessagingService: Permission request failed: $e');
      rethrow;
    }
  }

  /// Get and store FCM token
  static Future<void> _getAndStoreToken() async {
    try {
      _log('🔑 FirebaseMessagingService: Getting FCM token...');

      String? token;

      // For web platforms, use VAPID key if available
      if (kIsWeb) {
        // You can set your VAPID key here if you have one
        // token = await _messaging!.getToken(vapidKey: "YOUR_VAPID_KEY");
        token = await _messaging!.getToken();
      } else {
        token = await _messaging!.getToken();
      }

      if (token != null) {
        _currentToken = token;
        _log('✅ FirebaseMessagingService: FCM token obtained');
        _log('🔑 Token: ${token.substring(0, 50)}...');

        // Store token in SharedPreferences
        await _storeToken(token);

        // Call token refresh callback if provided
        _onTokenRefresh?.call(token);
      } else {
        _log('❌ FirebaseMessagingService: Failed to get FCM token');
      }
    } catch (e) {
      _log('❌ FirebaseMessagingService: Token retrieval failed: $e');
      rethrow;
    }
  }

  /// Store FCM token in SharedPreferences
  static Future<void> _storeToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      _log('💾 FirebaseMessagingService: Token stored in SharedPreferences');
    } catch (e) {
      _log('❌ FirebaseMessagingService: Failed to store token: $e');
    }
  }

  /// Get stored FCM token from SharedPreferences
  static Future<String?> getStoredToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fcm_token');
      _log(
        '📖 FirebaseMessagingService: Retrieved stored token: ${token != null ? '${token.substring(0, 50)}...' : 'null'}',
      );
      return token;
    } catch (e) {
      _log('❌ FirebaseMessagingService: Failed to get stored token: $e');
      return null;
    }
  }

  /// Set up message handlers
  static Future<void> _setupMessageHandlers() async {
    try {
      _log('📨 FirebaseMessagingService: Setting up message handlers...');

      // Handle messages when app is in foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _log('📨 FirebaseMessagingService: Foreground message received');
        _logMessage(message, 'FOREGROUND');
        _onMessageReceived?.call(message);
      });

      // Handle messages when app is opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _log('📨 FirebaseMessagingService: Background message opened app');
        _logMessage(message, 'BACKGROUND_OPENED');
        _onMessageOpenedApp?.call(message);
      });

      // Handle messages when app is terminated
      final RemoteMessage? initialMessage = await _messaging!
          .getInitialMessage();
      if (initialMessage != null) {
        _log('📨 FirebaseMessagingService: App opened from terminated state');
        _logMessage(initialMessage, 'TERMINATED_OPENED');
        _onMessageOpenedApp?.call(initialMessage);
      }

      // Set up background message handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      _log('✅ FirebaseMessagingService: Message handlers set up successfully');
    } catch (e) {
      _log('❌ FirebaseMessagingService: Message handler setup failed: $e');
      rethrow;
    }
  }

  /// Set up token refresh listener
  static void _setupTokenRefreshListener() {
    try {
      _log('🔄 FirebaseMessagingService: Setting up token refresh listener...');

      _messaging!.onTokenRefresh.listen(
        (String newToken) {
          _log('🔄 FirebaseMessagingService: Token refreshed');
          _log('🔑 New token: ${newToken.substring(0, 50)}...');

          _currentToken = newToken;
          _storeToken(newToken);
          _onTokenRefresh?.call(newToken);
        },
        onError: (error) {
          _log('❌ FirebaseMessagingService: Token refresh error: $error');
        },
      );

      _log(
        '✅ FirebaseMessagingService: Token refresh listener set up successfully',
      );
    } catch (e) {
      _log(
        '❌ FirebaseMessagingService: Token refresh listener setup failed: $e',
      );
    }
  }

  /// Log message details for debugging
  static void _logMessage(RemoteMessage message, String context) {
    _log('📨 FirebaseMessagingService: [$context] Message Details:');
    _log('   📋 Message ID: ${message.messageId}');
    _log('   📤 From: ${message.from}');
    _log('   ⏰ Sent Time: ${message.sentTime}');
    _log('   📊 TTL: ${message.ttl}');

    if (message.notification != null) {
      _log('   🔔 Notification:');
      _log('      📝 Title: ${message.notification!.title}');
      _log('      📄 Body: ${message.notification!.body}');
      _log(
        '      🖼️ Image: ${message.notification!.android?.imageUrl ?? message.notification!.apple?.imageUrl}',
      );
    }

    if (message.data.isNotEmpty) {
      _log('   📦 Data: ${jsonEncode(message.data)}');
    }
  }

  /// Get current FCM token
  static String? get currentToken => _currentToken;

  /// Check if FCM is initialized
  static bool get isInitialized => _isInitialized;

  /// Get Firebase Messaging instance
  static FirebaseMessaging? get messaging => _messaging;

  /// Manually refresh FCM token
  static Future<String?> refreshToken() async {
    try {
      _log('🔄 FirebaseMessagingService: Manually refreshing token...');

      if (_messaging == null) {
        _log('❌ FirebaseMessagingService: Not initialized');
        return null;
      }

      await _messaging!.deleteToken();
      await _getAndStoreToken();

      _log('✅ FirebaseMessagingService: Token refreshed manually');
      return _currentToken;
    } catch (e) {
      _log('❌ FirebaseMessagingService: Manual token refresh failed: $e');
      return null;
    }
  }

  /// Subscribe to a topic
  static Future<void> subscribeToTopic(String topic) async {
    try {
      _log('📢 FirebaseMessagingService: Subscribing to topic: $topic');

      if (_messaging == null) {
        _log('❌ FirebaseMessagingService: Not initialized');
        return;
      }

      await _messaging!.subscribeToTopic(topic);
      _log('✅ FirebaseMessagingService: Subscribed to topic: $topic');
    } catch (e) {
      _log('❌ FirebaseMessagingService: Topic subscription failed: $e');
      rethrow;
    }
  }

  /// Unsubscribe from a topic
  static Future<void> unsubscribeFromTopic(String topic) async {
    try {
      _log('📢 FirebaseMessagingService: Unsubscribing from topic: $topic');

      if (_messaging == null) {
        _log('❌ FirebaseMessagingService: Not initialized');
        return;
      }

      await _messaging!.unsubscribeFromTopic(topic);
      _log('✅ FirebaseMessagingService: Unsubscribed from topic: $topic');
    } catch (e) {
      _log('❌ FirebaseMessagingService: Topic unsubscription failed: $e');
      rethrow;
    }
  }

  /// Enable/disable auto initialization
  static Future<void> setAutoInitEnabled(bool enabled) async {
    try {
      _log('⚙️ FirebaseMessagingService: Setting auto init to: $enabled');

      if (_messaging == null) {
        _log('❌ FirebaseMessagingService: Not initialized');
        return;
      }

      await _messaging!.setAutoInitEnabled(enabled);
      _log('✅ FirebaseMessagingService: Auto init set to: $enabled');
    } catch (e) {
      _log('❌ FirebaseMessagingService: Auto init setting failed: $e');
      rethrow;
    }
  }

  /// Get notification settings
  static Future<NotificationSettings> getNotificationSettings() async {
    try {
      if (_messaging == null) {
        throw Exception('FirebaseMessagingService not initialized');
      }

      final settings = await _messaging!.getNotificationSettings();
      _log('📋 FirebaseMessagingService: Current notification settings:');
      _log('   🔐 Authorization: ${settings.authorizationStatus}');
      _log('   🔔 Alert: ${settings.alert}');
      _log('   🔊 Sound: ${settings.sound}');
      _log('   🔴 Badge: ${settings.badge}');

      return settings;
    } catch (e) {
      _log(
        '❌ FirebaseMessagingService: Failed to get notification settings: $e',
      );
      rethrow;
    }
  }

  /// Helper method for conditional logging
  static void _log(String message) {
    // Only log in debug mode
    assert(() {
      developer.log(message, name: 'FCM');
      return true;
    }());
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if not already done
  // await Firebase.initializeApp();

  developer.log('📨 FCM: Background message received', name: 'FCM');
  developer.log('   📋 Message ID: ${message.messageId}', name: 'FCM');
  developer.log('   📤 From: ${message.from}', name: 'FCM');

  if (message.notification != null) {
    developer.log('   🔔 Title: ${message.notification!.title}', name: 'FCM');
    developer.log('   📄 Body: ${message.notification!.body}', name: 'FCM');
  }

  if (message.data.isNotEmpty) {
    developer.log('   📦 Data: ${jsonEncode(message.data)}', name: 'FCM');
  }
}
