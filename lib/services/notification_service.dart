import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/screens/order_details_screen.dart' as exanor_order_details;
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:exanor/services/api_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:exanor/utils/event_bus.dart';
import 'package:exanor/utils/platform_helper.dart';

/// Notification Service for handling in-app notifications
class NotificationService {
  static GlobalKey<NavigatorState>? _navigatorKey;
  static bool _tokenSentThisSession = false;
  static AudioPlayer? _audioPlayer;
  static int _soundPlayCount = 0;

  /// Initialize the notification service with navigator key
  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    _audioPlayer = AudioPlayer();
    developer.log(
      '✅ NotificationService: Initialized with navigator key and audio player',
      name: 'Notification',
    );
  }

  // Platform channel for native volume control
  static const MethodChannel _volumeChannel = MethodChannel(
    'com.exanor.exanor/volume',
  );

  /// Play the order notification sound
  static Future<void> playOrderSound() async {
    try {
      developer.log(
        '🔊 NotificationService: Playing notification sound',
        name: 'Notification',
      );

      // Use native Android code to play sound at max alarm volume
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await _volumeChannel.invokeMethod('playAlarmSoundAtMaxVolume');
          developer.log(
            '🔊 NotificationService: Native alarm sound playing at MAX volume',
            name: 'Notification',
          );
          return; // Native playback handles everything
        } catch (e) {
          developer.log(
            '⚠️ NotificationService: Native playback failed, falling back to audioplayers: $e',
            name: 'Notification',
          );
        }
      }

      // Fallback to audioplayers for iOS or if native fails
      _audioPlayer ??= AudioPlayer();

      await _audioPlayer!.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {AVAudioSessionOptions.duckOthers},
          ),
        ),
      );

      await _audioPlayer!.setVolume(1.0);

      // Play the sound 3 times for every order
      _soundPlayCount = 0;
      await _audioPlayer!.play(
        AssetSource('order_sound/Store-notification.mp3'),
        volume: 1.0,
      );

      // Listen for completion and replay up to 3 total times
      _audioPlayer!.onPlayerComplete.listen((_) async {
        _soundPlayCount++;
        if (_soundPlayCount < 2) {
          await Future.delayed(const Duration(milliseconds: 500));
          try {
            await _audioPlayer!.play(
              AssetSource('order_sound/Store-notification.mp3'),
              volume: 1.0,
            );
          } catch (_) {}
        }
      });
    } catch (e) {
      developer.log(
        '❌ NotificationService: Failed to play order sound: $e',
        name: 'Notification',
      );
    }
  }

  /// Stop any currently playing notification sound
  static Future<void> stopSound() async {
    try {
      // Stop native Android alarm sound
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await _volumeChannel.invokeMethod('stopAlarmSound');
        } catch (e) {
          // Ignore native stop errors
        }
      }

      // Also stop audioplayers (for iOS fallback)
      await _audioPlayer?.stop();
    } catch (e) {
      developer.log(
        '❌ NotificationService: Failed to stop sound: $e',
        name: 'Notification',
      );
    }
  }

  /// Get platform detection data
  static Map<String, bool> _getPlatformData() {
    return {
      'is_android': !kIsWeb && Platform.isAndroid,
      'is_ios': !kIsWeb && Platform.isIOS,
      'is_web': kIsWeb,
      'is_macos': !kIsWeb && Platform.isMacOS,
      'is_windows': !kIsWeb && Platform.isWindows,
      'is_linux': !kIsWeb && Platform.isLinux,
    };
  }

  /// Create notification token and send to server
  /// Call this method from authenticated screens' initState
  /// This method is idempotent - it only sends the token once per session
  static Future<void> createNotificationToken() async {
    // Only send token once per app session to avoid spamming the server
    if (_tokenSentThisSession) {
      developer.log(
        '📤 NotificationService: Token already sent this session, skipping',
        name: 'Notification',
      );
      return;
    }

    // Skip on platforms that don't support FCM
    if (!PlatformHelper.isPushNotificationSupported) {
      developer.log(
        '⚠️ NotificationService: FCM not supported on ${defaultTargetPlatform.name}',
        name: 'Notification',
      );
      return;
    }

    try {
      developer.log(
        '📤 NotificationService: Getting FCM token...',
        name: 'Notification',
      );

      // Get FCM token
      String? token = await FirebaseMessaging.instance.getToken();

      if (token == null) {
        developer.log(
          '❌ NotificationService: Failed to get FCM token',
          name: 'Notification',
        );
        return;
      }

      developer.log(
        '🔑 NotificationService: FCM token obtained: ${token.substring(0, 50)}...',
        name: 'Notification',
      );

      // Detect platform
      final platformData = _getPlatformData();

      // Send token to backend server
      await ApiService.post(
        '/create-notification-token/',
        body: {'fcm_token': token, ...platformData},
        useBearerToken: true,
      );

      _tokenSentThisSession = true;

      developer.log(
        '✅ NotificationService: FCM token sent to server successfully',
        name: 'Notification',
      );
    } catch (e) {
      developer.log(
        '❌ NotificationService: Failed to create notification token: $e',
        name: 'Notification',
      );
    }
  }

  /// Reset the token sent flag (call this on logout)
  static void resetTokenSentFlag() {
    _tokenSentThisSession = false;
    developer.log(
      '🔄 NotificationService: Token sent flag reset',
      name: 'Notification',
    );
  }

  // Debounce tracking to prevent notification spam
  static DateTime? _lastNotificationTime;
  static String? _lastNotificationId;

  /// Show in-app notification for foreground messages
  static void showInAppNotification(RemoteMessage message) {
    if (_navigatorKey?.currentContext == null) {
      developer.log(
        '❌ NotificationService: No context available for in-app notification',
        name: 'Notification',
      );
      return;
    }

    // Debounce: ignore duplicate notifications within 3 seconds
    final now = DateTime.now();
    final msgId = message.messageId ?? message.notification?.title ?? '';
    if (_lastNotificationTime != null &&
        _lastNotificationId == msgId &&
        now.difference(_lastNotificationTime!).inSeconds < 3) {
      developer.log(
        '⚠️ NotificationService: Debounced duplicate notification',
        name: 'Notification',
      );
      return;
    }
    _lastNotificationTime = now;
    _lastNotificationId = msgId;

    final context = _navigatorKey!.currentContext!;
    final notification = message.notification;

    if (notification == null) {
      developer.log(
        '⚠️ NotificationService: No notification data in message',
        name: 'Notification',
      );
      return;
    }

    developer.log(
      '🔔 NotificationService: Showing in-app notification',
      name: 'Notification',
    );

    // Auto-refresh orders screen
    EventBus().fire(OrderPlacedEvent());

    // 1. Play Haptic Feedback (Graceful handling, runs in parallel)
    Future(() async {
      try {
        // Continuous vibration for ~5 seconds (10 pulses x 500ms)
        for (int i = 0; i < 10; i++) {
          // Stop if context is gone (app closed/backgrounded)
          if (_navigatorKey?.currentContext == null) break;

          await HapticFeedback.vibrate();
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        // Ignore vibration errors
        developer.log(
          '⚠️ NotificationService: Haptics failed (non-fatal): $e',
          name: 'Notification',
        );
      }
    });

    // 2. Play Order Sound
    playOrderSound();

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryColor = const Color(0xFF2563EB); // Modern Blue tone
    final Color bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF); // Slate dark vs very light blue

    final screenWidth = MediaQuery.of(context).size.width;
    final double horizontalMargin = screenWidth > 600 ? (screenWidth - 450) / 2 : 16.0;

    // Show a premium SnackBar styled like the requested design
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              handleNotificationTap(message);
              // Stop sound when notification is tapped/dismissed
              stopSound();
            },
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: primaryColor.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.08), // Softer, colored shadow instead of black
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Icon Container
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shopping_bag_rounded, // Better icon for "New Order"
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // 2. Text Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (notification.title != null)
                          Text(
                            notification.title!,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              letterSpacing: 0.2,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (notification.title != null && notification.body != null)
                          const SizedBox(height: 4),
                        if (notification.body != null)
                          Text(
                            notification.body!,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // 3. Action Buttons (View & Close)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            stopSound();
                            handleNotificationTap(message); // Navigate to order
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: const Text(
                              'View',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Cancel / Cross Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            stopSound();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(horizontalMargin, 0, horizontalMargin, 24),
        padding: EdgeInsets.zero,
        duration: const Duration(seconds: 8), // 8 seconds duration
      ),
    );
  }

  /// Handle notification tap
  static void handleNotificationTap(RemoteMessage message) {
    developer.log(
      '👆 NotificationService: Notification tapped - handling navigation',
      name: 'Notification',
    );

    final context = _navigatorKey?.currentContext;
    if (context != null) {
      final data = message.data;
      final String? orderId = data['orderId'] ?? data['order_id'];
      final String? storeId = data['storeId'] ?? data['store_id'];

      if (orderId != null && orderId.isNotEmpty) {
        developer.log('Navigating directly to order: $orderId', name: 'Notification');
        // If orderId is provided, push the OrderDetailsScreen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => exanor_order_details.OrderDetailsScreen(
              orderId: orderId,
              storeId: storeId ?? '', // Requires storeId
            ),
          ),
        );
      } else {
        // Fallback: switch tab
        developer.log('Order ID not found, jumping to Orders tab', name: 'Notification');
        EventBus().fire(NavigateToTabEvent('orders'));
      }
    }
  }

  /// Show a custom dialog for important notifications
  static void showNotificationDialog(RemoteMessage message) {
    if (_navigatorKey?.currentContext == null) {
      developer.log(
        '❌ NotificationService: No context available for dialog',
        name: 'Notification',
      );
      return;
    }

    final context = _navigatorKey!.currentContext!;
    final notification = message.notification;

    if (notification == null) {
      developer.log(
        '⚠️ NotificationService: No notification data in message',
        name: 'Notification',
      );
      return;
    }

    developer.log(
      '📱 NotificationService: Showing notification dialog',
      name: 'Notification',
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: notification.title != null
              ? Text(notification.title!)
              : const Text('Notification'),
          content: notification.body != null
              ? Text(notification.body!)
              : const Text('You have a new notification'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Dismiss'),
            ),
            if (message.data.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  handleNotificationTap(message);
                },
                child: const Text('View'),
              ),
          ],
        );
      },
    );
  }

  /// Check if the app should show in-app notifications
  static bool shouldShowInAppNotification(RemoteMessage message) {
    // You can add logic here to determine when to show in-app notifications
    // For example, don't show if user is in a chat screen and the message is a chat message

    if (_navigatorKey?.currentContext == null) {
      return false;
    }

    // Check if the message has high priority
    final String? priority = message.data['priority'];
    if (priority == 'high') {
      return true;
    }

    // Check if it's a system notification
    final String? type = message.data['type'];
    if (type == 'system' || type == 'announcement') {
      return true;
    }

    // Default: show in-app notification for all foreground messages
    return true;
  }
}
