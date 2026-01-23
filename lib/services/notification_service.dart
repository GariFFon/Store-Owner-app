import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:developer' as developer;

/// Notification Service for handling in-app notifications
class NotificationService {
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize the notification service with navigator key
  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    developer.log(
      '✅ NotificationService: Initialized with navigator key',
      name: 'Notification',
    );
  }

  /// Show in-app notification for foreground messages
  static void showInAppNotification(RemoteMessage message) {
    if (_navigatorKey?.currentContext == null) {
      developer.log(
        '❌ NotificationService: No context available for in-app notification',
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
      '🔔 NotificationService: Showing in-app notification',
      name: 'Notification',
    );

    // Show a SnackBar with the notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (notification.title != null)
              Text(
                notification.title!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            if (notification.body != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  notification.body!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Handle notification tap
            _handleNotificationTap(message);
          },
        ),
      ),
    );
  }

  /// Handle notification tap
  static void _handleNotificationTap(RemoteMessage message) {
    developer.log(
      '👆 NotificationService: Notification tapped - opening app',
      name: 'Notification',
    );

    // Simply dismiss the notification snackbar/dialog
    // The app is already open since this is called from foreground notifications
    // No additional navigation is needed
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
                  _handleNotificationTap(message);
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
