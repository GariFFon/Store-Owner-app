import 'package:flutter/material.dart';
import 'package:exanor/components/onboarding_page.dart';
import 'package:exanor/components/onboarding_page_indicator.dart';
import 'package:exanor/screens/simple_phone_registration_screen.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'dart:developer' as developer;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<OnboardingPageData> _pages = [];

  @override
  void initState() {
    super.initState();
    _initializePages();
  }

  void _initializePages() {
    developer.log(
      '🎨 OnboardingScreen: Initializing pages with Remote Config images',
      name: 'OnboardingScreen',
    );

    // White color scheme for all pages
    const primaryColor = Color(0xFF2C2C2C); // Dark gray for text/icons
    const secondaryColor = Color(0xFFFFFFFF); // Pure white background

    _pages = [
      OnboardingPageData(
        image: FirebaseRemoteConfigService.getOnboardingImg1Url(),
        title: 'Find Local Professionals',
        subtitle:
            'Discover skilled professionals in your area ready to help with any task or service you need.',
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
      ),
      OnboardingPageData(
        image: FirebaseRemoteConfigService.getOnboardingImg2Url(),
        title: 'Book Services Instantly',
        subtitle:
            'Schedule appointments and book services with just a few taps. Quick, easy, and convenient.',
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
      ),
      OnboardingPageData(
        image: FirebaseRemoteConfigService.getOnboardingImg3Url(),
        title: 'Track & Manage',
        subtitle:
            'Keep track of your bookings, communicate with professionals, and manage all your services in one place.',
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
      ),
    ];

    developer.log(
      '🖼️ OnboardingScreen: Pages initialized with images:',
      name: 'OnboardingScreen',
    );
    developer.log(
      '   📸 Image 1: ${_pages[0].image}',
      name: 'OnboardingScreen',
    );
    developer.log(
      '   📸 Image 2: ${_pages[1].image}',
      name: 'OnboardingScreen',
    );
    developer.log(
      '   📸 Image 3: ${_pages[2].image}',
      name: 'OnboardingScreen',
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    developer.log(
      '🔘 OnboardingScreen: _nextPage called - currentPage: $_currentPage, totalPages: ${_pages.length}',
      name: 'OnboardingScreen',
    );
    if (_currentPage < _pages.length - 1) {
      developer.log(
        '➡️ OnboardingScreen: Moving to next page',
        name: 'OnboardingScreen',
      );
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      developer.log(
        '✅ OnboardingScreen: Last page reached, calling _navigateToHome',
        name: 'OnboardingScreen',
      );
      _navigateToHome();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipOnboarding() {
    _navigateToHome();
  }

  void _navigateToHome() async {
    developer.log(
      '🔄 OnboardingScreen: _navigateToHome called - navigating to PhoneRegistration',
      name: 'OnboardingScreen',
    );

    // Check if widget is still mounted
    if (!mounted) {
      developer.log(
        '⚠️ OnboardingScreen: Widget not mounted, cannot navigate',
        name: 'OnboardingScreen',
      );
      return;
    }

    developer.log(
      '✅ OnboardingScreen: Widget is mounted, proceeding with navigation',
      name: 'OnboardingScreen',
    );

    try {
      // Small delay to ensure UI is ready
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted) {
        developer.log(
          '⚠️ OnboardingScreen: Widget unmounted during delay',
          name: 'OnboardingScreen',
        );
        return;
      }

      developer.log(
        '🚀 OnboardingScreen: Executing navigation now...',
        name: 'OnboardingScreen',
      );

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) {
            developer.log(
              '📱 OnboardingScreen: Building SimplePhoneRegistrationScreen...',
              name: 'OnboardingScreen',
            );
            return const SimplePhoneRegistrationScreen();
          },
        ),
      );

      developer.log(
        '✅ OnboardingScreen: Navigation completed successfully',
        name: 'OnboardingScreen',
      );
    } catch (e, stackTrace) {
      developer.log(
        '❌ OnboardingScreen: Navigation failed with error: $e',
        name: 'OnboardingScreen',
      );
      developer.log('📚 Stack trace: $stackTrace', name: 'OnboardingScreen');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Handle case where pages are not yet initialized
    if (_pages.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2C2C2C)),
        ),
      );
    }

    final currentPageData = _pages[_currentPage];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // PageView for onboarding pages (full screen)
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return OnboardingPage(
                data: _pages[index],
                isActive: index == _currentPage,
              );
            },
          ),

          // Bottom controls overlay - with explicit pointer events
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page indicators
                  OnboardingPageIndicator(
                    currentPage: _currentPage,
                    totalPages: _pages.length,
                    activeColor: theme.colorScheme.primary,
                    inactiveColor: Colors.white.withOpacity(0.4),
                  ),

                  const SizedBox(height: 24),

                  // Navigation buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Previous button
                      AnimatedOpacity(
                        opacity: _currentPage > 0 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: _currentPage > 0
                            ? GestureDetector(
                                onTap: _previousPage,
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_ios_new,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              )
                            : SizedBox(width: 56, height: 56),
                      ),

                      // Next/Get Started button
                      GestureDetector(
                        onTap: () {
                          developer.log(
                            '👆 OnboardingScreen: Get Started/Next button tapped!',
                            name: 'OnboardingScreen',
                          );
                          developer.log(
                            '📄 Current page: $_currentPage, Total pages: ${_pages.length}',
                            name: 'OnboardingScreen',
                          );
                          _nextPage();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.3,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentPage == _pages.length - 1
                                    ? 'Get Started'
                                    : 'Next',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _currentPage == _pages.length - 1
                                    ? Icons.rocket_launch
                                    : Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPageData {
  final String image;
  final String title;
  final String subtitle;
  final Color primaryColor;
  final Color secondaryColor;

  OnboardingPageData({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.secondaryColor,
  });
}
