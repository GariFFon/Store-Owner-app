import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class InterstitialAdsService {
  static final InterstitialAdsService _instance =
      InterstitialAdsService._internal();
  factory InterstitialAdsService() => _instance;
  InterstitialAdsService._internal();

  static InterstitialAdsService get instance => _instance;

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  bool _isAdLoading = false;

  // Ad Unit IDs - using test ads in debug, production ads in release
  static const String _testAdUnitId =
      'ca-app-pub-3940256099942544/1033173712'; // Test interstitial ad unit
  static const String _productionAdUnitId =
      'ca-app-pub-5158384667126059/3289731444'; // Your production interstitial ad unit

  // Get the appropriate ad unit ID based on debug mode
  String get _adUnitId {
    if (kDebugMode) {
      return _testAdUnitId; // Use test ads in debug mode
    } else {
      return _productionAdUnitId; // Use production ads in release mode
    }
  }

  /// Initialize the Mobile Ads SDK (shared with rewarded ads)
  static Future<void> initialize() async {
    try {
      await MobileAds.instance.initialize();
      print(
        '✅ InterstitialAdsService: Mobile Ads SDK initialized successfully',
      );
    } catch (e) {
      print(
        '❌ InterstitialAdsService: Failed to initialize Mobile Ads SDK: $e',
      );
    }
  }

  /// Load an interstitial ad
  Future<void> loadInterstitialAd() async {
    if (_isAdLoading || _isAdLoaded) {
      print('🔄 InterstitialAdsService: Ad is already loading or loaded');
      return;
    }

    _isAdLoading = true;
    print(
      '🔄 InterstitialAdsService: Loading interstitial ad with ID: $_adUnitId',
    );

    try {
      await InterstitialAd.load(
        adUnitId: _adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            print(
              '✅ InterstitialAdsService: Interstitial ad loaded successfully',
            );
            _interstitialAd = ad;
            _isAdLoaded = true;
            _isAdLoading = false;
            _setAdCallbacks();
          },
          onAdFailedToLoad: (LoadAdError error) {
            print(
              '❌ InterstitialAdsService: Failed to load interstitial ad: $error',
            );
            _interstitialAd = null;
            _isAdLoaded = false;
            _isAdLoading = false;
          },
        ),
      );
    } catch (e) {
      print('❌ InterstitialAdsService: Exception loading interstitial ad: $e');
      _isAdLoading = false;
    }
  }

  /// Set callbacks for the interstitial ad
  void _setAdCallbacks() {
    if (_interstitialAd == null) return;

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) {
        print(
          '📱 InterstitialAdsService: Interstitial ad showed full screen content',
        );
      },
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print(
          '👋 InterstitialAdsService: Interstitial ad dismissed full screen content',
        );
        ad.dispose();
        _interstitialAd = null;
        _isAdLoaded = false;
        // Preload the next ad
        loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print(
          '❌ InterstitialAdsService: Failed to show interstitial ad: $error',
        );
        ad.dispose();
        _interstitialAd = null;
        _isAdLoaded = false;
        // Try to load another ad
        loadInterstitialAd();
      },
    );
  }

  /// Show the interstitial ad with callbacks
  Future<bool> showInterstitialAd({
    Function()? onAdClosed,
    Function(String error)? onAdFailedToShow,
  }) async {
    if (!_isAdLoaded || _interstitialAd == null) {
      print('❌ InterstitialAdsService: No interstitial ad available to show');
      onAdFailedToShow?.call('No ad available. Please try again in a moment.');

      // Try to load an ad for next time
      loadInterstitialAd();
      return false;
    }

    print('📱 InterstitialAdsService: Showing interstitial ad');

    try {
      await _interstitialAd!.show();

      // Set up callback for when ad is closed
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (InterstitialAd ad) {
          print(
            '📱 InterstitialAdsService: Interstitial ad showed full screen content',
          );
        },
        onAdDismissedFullScreenContent: (InterstitialAd ad) {
          print(
            '👋 InterstitialAdsService: Interstitial ad dismissed full screen content',
          );
          onAdClosed?.call();
          ad.dispose();
          _interstitialAd = null;
          _isAdLoaded = false;
          // Preload the next ad
          loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
          print(
            '❌ InterstitialAdsService: Failed to show interstitial ad: $error',
          );
          onAdFailedToShow?.call('Failed to show ad: ${error.message}');
          ad.dispose();
          _interstitialAd = null;
          _isAdLoaded = false;
          // Try to load another ad
          loadInterstitialAd();
        },
      );

      return true;
    } catch (e) {
      print('❌ InterstitialAdsService: Exception showing interstitial ad: $e');
      onAdFailedToShow?.call('Error showing ad: $e');
      return false;
    }
  }

  /// Check if an interstitial ad is ready to be shown
  bool get isAdReady => _isAdLoaded && _interstitialAd != null;

  /// Check if an ad is currently loading
  bool get isLoading => _isAdLoading;

  /// Dispose of the current ad
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
    _isAdLoading = false;
  }

  /// Preload an ad (call this during app initialization or after showing an ad)
  void preloadAd() {
    if (!_isAdLoaded && !_isAdLoading) {
      loadInterstitialAd();
    }
  }

  /// Show interstitial ad with simple interface for common usage
  Future<void> showAdIfAvailable({
    String context = 'general',
    Function()? onCompleted,
  }) async {
    print(
      '🎯 InterstitialAdsService: Attempting to show ad for context: $context',
    );

    try {
      // Add a small delay to ensure UI operations are complete
      await Future.delayed(const Duration(milliseconds: 100));

      final success = await showInterstitialAd(
        onAdClosed: () {
          print('✅ InterstitialAdsService: Ad completed for context: $context');

          // Add small delay before calling completion to ensure ad UI is fully dismissed
          Future.delayed(const Duration(milliseconds: 150), () {
            try {
              onCompleted?.call();
            } catch (e) {
              print(
                '❌ InterstitialAdsService: Error in onCompleted callback: $e',
              );
            }
          });
        },
        onAdFailedToShow: (error) {
          print(
            '❌ InterstitialAdsService: Ad failed for context: $context - $error',
          );

          // Still call onCompleted even if ad fails, so user flow continues
          Future.delayed(const Duration(milliseconds: 100), () {
            try {
              onCompleted?.call();
            } catch (e) {
              print(
                '❌ InterstitialAdsService: Error in onCompleted callback (failed): $e',
              );
            }
          });
        },
      );

      if (!success) {
        // If ad couldn't be shown, still continue user flow
        print(
          '⚠️ InterstitialAdsService: No ad available for context: $context, continuing...',
        );

        // Small delay before calling completion
        Future.delayed(const Duration(milliseconds: 100), () {
          try {
            onCompleted?.call();
          } catch (e) {
            print(
              '❌ InterstitialAdsService: Error in onCompleted callback (no ad): $e',
            );
          }
        });
      }
    } catch (e) {
      print('❌ InterstitialAdsService: Exception in showAdIfAvailable: $e');

      // Ensure onCompleted is called even if there's an exception
      Future.delayed(const Duration(milliseconds: 100), () {
        try {
          onCompleted?.call();
        } catch (callbackError) {
          print(
            '❌ InterstitialAdsService: Error in onCompleted callback (exception): $callbackError',
          );
        }
      });
    }
  }
}
