import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAdsService {
  static final RewardedAdsService _instance = RewardedAdsService._internal();
  factory RewardedAdsService() => _instance;
  RewardedAdsService._internal();

  static RewardedAdsService get instance => _instance;

  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;

  // Ad Unit IDs
  static const String _testAdUnitId =
      'ca-app-pub-3940256099942544/5224354917'; // Test ad unit
  static const String _productionAdUnitId =
      'ca-app-pub-5158384667126059/6358979420'; // Your production ad unit

  // Get the appropriate ad unit ID based on debug mode
  String get _adUnitId {
    if (kDebugMode) {
      return _testAdUnitId; // Use test ads in debug mode
    } else {
      return _productionAdUnitId; // Use production ads in release mode
    }
  }

  /// Initialize the Mobile Ads SDK
  static Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      print('✅ RewardedAdsService: Mobile Ads SDK initialized successfully');
    } catch (e) {
      print('❌ RewardedAdsService: Failed to initialize Mobile Ads SDK: $e');
    }
  }

  /// Load a rewarded ad
  Future<void> loadRewardedAd() async {
    if (_isAdLoading || _isAdLoaded) {
      print('🔄 RewardedAdsService: Ad is already loading or loaded');
      return;
    }

    _isAdLoading = true;
    print('🔄 RewardedAdsService: Loading rewarded ad with ID: $_adUnitId');

    try {
      await RewardedAd.load(
        adUnitId: _adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            print('✅ RewardedAdsService: Rewarded ad loaded successfully');
            _rewardedAd = ad;
            _isAdLoaded = true;
            _isAdLoading = false;
            _setAdCallbacks();
          },
          onAdFailedToLoad: (LoadAdError error) {
            print('❌ RewardedAdsService: Failed to load rewarded ad: $error');
            _rewardedAd = null;
            _isAdLoaded = false;
            _isAdLoading = false;
          },
        ),
      );
    } catch (e) {
      print('❌ RewardedAdsService: Exception loading rewarded ad: $e');
      _isAdLoading = false;
    }
  }

  /// Set callbacks for the rewarded ad
  void _setAdCallbacks() {
    if (_rewardedAd == null) return;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        print('📱 RewardedAdsService: Rewarded ad showed full screen content');
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        print(
          '👋 RewardedAdsService: Rewarded ad dismissed full screen content',
        );
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        // Preload the next ad
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        print('❌ RewardedAdsService: Failed to show rewarded ad: $error');
        ad.dispose();
        _rewardedAd = null;
        _isAdLoaded = false;
        // Try to load another ad
        loadRewardedAd();
      },
    );
  }

  /// Show the rewarded ad with callbacks for reward and completion
  Future<bool> showRewardedAd({
    required Function(RewardItem reward) onUserEarnedReward,
    Function()? onAdClosed,
    Function(String error)? onAdFailedToShow,
  }) async {
    if (!_isAdLoaded || _rewardedAd == null) {
      print('❌ RewardedAdsService: No rewarded ad available to show');
      onAdFailedToShow?.call('No ad available. Please try again in a moment.');

      // Try to load an ad for next time
      loadRewardedAd();
      return false;
    }

    print('📱 RewardedAdsService: Showing rewarded ad');

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          print(
            '🎉 RewardedAdsService: User earned reward: ${reward.amount} ${reward.type}',
          );
          onUserEarnedReward(reward);
        },
      );

      // Set up callback for when ad is closed
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (RewardedAd ad) {
          print(
            '📱 RewardedAdsService: Rewarded ad showed full screen content',
          );
        },
        onAdDismissedFullScreenContent: (RewardedAd ad) {
          print(
            '👋 RewardedAdsService: Rewarded ad dismissed full screen content',
          );
          onAdClosed?.call();
          ad.dispose();
          _rewardedAd = null;
          _isAdLoaded = false;
          // Preload the next ad
          loadRewardedAd();
        },
        onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
          print('❌ RewardedAdsService: Failed to show rewarded ad: $error');
          onAdFailedToShow?.call('Failed to show ad: ${error.message}');
          ad.dispose();
          _rewardedAd = null;
          _isAdLoaded = false;
          // Try to load another ad
          loadRewardedAd();
        },
      );

      return true;
    } catch (e) {
      print('❌ RewardedAdsService: Exception showing rewarded ad: $e');
      onAdFailedToShow?.call('Error showing ad: $e');
      return false;
    }
  }

  /// Check if a rewarded ad is ready to be shown
  bool get isAdReady => _isAdLoaded && _rewardedAd != null;

  /// Check if an ad is currently loading
  bool get isLoading => _isAdLoading;

  /// Dispose of the current ad
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;
    _isAdLoading = false;
  }

  /// Get estimated reward credits for watching an ad
  /// This is a configurable value that determines how much credit users get
  static double get rewardCreditsAmount => 10.0; // ₹10 for watching an ad

  /// Ad Credit Plan ID for rewarded ads
  /// This ID represents the specific ad credit plan for rewarded ad earnings
  static String get adCreditPlanId => '1557506e-b0b8-4adc-a4b7-ed2b50813d2b';

  /// Preload an ad (call this during app initialization or after showing an ad)
  void preloadAd() {
    if (!_isAdLoaded && !_isAdLoading) {
      loadRewardedAd();
    }
  }
}
