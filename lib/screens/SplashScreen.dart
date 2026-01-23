import 'package:flutter/material.dart';
import 'package:exanor/config/theme_config.dart';
import 'package:exanor/screens/HomeScreen.dart';
import 'package:exanor/screens/onboarding_screen.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/in_app_update_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:developer' as developer;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _shimmerController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    developer.log(
      '🚀 SplashScreen: initState called - starting splash screen',
      name: 'SplashScreen',
    );
    _initAnimations();
    _startAnimations();
    _startTimer();
  }

  void _initAnimations() {
    // Fade animation controller
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Scale animation controller
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Shimmer animation controller
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Define animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  void _startAnimations() {
    // Start animations with delays
    _fadeController.forward();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _scaleController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _shimmerController.repeat(reverse: true);
      }
    });
  }

  void _startTimer() {
    developer.log(
      '⏰ SplashScreen: Starting 3-second timer',
      name: 'SplashScreen',
    );
    _timer = Timer(const Duration(seconds: 3), () async {
      developer.log(
        '⏰ SplashScreen: Timer completed, starting navigation',
        name: 'SplashScreen',
      );
      if (mounted) {
        await _waitForConfigurationAndNavigate();
      }
    });
  }

  Future<void> _waitForConfigurationAndNavigate() async {
    developer.log(
      '🔄 SplashScreen: Waiting for API configuration to complete...',
      name: 'SplashScreen',
    );

    // Wait for API service configuration to complete
    try {
      // Check if configuration is already ready
      final config = ApiService.getCurrentConfiguration();
      developer.log(
        '📊 SplashScreen: Current config status: $config',
        name: 'SplashScreen',
      );

      if (!config['isConfigurationCached']) {
        developer.log(
          '⏳ SplashScreen: API configuration not ready, waiting...',
          name: 'SplashScreen',
        );

        // Initialize configuration if not already done
        await ApiService.initializeConfiguration();
        developer.log(
          '✅ SplashScreen: API configuration completed',
          name: 'SplashScreen',
        );
      } else {
        developer.log(
          '✅ SplashScreen: API configuration already ready',
          name: 'SplashScreen',
        );
      }
    } catch (e) {
      developer.log(
        '❌ SplashScreen: Error waiting for configuration: $e',
        name: 'SplashScreen',
      );
      // Continue anyway - API service will use defaults
    }

    // Check for critical updates after configuration is ready
    developer.log(
      '🔍 SplashScreen: Checking for critical app updates...',
      name: 'SplashScreen',
    );
    try {
      if (mounted) {
        await InAppUpdateService.instance.checkForCriticalUpdates(context);
        developer.log(
          '✅ SplashScreen: Update check completed',
          name: 'SplashScreen',
        );
      }
    } catch (e) {
      developer.log(
        '❌ SplashScreen: Error checking for updates: $e',
        name: 'SplashScreen',
      );
      // Continue anyway - updates are not critical for app startup
    }

    // Now proceed with auth check and navigation
    await _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      final refreshToken = prefs.getString('refresh_token');

      if (mounted) {
        if (accessToken != null && refreshToken != null) {
          // User is logged in, navigate to HomeScreen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        } else {
          // No tokens found, navigate to OnboardingScreen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
      }
    } catch (e) {
      // If there's an error checking tokens, default to onboarding
      developer.log(
        '❌ SplashScreen: Error checking tokens: $e',
        name: 'SplashScreen',
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _fadeAnimation,
            _scaleAnimation,
            _shimmerAnimation,
          ]),
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        // Base logo
                        Image.asset(
                          'assets/icon/exanor_icon_512x512px.png',
                          width: 200,
                          height: 200,
                          errorBuilder: (context, error, stackTrace) {
                            // Fallback if the image doesn't exist
                            return Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3), // Flutter blue
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Icon(
                                Icons.flutter_dash,
                                size: 100,
                                color: Colors.white,
                              ),
                            );
                          },
                        ),

                        // Shimmer overlay
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Transform.translate(
                              offset: Offset(_shimmerAnimation.value * 100, 0),
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.3),
                                      Colors.white.withOpacity(0.7),
                                      Colors.white.withOpacity(0.3),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                                  ),
                                ),
                                width: 100,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
