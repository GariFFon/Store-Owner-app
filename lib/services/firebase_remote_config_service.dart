import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'dart:developer' as developer;
import 'dart:convert';

class FirebaseRemoteConfigService {
  static FirebaseRemoteConfig? _remoteConfig;
  static bool _isInitialized = false;

  // Configuration keys - replace with your actual parameter names
  static const String _baseUrlKey = 'baseUrl';
  static const String _bareBaseUrlKey = 'bareBaseUrl';
  static const String _apiTimeoutKey = 'api_timeout_seconds';
  static const String _enableDebugModeKey = 'enable_debug_mode';
  static const String _appVersionKey = 'min_app_version';

  // Search configuration keys
  static const String _searchRadiusKey = 'searchRadius';
  static const String _searchStatusKey = 'searchStatus';
  static const String _searchOrderByKey = 'searchOrderBy';

  // Onboarding screen image URLs
  static const String _onboardingImg1Key = 'onboardingScreenImgUrl1';
  static const String _onboardingImg2Key = 'onboardingScreenImgUrl2';
  static const String _onboardingImg3Key = 'onboardingScreenImgUrl3';

  // Support page URLs
  static const String _privacyPolicyKey = 'privacyPolicy';
  static const String _refundPolicyKey = 'refundPolicy';
  static const String _termsAndConditionsKey = 'termsAndConditions';
  static const String _termsOfServiceKey = 'termsOfService';
  static const String _aboutUsKey = 'aboutUs';
  static const String _disclaimerKey = 'disclaimer';
  static const String _deleteAccountKey = 'deleteAccount';
  static const String _contactUsKey = 'contactUs';

  // App download URL
  static const String _appDownloadUrlKey = 'app_download_url';

  // App startup ad image URL
  static const String _appStartupAdImgUrlKey = 'app_startup_ad_img_url';

  // Referral reward amount
  static const String _referralRewardAmountKey = 'referral_reward_amount';

  // Bottom navigation tabs configuration
  static const String _bottomNavBarTabsKey = 'bottomNavBarTabs';

  // Dashboard section configuration
  static const String _dashboardSectionKey = 'dashboardSection';

  // Default values
  static const Map<String, dynamic> _defaults = {
    _baseUrlKey: 'https://development.api.exanor.com/api/v1',
    _bareBaseUrlKey: 'https://development.api.exanor.com',
    _apiTimeoutKey: 30,
    _enableDebugModeKey: false,
    _appVersionKey: '1.0.0',

    // Search defaults
    _searchRadiusKey: 1000,
    _searchStatusKey: 'active',
    _searchOrderByKey: 'ranking',
    _onboardingImg1Key:
        'https://images.unsplash.com/photo-1551434678-e076c223a692?w=400&h=600&fit=crop',
    _onboardingImg2Key:
        'https://images.unsplash.com/photo-1557804506-669a67965ba0?w=400&h=600&fit=crop',
    _onboardingImg3Key:
        'https://images.unsplash.com/photo-1552581234-26160f608093?w=400&h=600&fit=crop',

    // Support page URLs defaults
    _privacyPolicyKey: 'https://exanor.com/privacy-policy',
    _refundPolicyKey: 'https://exanor.com/refund-policy',
    _termsAndConditionsKey: 'https://exanor.com/terms-and-conditions',
    _termsOfServiceKey: 'https://exanor.com/terms-of-service',
    _aboutUsKey: 'https://exanor.com/about-us',
    _disclaimerKey: 'https://exanor.com/disclaimer',
    _deleteAccountKey: 'https://exanor.com/delete-account',
    _contactUsKey: 'https://exanor.com/contact-us',

    // App download URL default
    _appDownloadUrlKey: 'https://exanor.com/download',

    // App startup ad image URL default (empty by default)
    _appStartupAdImgUrlKey: '',

    // Referral reward amount default
    _referralRewardAmountKey: 100,

    // Bottom navigation tabs default configuration
    _bottomNavBarTabsKey: '''[
      {
        "id": "home",
        "label": "Home",
        "icon": "home_outlined",
        "activeIcon": "home",
        "action": "navigate",
        "actionData": "/home",
        "badgeType": "none",
        "index": 0
      },
      {
        "id": "register",
        "label": "Register",
        "icon": "person_add_outlined",
        "activeIcon": "person_add",
        "action": "showRegistration",
        "actionData": null,
        "badgeType": "freeBadge",
        "index": 1
      },
      {
        "id": "refer",
        "label": "Refer & Earn",
        "icon": "card_giftcard_outlined",
        "activeIcon": "card_giftcard",
        "action": "navigate",
        "actionData": "/refer_and_earn",
        "badgeType": "goldenBadge",
        "index": 2
      },
      {
        "id": "translate",
        "label": "Translate",
        "icon": "translate_outlined",
        "activeIcon": "translate",
        "action": "showLanguageSelector",
        "actionData": null,
        "badgeType": "none",
        "index": 3
      },
      {
        "id": "feed",
        "label": "Feed",
        "icon": "play_circle_outline",
        "activeIcon": "play_circle_filled",
        "action": "navigate",
        "actionData": "/feed",
        "badgeType": "none",
        "index": 4
      }
    ]''',

    // Dashboard section default configuration
    _dashboardSectionKey: '''[
      {
        "id": "professional",
        "title": "Professional",
        "subtitle": "Showcase skills",
        "icon": "person_outline_rounded",
        "gradientColors": ["#42A5F5", "#AB47BC"],
        "action": "handleProfessionalProfile",
        "enabled": true,
        "order": 0
      },
      {
        "id": "employee",
        "title": "Employee",
        "subtitle": "Find jobs",
        "icon": "work_outline_rounded",
        "gradientColors": ["#66BB6A", "#26A69A"],
        "action": "handleEmployeeProfile",
        "enabled": true,
        "order": 1
      },
      {
        "id": "business",
        "title": "Business",
        "subtitle": "Grow reach",
        "icon": "business_outlined",
        "gradientColors": ["#FFA726", "#F44336"],
        "action": "navigateToBusinesses",
        "enabled": true,
        "order": 2
      }
    ]''',
  };

  /// Initialize Firebase Remote Config
  static Future<void> initialize() async {
    try {
      developer.log(
        '🔧 FirebaseRemoteConfig: Starting initialization...',
        name: 'RemoteConfig',
      );

      // Get Remote Config instance
      _remoteConfig = FirebaseRemoteConfig.instance;
      developer.log(
        '✅ FirebaseRemoteConfig: Instance obtained successfully',
        name: 'RemoteConfig',
      );

      // Set configuration settings
      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(minutes: 5), // For development
        ),
      );
      developer.log(
        '⚙️ FirebaseRemoteConfig: Config settings applied - fetchTimeout: 1min, minimumFetchInterval: 5min',
        name: 'RemoteConfig',
      );

      // Set default values
      await _remoteConfig!.setDefaults(_defaults);
      developer.log(
        '📋 FirebaseRemoteConfig: Default values set: $_defaults',
        name: 'RemoteConfig',
      );

      // Fetch and activate values
      await fetchAndActivate();

      // Set up real-time listener
      _setupRealTimeListener();

      _isInitialized = true;
      developer.log(
        '✅ FirebaseRemoteConfig: Initialization completed successfully',
        name: 'RemoteConfig',
      );
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Initialization failed: $e',
        name: 'RemoteConfig',
      );
      developer.log(
        '📝 FirebaseRemoteConfig: Stack trace: ${StackTrace.current}',
        name: 'RemoteConfig',
      );
      rethrow;
    }
  }

  /// Fetch and activate remote config values
  static Future<bool> fetchAndActivate() async {
    try {
      if (_remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, cannot fetch',
          name: 'RemoteConfig',
        );
        return false;
      }

      developer.log(
        '🔄 FirebaseRemoteConfig: Starting fetch and activate...',
        name: 'RemoteConfig',
      );

      final bool activated = await _remoteConfig!.fetchAndActivate();

      if (activated) {
        developer.log(
          '✅ FirebaseRemoteConfig: Fetch and activate successful - new values activated',
          name: 'RemoteConfig',
        );
        _logCurrentValues();
      } else {
        developer.log(
          '📋 FirebaseRemoteConfig: Fetch completed but no new values to activate',
          name: 'RemoteConfig',
        );
      }

      return activated;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Fetch and activate failed: $e',
        name: 'RemoteConfig',
      );
      return false;
    }
  }

  /// Set up real-time listener for config updates
  static void _setupRealTimeListener() {
    try {
      developer.log(
        '👂 FirebaseRemoteConfig: Setting up real-time listener...',
        name: 'RemoteConfig',
      );

      _remoteConfig!.onConfigUpdated.listen((event) async {
        developer.log(
          '🔔 FirebaseRemoteConfig: Real-time update received!',
          name: 'RemoteConfig',
        );

        try {
          await _remoteConfig!.activate();
          developer.log(
            '✅ FirebaseRemoteConfig: Real-time update activated successfully',
            name: 'RemoteConfig',
          );
          _logCurrentValues();
        } catch (e) {
          developer.log(
            '❌ FirebaseRemoteConfig: Failed to activate real-time update: $e',
            name: 'RemoteConfig',
          );
        }
      });

      developer.log(
        '✅ FirebaseRemoteConfig: Real-time listener set up successfully',
        name: 'RemoteConfig',
      );
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Failed to set up real-time listener: $e',
        name: 'RemoteConfig',
      );
    }
  }

  /// Log current configuration values for debugging
  static void _logCurrentValues() {
    try {
      developer.log(
        '📊 FirebaseRemoteConfig: Current configuration values:',
        name: 'RemoteConfig',
      );
      developer.log('   📍 Base URL: ${getBaseUrl()}', name: 'RemoteConfig');
      developer.log(
        '   📍 Bare Base URL: ${getBareBaseUrl()}',
        name: 'RemoteConfig',
      );
      developer.log(
        '   ⏰ API Timeout: ${getApiTimeout()}s',
        name: 'RemoteConfig',
      );
      developer.log(
        '   🐛 Debug Mode: ${isDebugModeEnabled()}',
        name: 'RemoteConfig',
      );
      developer.log(
        '   📱 Min App Version: ${getMinAppVersion()}',
        name: 'RemoteConfig',
      );
      developer.log(
        '   🔍 Search Radius: ${getSearchRadius()}',
        name: 'RemoteConfig',
      );
      developer.log(
        '   📋 Search Status: ${getSearchStatus()}',
        name: 'RemoteConfig',
      );
      developer.log(
        '   📊 Search Order By: ${getSearchOrderBy()}',
        name: 'RemoteConfig',
      );
      developer.log(
        '   📊 Last Fetch Status: ${_remoteConfig?.lastFetchStatus}',
        name: 'RemoteConfig',
      );
      developer.log(
        '   🕐 Last Fetch Time: ${_remoteConfig?.lastFetchTime}',
        name: 'RemoteConfig',
      );
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error logging current values: $e',
        name: 'RemoteConfig',
      );
    }
  }

  /// Get base URL from Remote Config
  static String getBaseUrl() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default base URL',
          name: 'RemoteConfig',
        );
        return _defaults[_baseUrlKey] as String;
      }

      final value = _remoteConfig!.getString(_baseUrlKey);
      developer.log(
        '📍 FirebaseRemoteConfig: Retrieved base URL: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting base URL: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_baseUrlKey] as String;
    }
  }

  /// Get bare base URL from Remote Config
  static String getBareBaseUrl() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default bare base URL',
          name: 'RemoteConfig',
        );
        return _defaults[_bareBaseUrlKey] as String;
      }

      final value = _remoteConfig!.getString(_bareBaseUrlKey);
      developer.log(
        '📍 FirebaseRemoteConfig: Retrieved bare base URL: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting bare base URL: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_bareBaseUrlKey] as String;
    }
  }

  /// Get API timeout from Remote Config
  static int getApiTimeout() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default timeout',
          name: 'RemoteConfig',
        );
        return _defaults[_apiTimeoutKey] as int;
      }

      final value = _remoteConfig!.getInt(_apiTimeoutKey);
      developer.log(
        '⏰ FirebaseRemoteConfig: Retrieved API timeout: ${value}s',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting API timeout: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_apiTimeoutKey] as int;
    }
  }

  /// Check if debug mode is enabled
  static bool isDebugModeEnabled() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default debug mode',
          name: 'RemoteConfig',
        );
        return _defaults[_enableDebugModeKey] as bool;
      }

      final value = _remoteConfig!.getBool(_enableDebugModeKey);
      developer.log(
        '🐛 FirebaseRemoteConfig: Retrieved debug mode: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting debug mode: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_enableDebugModeKey] as bool;
    }
  }

  /// Get minimum app version
  static String getMinAppVersion() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default app version',
          name: 'RemoteConfig',
        );
        return _defaults[_appVersionKey] as String;
      }

      final value = _remoteConfig!.getString(_appVersionKey);
      developer.log(
        '📱 FirebaseRemoteConfig: Retrieved min app version: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting min app version: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_appVersionKey] as String;
    }
  }

  /// Get search radius from Remote Config
  static int getSearchRadius() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default search radius',
          name: 'RemoteConfig',
        );
        return _defaults[_searchRadiusKey] as int;
      }

      final value = _remoteConfig!.getInt(_searchRadiusKey);
      developer.log(
        '🔍 FirebaseRemoteConfig: Retrieved search radius: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting search radius: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_searchRadiusKey] as int;
    }
  }

  /// Get search status from Remote Config
  static String getSearchStatus() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default search status',
          name: 'RemoteConfig',
        );
        return _defaults[_searchStatusKey] as String;
      }

      final value = _remoteConfig!.getString(_searchStatusKey);
      developer.log(
        '📋 FirebaseRemoteConfig: Retrieved search status: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting search status: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_searchStatusKey] as String;
    }
  }

  /// Get search order by from Remote Config
  static String getSearchOrderBy() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default search order by',
          name: 'RemoteConfig',
        );
        return _defaults[_searchOrderByKey] as String;
      }

      final value = _remoteConfig!.getString(_searchOrderByKey);
      developer.log(
        '📊 FirebaseRemoteConfig: Retrieved search order by: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting search order by: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_searchOrderByKey] as String;
    }
  }

  /// Get onboarding screen image URL 1
  static String getOnboardingImg1Url() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default onboarding img 1',
          name: 'RemoteConfig',
        );
        return _defaults[_onboardingImg1Key] as String;
      }

      final value = _remoteConfig!.getString(_onboardingImg1Key);
      developer.log(
        '🖼️ FirebaseRemoteConfig: Retrieved onboarding img 1: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting onboarding img 1: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_onboardingImg1Key] as String;
    }
  }

  /// Get onboarding screen image URL 2
  static String getOnboardingImg2Url() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default onboarding img 2',
          name: 'RemoteConfig',
        );
        return _defaults[_onboardingImg2Key] as String;
      }

      final value = _remoteConfig!.getString(_onboardingImg2Key);
      developer.log(
        '🖼️ FirebaseRemoteConfig: Retrieved onboarding img 2: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting onboarding img 2: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_onboardingImg2Key] as String;
    }
  }

  /// Get onboarding screen image URL 3
  static String getOnboardingImg3Url() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default onboarding img 3',
          name: 'RemoteConfig',
        );
        return _defaults[_onboardingImg3Key] as String;
      }

      final value = _remoteConfig!.getString(_onboardingImg3Key);
      developer.log(
        '🖼️ FirebaseRemoteConfig: Retrieved onboarding img 3: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting onboarding img 3: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_onboardingImg3Key] as String;
    }
  }

  /// Get Privacy Policy URL
  static String getPrivacyPolicyUrl() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default privacy policy URL',
          name: 'RemoteConfig',
        );
        return _defaults[_privacyPolicyKey] as String;
      }

      final value = _remoteConfig!.getString(_privacyPolicyKey);
      developer.log(
        '🔗 FirebaseRemoteConfig: Retrieved privacy policy URL: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting privacy policy URL: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_privacyPolicyKey] as String;
    }
  }

  /// Get Refund Policy URL
  static String getRefundPolicyUrl() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default refund policy URL',
          name: 'RemoteConfig',
        );
        return _defaults[_refundPolicyKey] as String;
      }

      final value = _remoteConfig!.getString(_refundPolicyKey);
      developer.log(
        '🔗 FirebaseRemoteConfig: Retrieved refund policy URL: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting refund policy URL: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_refundPolicyKey] as String;
    }
  }

  /// Get Terms and Conditions URL
  static String getTermsAndConditionsUrl() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default terms and conditions URL',
          name: 'RemoteConfig',
        );
        return _defaults[_termsAndConditionsKey] as String;
      }

      final value = _remoteConfig!.getString(_termsAndConditionsKey);
      developer.log(
        '🔗 FirebaseRemoteConfig: Retrieved terms and conditions URL: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting terms and conditions URL: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_termsAndConditionsKey] as String;
    }
  }

  /// Get Terms of Service URL
  static String getTermsOfServiceUrl() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default terms of service URL',
          name: 'RemoteConfig',
        );
        return _defaults[_termsOfServiceKey] as String;
      }

      final value = _remoteConfig!.getString(_termsOfServiceKey);
      developer.log(
        '🔗 FirebaseRemoteConfig: Retrieved terms of service URL: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting terms of service URL: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_termsOfServiceKey] as String;
    }
  }

  /// Get About Us URL
  static String getAboutUsUrl() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default about us URL',
          name: 'RemoteConfig',
        );
        return _defaults[_aboutUsKey] as String;
      }

      final value = _remoteConfig!.getString(_aboutUsKey);
      developer.log(
        '🔗 FirebaseRemoteConfig: Retrieved about us URL: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting about us URL: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_aboutUsKey] as String;
    }
  }

  /// Get Disclaimer URL
  static String getDisclaimerUrl() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default disclaimer URL',
          name: 'RemoteConfig',
        );
        return _defaults[_disclaimerKey] as String;
      }

      final value = _remoteConfig!.getString(_disclaimerKey);
      developer.log(
        '🔗 FirebaseRemoteConfig: Retrieved disclaimer URL: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting disclaimer URL: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_disclaimerKey] as String;
    }
  }

  /// Get Delete Account URL
  static String getDeleteAccountUrl() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default delete account URL',
          name: 'RemoteConfig',
        );
        return _defaults[_deleteAccountKey] as String;
      }

      final value = _remoteConfig!.getString(_deleteAccountKey);
      developer.log(
        '🔗 FirebaseRemoteConfig: Retrieved delete account URL: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting delete account URL: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_deleteAccountKey] as String;
    }
  }

  /// Get Contact Us URL
  static String getContactUsUrl() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default contact us URL',
          name: 'RemoteConfig',
        );
        return _defaults[_contactUsKey] as String;
      }

      final value = _remoteConfig!.getString(_contactUsKey);
      developer.log(
        '🔗 FirebaseRemoteConfig: Retrieved contact us URL: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting contact us URL: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_contactUsKey] as String;
    }
  }

  /// Get App Download URL
  static String getAppDownloadUrl() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default app download URL',
          name: 'RemoteConfig',
        );
        return _defaults[_appDownloadUrlKey] as String;
      }

      final value = _remoteConfig!.getString(_appDownloadUrlKey);
      developer.log(
        '🔗 FirebaseRemoteConfig: Retrieved app download URL: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting app download URL: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_appDownloadUrlKey] as String;
    }
  }

  /// Get App Startup Ad Image URL
  static String getAppStartupAdImgUrl() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default app startup ad image URL',
          name: 'RemoteConfig',
        );
        return _defaults[_appStartupAdImgUrlKey] as String;
      }

      final value = _remoteConfig!.getString(_appStartupAdImgUrlKey);
      developer.log(
        '🖼️ FirebaseRemoteConfig: Retrieved app startup ad image URL: $value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting app startup ad image URL: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_appStartupAdImgUrlKey] as String;
    }
  }

  /// Get Referral Reward Amount
  static int getReferralRewardAmount() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default referral reward amount',
          name: 'RemoteConfig',
        );
        return _defaults[_referralRewardAmountKey] as int;
      }

      final value = _remoteConfig!.getInt(_referralRewardAmountKey);
      developer.log(
        '💰 FirebaseRemoteConfig: Retrieved referral reward amount: ₹$value',
        name: 'RemoteConfig',
      );
      return value;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting referral reward amount: $e, returning default',
        name: 'RemoteConfig',
      );
      return _defaults[_referralRewardAmountKey] as int;
    }
  }

  /// Get Bottom Navigation Tabs Configuration
  static List<Map<String, dynamic>> getBottomNavBarTabs() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default bottom navigation tabs',
          name: 'RemoteConfig',
        );
        return List<Map<String, dynamic>>.from(
          jsonDecode(_defaults[_bottomNavBarTabsKey] as String),
        );
      }

      final value = _remoteConfig!.getString(_bottomNavBarTabsKey);
      developer.log(
        '🧭 FirebaseRemoteConfig: Retrieved bottom navigation tabs: $value',
        name: 'RemoteConfig',
      );
      return List<Map<String, dynamic>>.from(jsonDecode(value));
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting bottom navigation tabs: $e, returning default',
        name: 'RemoteConfig',
      );
      return List<Map<String, dynamic>>.from(
        jsonDecode(_defaults[_bottomNavBarTabsKey] as String),
      );
    }
  }

  /// Get Dashboard Section Configuration
  static List<Map<String, dynamic>> getDashboardSection() {
    try {
      if (!_isInitialized || _remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, returning default dashboard section',
          name: 'RemoteConfig',
        );
        return List<Map<String, dynamic>>.from(
          jsonDecode(_defaults[_dashboardSectionKey] as String),
        );
      }

      final value = _remoteConfig!.getString(_dashboardSectionKey);
      developer.log(
        '📊 FirebaseRemoteConfig: Retrieved dashboard section: $value',
        name: 'RemoteConfig',
      );
      return List<Map<String, dynamic>>.from(jsonDecode(value));
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting dashboard section: $e, returning default',
        name: 'RemoteConfig',
      );
      return List<Map<String, dynamic>>.from(
        jsonDecode(_defaults[_dashboardSectionKey] as String),
      );
    }
  }

  /// Get all configuration as a map for debugging
  static Map<String, dynamic> getAllConfig() {
    try {
      developer.log(
        '📊 FirebaseRemoteConfig: Retrieving all configuration values...',
        name: 'RemoteConfig',
      );

      final config = {
        'base_url': getBaseUrl(),
        'bare_base_url': getBareBaseUrl(),
        'api_timeout_seconds': getApiTimeout(),
        'enable_debug_mode': isDebugModeEnabled(),
        'min_app_version': getMinAppVersion(),
        'search_radius': getSearchRadius(),
        'search_status': getSearchStatus(),
        'search_order_by': getSearchOrderBy(),
        'onboarding_img_1': getOnboardingImg1Url(),
        'onboarding_img_2': getOnboardingImg2Url(),
        'onboarding_img_3': getOnboardingImg3Url(),
        'privacy_policy_url': getPrivacyPolicyUrl(),
        'refund_policy_url': getRefundPolicyUrl(),
        'terms_and_conditions_url': getTermsAndConditionsUrl(),
        'terms_of_service_url': getTermsOfServiceUrl(),
        'about_us_url': getAboutUsUrl(),
        'disclaimer_url': getDisclaimerUrl(),
        'delete_account_url': getDeleteAccountUrl(),
        'contact_us_url': getContactUsUrl(),
        'app_download_url': getAppDownloadUrl(),
        'app_startup_ad_img_url': getAppStartupAdImgUrl(),
        'referral_reward_amount': getReferralRewardAmount(),
        'bottom_nav_tabs': getBottomNavBarTabs(),
        'dashboard_section': getDashboardSection(),
        'is_initialized': _isInitialized,
        'last_fetch_status': _remoteConfig?.lastFetchStatus.toString(),
        'last_fetch_time': _remoteConfig?.lastFetchTime.toString(),
      };

      developer.log(
        '📋 FirebaseRemoteConfig: All config retrieved: $config',
        name: 'RemoteConfig',
      );

      return config;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Error getting all config: $e',
        name: 'RemoteConfig',
      );
      return {};
    }
  }

  /// Check if Remote Config is initialized
  static bool get isInitialized => _isInitialized;

  /// Get the Remote Config instance (for advanced usage)
  static FirebaseRemoteConfig? get instance => _remoteConfig;

  /// Force refresh configuration (useful for testing)
  static Future<bool> forceRefresh() async {
    try {
      developer.log(
        '🔄 FirebaseRemoteConfig: Force refresh requested...',
        name: 'RemoteConfig',
      );

      if (_remoteConfig == null) {
        developer.log(
          '⚠️ FirebaseRemoteConfig: Not initialized, cannot force refresh',
          name: 'RemoteConfig',
        );
        return false;
      }

      // Temporarily set minimum fetch interval to 0 for immediate fetch
      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: Duration.zero,
        ),
      );

      final result = await fetchAndActivate();

      // Reset to normal fetch interval
      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(minutes: 5),
        ),
      );

      developer.log(
        '✅ FirebaseRemoteConfig: Force refresh completed: $result',
        name: 'RemoteConfig',
      );

      return result;
    } catch (e) {
      developer.log(
        '❌ FirebaseRemoteConfig: Force refresh failed: $e',
        name: 'RemoteConfig',
      );
      return false;
    }
  }
}
