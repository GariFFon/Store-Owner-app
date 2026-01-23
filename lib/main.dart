import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/services/firebase_messaging_service.dart';
import 'package:exanor/services/notification_service.dart';
import 'package:exanor/services/translation_service.dart';
import 'package:exanor/screens/SplashScreen.dart';
import 'package:exanor/screens/onboarding_screen.dart';
import 'package:exanor/screens/phone_registration_screen.dart';
import 'package:exanor/screens/otp_verification_screen.dart';
import 'package:exanor/screens/HomeScreen.dart';
import 'package:exanor/screens/location_selection_screen.dart';
import 'package:exanor/screens/saved_addresses_screen.dart';
import 'package:exanor/screens/remote_config_debug_screen.dart';
import 'package:exanor/screens/orders_list_screen.dart';
// REMOVED: Deleted screens (chat, subscription, profiles, refer & earn, feed, taxi)

import 'package:exanor/config/theme_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:exanor/services/api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:exanor/services/enhanced_translation_service.dart';
import 'package:exanor/services/rewarded_ads_service.dart';
import 'package:exanor/services/interstitial_ads_service.dart';
import 'package:exanor/services/analytics_service.dart';
import 'package:exanor/services/crashlytics_service.dart';
import 'package:exanor/services/performance_service.dart';
import 'package:exanor/components/navigation_performance_tracker.dart';

/// Top-level function to handle background messages
/// This must be a top-level function, not a class method
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  developer.log(
    '📨 Background message received: ${message.messageId}',
    name: 'FCM',
  );

  // Handle background message here
  // You can update local storage, show notifications, etc.

  if (message.notification != null) {
    developer.log(
      '🔔 Background notification: ${message.notification!.title}',
      name: 'FCM',
    );
  }
}

/// Get platform detection data
Map<String, bool> _getPlatformData() {
  return {
    'is_android': !kIsWeb && Platform.isAndroid,
    'is_ios': !kIsWeb && Platform.isIOS,
    'is_web': kIsWeb,
    'is_macos': !kIsWeb && Platform.isMacOS,
    'is_windows': !kIsWeb && Platform.isWindows,
    'is_linux': !kIsWeb && Platform.isLinux,
  };
}

/// Initialize image picker plugin to avoid MissingPluginException
Future<void> _initializeImagePicker() async {
  try {
    // Force initialization of image_picker
    final ImagePicker picker = ImagePicker();
    print('📸 ImagePicker instance created: ${picker.hashCode}');

    // On Android, try to access the plugin early to trigger initialization
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Just accessing the instance isn't enough on some devices
      // Try to get available cameras which forces plugin registration
      try {
        // This will trigger plugin registration but might throw an exception
        // which we can safely ignore as we're just trying to initialize
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 1);
        print('📸 ImagePicker pre-initialized successfully');
      } catch (e) {
        // Ignore errors here, we're just trying to initialize the plugin
        print('📸 ImagePicker pre-initialization attempt: $e');
      }
    }

    // On iOS, try a different approach
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final status = await Permission.photos.status;
        print('📸 iOS photo permission status: $status');
      } catch (e) {
        print('📸 iOS permission check error: $e');
      }
    }
  } on MissingPluginException catch (e) {
    print('❌ Error initializing ImagePicker: $e');
  } catch (e) {
    print('❌ Unexpected error initializing ImagePicker: $e');
  }
}

/// Initialize translation services
Future<void> _initializeServices() async {
  try {
    // Initialize basic translation service
    await TranslationService.instance.initialize();

    // Initialize enhanced translation service
    await EnhancedTranslationService.instance.initialize();

    // Preload common translations for better performance
    await EnhancedTranslationService.instance.preloadCommonTranslations();

    // Set up crashlytics for translation services
    await CrashlyticsService.instance.setupTranslationErrorReporting(
      TranslationService.instance.currentLanguageCode,
    );

    print('✅ All translation services initialized successfully');
  } catch (e) {
    print('❌ Error initializing translation services: $e');
  }
}

/// Initialize Mobile Ads SDK
Future<void> _initializeMobileAds() async {
  try {
    await RewardedAdsService.initialize();
    await InterstitialAdsService.initialize();

    // Preload ads for better user experience (don't await these as they can take time)
    RewardedAdsService.instance.preloadAd();
    InterstitialAdsService.instance.preloadAd();

    // Set up crashlytics for ads
    await CrashlyticsService.instance.setupAdsErrorReporting();
  } catch (e) {
    print('❌ Error initializing Mobile Ads SDK: $e');
    rethrow;
  }
}

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  developer.log(
    '🚀 main() started - beginning app initialization',
    name: 'Main',
  );

  // Initialize API Service configuration with defaults first
  developer.log('🔧 Initializing API Service configuration...', name: 'Main');

  try {
    await ApiService.initializeConfiguration();
    developer.log(
      '✅ API Service configuration initialized successfully',
      name: 'Main',
    );
  } catch (e) {
    developer.log('❌ API Service configuration failed: $e', name: 'Main');
    developer.log('📝 Stack trace: ${StackTrace.current}', name: 'Main');
  }

  // Log current API configuration for debugging
  ApiService.logCurrentConfiguration();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize theme manager
  ThemeManager().initialize();

  // Initialize image picker
  // await _initializeImagePicker();

  // Set up the API service auth failure callback for navigation
  // This allows the API service to navigate to the login screen when auth fails
  ApiService.setAuthFailureCallback(() {
    // Navigate to phone registration screen when auth fails
    // You can use your navigation service or GoRouter here
    runApp(
      MaterialApp(home: SplashScreen(), navigatorKey: ApiService.navigatorKey),
    );
    // Note: The ApiService will handle navigation automatically through navigatorKey
    // We don't need to call runApp here as it restarts the entire app
  });

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  developer.log('✅ Firebase Core initialized successfully', name: 'Main');

  // Set up Firebase Messaging background handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  developer.log('✅ Firebase Messaging background handler set', name: 'Main');

  // NOW we can safely start performance tracing after Firebase is initialized
  developer.log('📊 Starting app startup performance trace...', name: 'Main');
  try {
    await PerformanceService.instance.initialize();
    await PerformanceService.instance.traceAppStartup();
    developer.log('✅ Performance tracing started successfully', name: 'Main');
  } catch (e) {
    developer.log('❌ Performance tracing failed: $e', name: 'Main');
  }

  // Initialize Firebase Crashlytics
  developer.log('💥 Initializing Firebase Crashlytics...', name: 'Main');
  try {
    // Initialize the Crashlytics service
    await CrashlyticsService.instance.initialize();

    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = (errorDetails) {
      developer.log(
        '💥 Flutter Error caught: ${errorDetails.exception}',
        name: 'Crashlytics',
      );
      CrashlyticsService.instance.recordFlutterFatalError(errorDetails);
    };

    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      developer.log('💥 Platform Error caught: $error', name: 'Crashlytics');
      CrashlyticsService.instance.recordError(error, stack, fatal: true);
      return true;
    };

    developer.log(
      '✅ Firebase Crashlytics initialized successfully',
      name: 'Main',
    );
  } catch (e) {
    developer.log(
      '❌ Firebase Crashlytics initialization failed: $e',
      name: 'Main',
    );
    developer.log('📝 Will continue without crash reporting', name: 'Main');
  }

  // Firebase Performance is already initialized above, just log success
  developer.log(
    '✅ Firebase Performance initialized successfully',
    name: 'Main',
  );

  // Initialize Firebase Remote Config
  developer.log('🔧 Initializing Firebase Remote Config...', name: 'Main');
  try {
    await FirebaseRemoteConfigService.initialize();
    developer.log(
      '✅ Firebase Remote Config initialized successfully',
      name: 'Main',
    );

    // IMPORTANT: Refresh API Service configuration after Remote Config loads
    developer.log(
      '🔄 Refreshing API Service with Remote Config values...',
      name: 'Main',
    );
    await ApiService.refreshConfiguration();
    developer.log(
      '✅ API Service refreshed with Remote Config values',
      name: 'Main',
    );

    // Log updated configuration
    ApiService.logCurrentConfiguration();
  } catch (e) {
    developer.log(
      '❌ Firebase Remote Config initialization failed: $e',
      name: 'Main',
    );
    developer.log('📝 Will continue with default values', name: 'Main');
  }

  // Initialize Translation Service (run in parallel with other non-critical services)
  final translationFuture = _initializeServices()
      .then((_) {
        developer.log(
          '✅ Translation Service initialized successfully',
          name: 'Main',
        );
      })
      .catchError((e) {
        developer.log(
          '❌ Translation Service initialization failed: $e',
          name: 'Main',
        );
        developer.log('📝 Will continue with English only', name: 'Main');
      });

  // Initialize Mobile Ads SDK (run in parallel)
  final adsFuture = _initializeMobileAds()
      .then((_) {
        developer.log(
          '✅ Mobile Ads SDK initialized successfully',
          name: 'Main',
        );
      })
      .catchError((e) {
        developer.log(
          '❌ Mobile Ads SDK initialization failed: $e',
          name: 'Main',
        );
        developer.log('📝 Will continue without ads', name: 'Main');
      });

  // Initialize Analytics Service (run in parallel)
  final analyticsFuture =
      Future(() {
        AnalyticsService().initialize();
        developer.log(
          '✅ Analytics Service initialized successfully',
          name: 'Main',
        );
      }).catchError((e) {
        developer.log(
          '❌ Analytics Service initialization failed: $e',
          name: 'Main',
        );
        developer.log('📝 Will continue without analytics', name: 'Main');
      });

  // Wait for all non-critical services to complete (run in parallel to improve startup time)
  developer.log(
    '🔄 Initializing non-critical services in parallel...',
    name: 'Main',
  );
  await Future.wait([translationFuture, adsFuture, analyticsFuture]);

  developer.log('🎯 main() completed - starting Flutter app', name: 'Main');

  // Complete app startup performance trace
  try {
    await PerformanceService.instance.completeAppStartupTrace();
    developer.log('✅ App startup trace completed', name: 'Main');
  } catch (e) {
    developer.log('❌ Failed to complete startup trace: $e', name: 'Main');
  }

  // Performance monitoring is now active for production use

  // Run the app within a zone to catch all async errors
  runZonedGuarded<Future<void>>(
    () async {
      runApp(const MyApp());
    },
    (error, stack) {
      developer.log('💥 Zone Error caught: $error', name: 'Crashlytics');
      CrashlyticsService.instance.recordError(error, stack, fatal: true);
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _initialMessage;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();

    // Initialize NotificationService with the navigator key
    NotificationService.initialize(ApiService.navigatorKey);

    // Set up Firebase Messaging listeners according to official documentation
    _setupFirebaseMessaging();
  }

  /// Set up Firebase Messaging listeners following official documentation pattern
  void _setupFirebaseMessaging() async {
    try {
      developer.log(
        '🔔 Setting up Firebase Messaging listeners...',
        name: 'FCM',
      );

      // Request notification permissions
      NotificationSettings settings = await FirebaseMessaging.instance
          .requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: true,
            sound: true,
          );

      developer.log(
        '📋 Notification permission: ${settings.authorizationStatus}',
        name: 'FCM',
      );

      // Get initial message (if app was opened from a notification)
      FirebaseMessaging.instance.getInitialMessage().then((
        RemoteMessage? message,
      ) {
        if (message != null) {
          developer.log(
            '📨 Initial message found: ${message.messageId}',
            name: 'FCM',
          );
          setState(() {
            _resolved = true;
            _initialMessage = message.messageId;
          });
          // App was opened from a notification - navigate to splash screen
          _navigateToSplashScreen();
        } else {
          developer.log('📨 No initial message found', name: 'FCM');
          setState(() {
            _resolved = true;
          });
        }
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        developer.log(
          '📨 Foreground message received: ${message.messageId}',
          name: 'FCM',
        );

        if (message.notification != null) {
          developer.log(
            '🔔 Foreground notification: ${message.notification!.title}',
            name: 'FCM',
          );
        }

        // Show in-app notification or handle as needed
        // The app is already open, so just show a notification
        if (NotificationService.shouldShowInAppNotification(message)) {
          NotificationService.showInAppNotification(message);
        }
      });

      // Handle notification taps when app is in background or terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        developer.log(
          '📨 Notification tapped - opening splash screen: ${message.messageId}',
          name: 'FCM',
        );

        if (message.notification != null) {
          developer.log(
            '🔔 Opened from notification: ${message.notification!.title}',
            name: 'FCM',
          );
        }

        // Always navigate to splash screen - simplest and most reliable approach
        _navigateToSplashScreen();
      });

      // Get and send FCM token to server
      String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        developer.log(
          '🔑 FCM token obtained: ${token.substring(0, 50)}...',
          name: 'FCM',
        );
        _sendTokenToServer(token);
      }

      // Listen for token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((String token) {
        developer.log(
          '🔄 FCM token refreshed: ${token.substring(0, 50)}...',
          name: 'FCM',
        );
        _sendTokenToServer(token);
      });

      developer.log(
        '✅ Firebase Messaging listeners set up successfully',
        name: 'FCM',
      );
    } catch (e) {
      developer.log('❌ Error setting up Firebase Messaging: $e', name: 'FCM');
    }
  }

  /// Navigate to splash screen - handles all app flow logic
  void _navigateToSplashScreen() {
    try {
      developer.log(
        '🚀 Navigating to splash screen from notification',
        name: 'FCM',
      );

      // Use the navigator key to navigate to splash screen
      if (ApiService.navigatorKey.currentState != null) {
        ApiService.navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SplashScreen()),
          (route) => false,
        );
        developer.log('✅ Navigation to splash screen completed', name: 'FCM');
      } else {
        developer.log('❌ Navigator key not available', name: 'FCM');
      }
    } catch (e) {
      developer.log('❌ Error navigating to splash screen: $e', name: 'FCM');
    }
  }

  /// Send FCM token to server
  void _sendTokenToServer(String token) {
    try {
      developer.log('📤 Sending FCM token to server...', name: 'FCM');

      // Detect platform
      final platformData = _getPlatformData();

      // Send token to backend server
      ApiService.post(
            '/create-notification-token/',
            body: {'fcm_token': token, ...platformData},
            useBearerToken: true,
          )
          .then((response) {
            developer.log(
              '✅ FCM token sent to server successfully',
              name: 'FCM',
            );
          })
          .catchError((error) {
            developer.log(
              '❌ Failed to send FCM token to server: $error',
              name: 'FCM',
            );
          });
    } catch (e) {
      developer.log('❌ Error in _sendTokenToServer: $e', name: 'FCM');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeManager(),
      builder: (context, child) {
        return AnimatedTheme(
          duration: ThemeManager.animationDuration,
          curve: ThemeManager.animationCurve,
          data: ThemeManager().getTheme(context),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'exanor',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeManager().materialThemeMode,
            navigatorKey: ApiService.navigatorKey,
            navigatorObservers: [
              AnalyticsService().observer,
              NavigationPerformanceObserver(),
            ],
            home: const SplashScreen(),
            // Note: Translation system is now integrated throughout the app
            // - Bottom Navigation: Translated labels for Home, Register, Refer, Messages, Alerts
            // - Category Lists: API responses translated (Professionals, Businesses, Employees, subcategories)
            // - Search Screen: Translated title, placeholders, error messages, and search results
            // - Sliver App Bar: Translated search text, category names, error messages
            // - Universal Translation: All user-facing text automatically translated
            // - Language Selector: Beautiful UI with 20+ languages including 8 Indian languages
            // - Profile Screen: User data and UI text translated
            // - Home Screen: Section headers and help text translated
            // Access language selector: FAB on home screen or language tools in selector
            routes: {
              '/onboarding': (context) => const OnboardingScreen(),
              '/phone_registration': (context) =>
                  const PhoneRegistrationScreen(),
              '/otp_verification': (context) =>
                  const OTPVerificationScreen(phoneNumber: ''),
              '/home': (context) => const HomeScreen(),
              '/location_selection': (context) =>
                  const LocationSelectionScreen(),
              '/saved_addresses': (context) => const SavedAddressesScreen(),
              '/remote_config_debug': (context) =>
                  const RemoteConfigDebugScreen(),
              '/orders': (context) => const OrdersListScreen(),
              '/restart_app': (context) => const SplashScreen(),
              // REMOVED: Routes for deleted screens (profiles, chat, subscription, etc.)
            },
          ),
        );
      },
    );
  }
}
