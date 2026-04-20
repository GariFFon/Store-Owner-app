import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/notification_service.dart';
import 'package:exanor/utils/event_bus.dart';
import 'dart:developer' as developer;

class WindowsNotificationService {
  static Timer? _pollingTimer;
  static String? _lastKnownOrderId;
  static bool _isInitialized = false;

  /// Initialize local_notifier for Windows
  static Future<void> initialize() async {
    if (kIsWeb || !Platform.isWindows) return;
    
    if (_isInitialized) return;

    try {
      await localNotifier.setup(
        appName: 'exanorStore',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _isInitialized = true;
      developer.log('✅ WindowsNotificationService: local_notifier initialized', name: 'WindowsNotification');
    } catch (e) {
      developer.log('❌ WindowsNotificationService: Failed to initialize local_notifier: $e', name: 'WindowsNotification');
    }
  }

  /// Start polling for new orders (run this when store ID is known, e.g., on login or store selection)
  static void startPolling(String storeId) {
    if (kIsWeb || !Platform.isWindows) return;

    // Stop existing timer
    stopPolling();

    developer.log('🔄 WindowsNotificationService: Starting order polling for store $storeId', name: 'WindowsNotification');

    // Poll every 45 seconds to reduce backend overhead
    _pollingTimer = Timer.periodic(const Duration(seconds: 45), (timer) async {
      await _checkNewOrders(storeId);
    });
    
    // Check immediately as well
    _checkNewOrders(storeId);
  }

  static void stopPolling() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
      developer.log('🛑 WindowsNotificationService: Polling stopped', name: 'WindowsNotification');
    }
  }

  static Future<void> _checkNewOrders(String storeId) async {
    try {
      final response = await ApiService.post(
        '/orders/',
        body: {
          "query": {"status": "order_placed"}, // only look for new unmatched orders
          "page": 1,
          "page_size": 1,
          "store_id": storeId,
          "store_access": true,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          final orders = List<dynamic>.from(data['response']);
          if (orders.isNotEmpty) {
            final latestOrder = orders.first;
            final currentOrderId = latestOrder['id']?.toString();
            final orderToken = latestOrder['token_number']?.toString() ?? 'New';
            
            if (currentOrderId != null) {
              if (_lastKnownOrderId == null) {
                // First poll, just record
                _lastKnownOrderId = currentOrderId;
              } else if (_lastKnownOrderId != currentOrderId) {
                // New order discovered!
                _lastKnownOrderId = currentOrderId;
                
                developer.log('🔔 WindowsNotificationService: New order discovered!', name: 'WindowsNotification');
                
                // Play order sound
                NotificationService.playOrderSound();
                
                // Show Windows system notification
                _showSystemNotification(orderToken, currentOrderId);
                
                // Fire event so app refreshes UI
                EventBus().fire(OrderPlacedEvent());
              }
            }
          }
        }
      }
    } catch (e) {
      developer.log('❌ WindowsNotificationService: Polling error: $e', name: 'WindowsNotification');
    }
  }

  static void _showSystemNotification(String tokenNumber, String orderId) {
    if (!_isInitialized) return;
    
    try {
      LocalNotification notification = LocalNotification(
        title: "New Order Arrived!",
        body: "Token #$tokenNumber has just been placed.",
      );
      
      notification.onShow = () {
        developer.log('🔔 LocalNotification: token $tokenNumber shown');
      };
      
      notification.onClick = () {
        // App can be brought to front here if possible, but local_notifier will just focus the window usually.
        // Also stop the sound
        NotificationService.stopSound();
        EventBus().fire(OrderPlacedEvent());
      };

      notification.show();
    } catch (e) {
      developer.log('❌ LocalNotification error: $e');
    }
  }
}
