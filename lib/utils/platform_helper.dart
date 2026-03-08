import 'package:flutter/foundation.dart';

/// Platform helper utilities for cross-platform support.
/// Provides easy checks for which platform features are available.
class PlatformHelper {
  /// Returns true if the app is running on a mobile device (Android/iOS)
  static bool get isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Returns true if the app is running on a desktop platform (Windows/macOS/Linux)
  static bool get isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// Returns true if the app is running on Windows
  static bool get isWindows => defaultTargetPlatform == TargetPlatform.windows;

  /// Returns true if the app is running on Android
  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Returns true if the app is running on iOS
  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// Returns true if Firebase is supported on the current platform.
  /// Firebase is only fully supported on Android, iOS, macOS, and Web.
  static bool get isFirebaseSupported => isMobile;

  /// Returns true if Google Mobile Ads is supported.
  /// Only supported on Android and iOS.
  static bool get isAdsSupported => isMobile;

  /// Returns true if Google ML Kit (translation) is supported.
  /// Only supported on Android and iOS.
  static bool get isMLKitSupported => isMobile;

  /// Returns true if in-app updates (Play Store) are supported.
  /// Only supported on Android.
  static bool get isInAppUpdateSupported =>
      defaultTargetPlatform == TargetPlatform.android;

  /// Returns true if in-app purchases are supported.
  /// Only supported on Android and iOS.
  static bool get isInAppPurchaseSupported => isMobile;

  /// Returns true if Google Maps native view is supported.
  /// Only supported on Android and iOS.
  static bool get isGoogleMapsNativeSupported => isMobile;

  /// Returns true if mobile QR scanner (camera-based) is supported.
  /// Only supported on Android and iOS.
  static bool get isCameraScannerSupported => isMobile;

  /// Returns true if Bluetooth thermal printing is supported.
  /// Only supported on Android and iOS.
  static bool get isBluetoothPrintingSupported => isMobile;

  /// Returns true if fast_contacts is supported.
  /// Only supported on Android and iOS.
  static bool get isContactsSupported => isMobile;

  /// Returns true if push notifications (FCM) are supported.
  /// Only supported on Android and iOS.
  static bool get isPushNotificationSupported => isMobile;

  /// Returns true if PDF printing is supported (works cross-platform).
  static bool get isPdfPrintingSupported => true;

  /// Returns true if speech-to-text is supported (works cross-platform).
  static bool get isSpeechToTextSupported => true;

  /// Returns true if WebView is supported on the current platform.
  /// Supported on Android, iOS, and Windows (with webview_flutter_windows).
  static bool get isWebViewSupported => isMobile || isWindows;

  /// Log platform info for debugging
  static void logPlatformInfo() {
    if (kDebugMode) {
      print('═══════════════════════════════════════════');
      print('🖥️ Platform: $defaultTargetPlatform');
      print('📱 isMobile: $isMobile');
      print('🖥️ isDesktop: $isDesktop');
      print('🪟 isWindows: $isWindows');
      print('🔥 Firebase: $isFirebaseSupported');
      print('📢 Ads: $isAdsSupported');
      print('🌐 ML Kit: $isMLKitSupported');
      print('🔔 Push Notifications: $isPushNotificationSupported');
      print('🗺️ Google Maps Native: $isGoogleMapsNativeSupported');
      print('📷 Camera Scanner: $isCameraScannerSupported');
      print('🖨️ PDF Printing: $isPdfPrintingSupported');
      print('🎙️ Speech-to-Text: $isSpeechToTextSupported');
      print('═══════════════════════════════════════════');
    }
  }
}
