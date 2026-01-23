import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exanor/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/enhanced_translation_service.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:convert';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/components/language_selector.dart';

// Dashboard item model for remote config
class DashboardItem {
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final List<Color> gradientColors;
  final String action;
  final String? actionData;
  final bool enabled;
  final int order;

  DashboardItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.action,
    this.actionData,
    required this.enabled,
    required this.order,
  });

  factory DashboardItem.fromJson(Map<String, dynamic> json) {
    List<Color> parseGradientColors(List<dynamic> colorStrings) {
      return colorStrings.map((colorString) {
        String hex = colorString.toString().replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      }).toList();
    }

    return DashboardItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      icon: json['icon'] ?? 'help_outline',
      gradientColors: parseGradientColors(
        json['gradientColors'] ?? ['#42A5F5', '#AB47BC'],
      ),
      action: json['action'] ?? 'navigate',
      actionData: json['actionData'],
      enabled: json['enabled'] ?? true,
      order: json['order'] ?? 0,
    );
  }

  // Method to get IconData from string
  IconData getIconData() {
    const iconMap = {
      'person_outline_rounded': Icons.person_outline_rounded,
      'work_outline_rounded': Icons.work_outline_rounded,
      'business_outlined': Icons.business_outlined,
      'store_outlined': Icons.store_outlined,
      'settings_outlined': Icons.settings_outlined,
      'help_outline': Icons.help_outline,
      'info_outline': Icons.info_outline,
      'account_circle_outlined': Icons.account_circle_outlined,
      'dashboard_outlined': Icons.dashboard_outlined,
      'analytics_outlined': Icons.analytics_outlined,
      'inventory_outlined': Icons.inventory_outlined,
      'group_outlined': Icons.group_outlined,
      'payment_outlined': Icons.payment_outlined,
      'security_outlined': Icons.security_outlined,
      'support_outlined': Icons.support_outlined,
      'notifications_outlined': Icons.notifications_outlined,
      'mail_outline': Icons.mail_outline,
      'phone_outlined': Icons.phone_outlined,
      'location_on_outlined': Icons.location_on_outlined,
      'calendar_today_outlined': Icons.calendar_today_outlined,
      'star_outline': Icons.star_outline,
      'favorite_outline': Icons.favorite_outline,
      'bookmark_outline': Icons.bookmark_outline,
      'share_outlined': Icons.share_outlined,
      'download_outlined': Icons.download_outlined,
      'upload_outlined': Icons.upload_outlined,
      'edit_outlined': Icons.edit_outlined,
      'delete_outline': Icons.delete_outline,
      'add_circle_outline': Icons.add_circle_outline,
      'remove_circle_outline': Icons.remove_circle_outline,
      'search_outlined': Icons.search_outlined,
      'filter_list_outlined': Icons.filter_list_outlined,
      'sort_outlined': Icons.sort_outlined,
      'visibility_outlined': Icons.visibility_outlined,
      'visibility_off_outlined': Icons.visibility_off_outlined,
      'lock_outline': Icons.lock_outline,
      'lock_open_outlined': Icons.lock_open_outlined,
    };

    return iconMap[icon] ?? Icons.help_outline;
  }
}

class DashboardSection extends StatefulWidget {
  const DashboardSection({super.key});

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _pulseAnimation;

  int _hoveredIndex = -1;
  int _pressedIndex = -1;
  List<DashboardItem> _dashboardItems = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardItems();

    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 80.0, end: 0.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.elasticOut),
    );

    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations
    _mainController.forward();
    _shimmerController.repeat();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _mainController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _loadDashboardItems() {
    try {
      // Load dashboard items from remote config
      final itemsData = FirebaseRemoteConfigService.getDashboardSection();
      setState(() {
        _dashboardItems = itemsData
            .map((json) => DashboardItem.fromJson(json))
            .where((item) => item.enabled) // Only show enabled items
            .toList();

        // Sort by order
        _dashboardItems.sort((a, b) => a.order.compareTo(b.order));
      });

      print(
        '📱 Loaded ${_dashboardItems.length} dashboard items from remote config',
      );
    } catch (e) {
      print('❌ Error loading dashboard items: $e');
      // Fallback to default items
      _dashboardItems = _getDefaultDashboardItems();
    }
  }

  List<DashboardItem> _getDefaultDashboardItems() {
    return [
      DashboardItem(
        id: 'professional',
        title: 'Professional',
        subtitle: 'Showcase skills',
        icon: 'person_outline_rounded',
        gradientColors: [Colors.blue.shade400, Colors.purple.shade400],
        action: 'handleProfessionalProfile',
        enabled: true,
        order: 0,
      ),
      DashboardItem(
        id: 'employee',
        title: 'Employee',
        subtitle: 'Find jobs',
        icon: 'work_outline_rounded',
        gradientColors: [Colors.green.shade400, Colors.teal.shade400],
        action: 'handleEmployeeProfile',
        enabled: true,
        order: 1,
      ),
      DashboardItem(
        id: 'business',
        title: 'Business',
        subtitle: 'Grow reach',
        icon: 'business_outlined',
        gradientColors: [Colors.orange.shade400, Colors.red.shade400],
        action: 'navigate',
        actionData: '/my_businesses',
        enabled: true,
        order: 2,
      ),
    ];
  }

  void _handleDashboardAction(DashboardItem item) {
    // Provide haptic feedback
    HapticFeedback.lightImpact();

    switch (item.action) {
      case 'handleProfessionalProfile':
        _handleProfessionalProfileNavigation(context);
        break;
      case 'handleEmployeeProfile':
        _handleEmployeeProfileNavigation(context);
        break;
      case 'navigateToBusinesses':
        Navigator.pushNamed(context, '/my_businesses');
        break;
      case 'navigate':
        if (item.actionData != null && item.actionData!.isNotEmpty) {
          // Handle special routes that need custom logic
          if (item.actionData == '/refer_and_earn') {
            _showReferEarnScreen();
          } else if (item.actionData == '/feed') {
            _showFeedScreen();
          } else {
            // Standard navigation
            Navigator.pushNamed(context, item.actionData!);
          }
        } else {
          print('Navigate action requires actionData');
        }
        break;
      case 'showRegistration':
        _showRegistrationBottomSheet();
        break;
      case 'showReferEarn':
        _showReferEarnScreen();
        break;
      case 'showLanguageSelector':
        _showLanguageSelector();
        break;
      case 'showFeed':
        _showFeedScreen();
        break;
      default:
        print('Unknown action: ${item.action}');
        break;
    }
  }

  Future<void> _handleProfessionalProfileNavigation(
    BuildContext context,
  ) async {
    try {
      print('🔍 Checking professional profile status...');

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Checking profile...'),
            ],
          ),
        ),
      );

      final response = await ApiService.post(
        '/view-self-professional-profile/',
        body: {},
        useBearerToken: true,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      print('📝 Professional profile response: ${response['statusCode']}');
      print('📝 Response data: ${response['data']}');

      if (response['statusCode'] == 200) {
        final responseData = response['data'];

        if (responseData['status'] == 404) {
          // No professional profile exists, redirect to onboarding
          print('➡️ No professional profile found, redirecting to onboarding');
          Navigator.pushNamed(context, '/professional_profile_onboarding');
        } else if (responseData['status'] == 200) {
          // Professional profile exists, redirect to editable profile
          print(
            '✅ Professional profile found, redirecting to editable profile',
          );
          final profileData = responseData['data'];

          Navigator.pushNamed(
            context,
            '/user_profile_editable',
            arguments: {'profile': 'professional', 'userData': profileData},
          );
        } else {
          // Unexpected status
          print('⚠️ Unexpected response status: ${responseData['status']}');
          _showErrorDialog(
            context,
            'Unexpected response from server. Please try again.',
          );
        }
      } else {
        // HTTP error
        print('❌ HTTP error: ${response['statusCode']}');
        _showErrorDialog(
          context,
          'Failed to check professional profile. Please try again.',
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      print('❌ Exception during professional profile check: $e');
      _showErrorDialog(
        context,
        'Network error. Please check your connection and try again.' +
            e.toString(),
      );
    }
  }

  Future<void> _handleEmployeeProfileNavigation(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading profile...'),
          ],
        ),
      ),
    );

    try {
      print('🔍 Starting API call to /view-self-employee-profile/');

      // Check if we have a valid token first
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      print('🔑 Access token available: ${token != null ? 'Yes' : 'No'}');

      if (token == null) {
        // Close loading dialog
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
        _showErrorDialog(
          context,
          'Please log in again to access your profile.',
        );
        return;
      }

      // Send POST to /view-self-employee-profile/ with empty body and token
      final response = await ApiService.post(
        '/view-self-employee-profile/',
        body: {},
        useBearerToken: true,
      );

      print('📡 API response received: $response');
      print('📊 Response statusCode: ${response['statusCode']}');
      print('📊 Response data: ${response['data']}');

      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      // Check response conditions
      if (response['statusCode'] == 200) {
        final responseStatus = response['data']?['status'];
        final responseData = response['data']?['data'];

        if (responseStatus == 200 &&
            responseData != null &&
            responseData is Map &&
            responseData.isNotEmpty) {
          // Case 2: Profile exists, go to user profile editable screen
          Navigator.pushNamed(
            context,
            '/user_profile_editable',
            arguments: responseData,
          );
        } else if (responseStatus == 404 &&
            (responseData == null ||
                (responseData is Map && responseData.isEmpty))) {
          // Case 3: No profile exists, go to onboarding
          Navigator.pushNamed(context, '/employee_profile_onboarding');
        } else if (responseStatus == 403) {
          // Case 4: Subscription required, extract required subscriptions and go to subscription screen
          final responseBody = response['data']; // Get the actual response body
          final List<dynamic> requiredSubscriptions =
              responseBody['required_subscriptions'] ?? [];
          final List<dynamic> subscriptionsAvailable =
              responseBody['subscriptions_available'] ?? [];

          print('🔒 Subscription required for employee profile');
          print('📋 Required subscriptions: $requiredSubscriptions');
          print('📋 Available subscriptions: $subscriptionsAvailable');
          print('📋 User subscriptions: ${responseBody['user_subscriptions']}');
          print('📋 Message: ${responseBody['message']}');

          _navigateToSubscriptionScreen(
            context,
            requiredSubscriptions.cast<String>(),
            subscriptionsAvailable.cast<Map<String, dynamic>>(),
          );
        } else {
          // Handle other status codes
          _showErrorDialog(context, 'Unexpected response from server');
        }
      } else {
        // Handle non-200 HTTP status codes
        _showErrorDialog(context, 'Failed to load profile information');
      }
    } catch (e) {
      // Close loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      print('❌ Error fetching employee profile: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');

      // More specific error handling
      String errorMessage = 'Network error occurred. Please try again.';
      if (e.toString().contains('SocketException')) {
        errorMessage = 'No internet connection. Please check your network.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Request timed out. Please try again.';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = 'Invalid server response. Please try again.';
      }

      _showErrorDialog(context, errorMessage);
    }
  }

  void _navigateToSubscriptionScreen(
    BuildContext context,
    List<String> requiredSubscriptionIds,
    List<Map<String, dynamic>> subscriptionsAvailable,
  ) async {
    print('🚀 Navigating to subscription screen for employee profile');
    print('📋 Required subscription IDs: $requiredSubscriptionIds');
    print('📋 Available subscriptions: ${subscriptionsAvailable.length}');

    try {
      // If we have subscriptions available, use them directly
      if (subscriptionsAvailable.isNotEmpty) {
        final result = await Navigator.pushNamed(
          context,
          '/subscription',
          arguments: {
            'service': 'Employee Profile',
            'subscriptionProfile': 'employee',
            'subscriptionsData': subscriptionsAvailable,
            'requiredSubscriptionIds': requiredSubscriptionIds,
          },
        );

        if (result == 'refresh_needed') {
          print(
            '🔄 Subscription completed, employee profile access should be available now',
          );
        }
      } else if (requiredSubscriptionIds.isNotEmpty) {
        // If no subscriptions available but we have required IDs, fetch them
        print(
          '🔍 No subscriptions_available but found required_subscription_ids: $requiredSubscriptionIds',
        );
        print('🚀 Fetching subscription details for required IDs...');

        await _fetchAndNavigateToSubscriptions(
          context,
          requiredSubscriptionIds,
          'Employee Profile',
        );
      } else {
        // Fallback to dialog
        _showSubscriptionRequiredDialog(context);
      }
    } catch (e) {
      print('❌ Error navigating to subscription screen: $e');
      _showSubscriptionRequiredDialog(context);
    }
  }

  /// Fetch subscription details for each required subscription ID
  /// This mirrors the logic from custom_sliver_app_bar.dart
  Future<void> _fetchAndNavigateToSubscriptions(
    BuildContext context,
    List<String> subscriptionIds,
    String categoryName,
  ) async {
    print(
      '💳 DashboardSection: *** FETCHING SUBSCRIPTION DETAILS *** for "$categoryName"',
    );
    print(
      '📋 DashboardSection: subscription_id_required list: $subscriptionIds',
    );

    List<Map<String, dynamic>> subscriptionsData = [];

    try {
      // For each required subscription ID, send POST request to /get-subscription/
      for (int i = 0; i < subscriptionIds.length; i++) {
        final String subscriptionId = subscriptionIds[i];
        print(
          '🔍 DashboardSection: [${i + 1}/${subscriptionIds.length}] Fetching subscription ID: $subscriptionId',
        );
        print(
          '📤 DashboardSection: Sending POST to /get-subscription/ with body: {"id": "$subscriptionId"}',
        );

        final response = await ApiService.post(
          '/get-subscription/',
          body: {'id': subscriptionId},
          useBearerToken: true,
        );

        print(
          '📥 DashboardSection: COMPLETE API RESPONSE for subscription $subscriptionId:',
        );
        print(response);

        if (response['data'] != null) {
          final responseData = response['data'];

          if (responseData['status'] == 200) {
            final List<dynamic> subscriptions = responseData['data'] ?? [];
            print(
              '✅ DashboardSection: Successfully fetched ${subscriptions.length} subscription(s) for ID $subscriptionId',
            );
            subscriptionsData.addAll(
              subscriptions.cast<Map<String, dynamic>>(),
            );
          } else {
            print(
              '❌ DashboardSection: Failed to fetch subscription $subscriptionId: ${responseData['message']}',
            );
          }
        } else {
          print(
            '❌ DashboardSection: Empty response data for subscription $subscriptionId',
          );
        }
      }

      print('📊 DashboardSection: *** SUBSCRIPTION FETCH COMPLETE ***');
      print(
        '📋 DashboardSection: Total subscriptions collected: ${subscriptionsData.length}',
      );
      print('📄 DashboardSection: Complete subscription list:');
      print(subscriptionsData);

      // Navigate to subscription page with fetched subscription data
      if (subscriptionsData.isNotEmpty) {
        print(
          '🚀 DashboardSection: Navigating to subscription page with subscription list',
        );

        final result = await Navigator.pushNamed(
          context,
          '/subscription',
          arguments: {
            'service': categoryName,
            'subscriptionProfile': 'employee',
            'subscriptionsData': subscriptionsData,
            'requiredSubscriptionIds': subscriptionIds,
          },
        );

        if (result == 'refresh_needed') {
          print(
            '🔄 DashboardSection: Subscription completed, triggering refresh if needed',
          );
        }
      } else {
        print(
          '⚠️ DashboardSection: No subscription data found, showing fallback dialog',
        );
        _showSubscriptionRequiredDialog(context);
      }
    } catch (e) {
      print('❌ DashboardSection: Exception fetching subscription details: $e');
      _showSubscriptionRequiredDialog(context);
    }
  }

  void _showSubscriptionRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: TranslatedText('Subscription Required'),
        content: TranslatedText(
          'You need an active subscription to access your employee profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: TranslatedText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to subscription screen (fallback without specific data)
              Navigator.pushNamed(context, '/subscription');
            },
            child: TranslatedText('View Subscriptions'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: TranslatedText('Error'),
        content: TranslatedText(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: TranslatedText('OK'),
          ),
        ],
      ),
    );
  }

  void _showRegistrationBottomSheet() {
    // For dashboard, simply navigate to registration route or show message
    // You can customize this based on your needs
    Navigator.pushNamed(context, '/registration').catchError((error) {
      // If route doesn't exist, show a message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TranslatedText('Registration feature coming soon!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    });
  }

  void _showReferEarnScreen() {
    // Navigate to refer and earn screen
    Navigator.pushNamed(context, '/refer_and_earn');
  }

  void _showLanguageSelector() {
    showLanguageSelector(
      context,
      onLanguageSelected: (language) {
        // Language selected
      },
    );
  }

  void _showFeedScreen() {
    // Navigate to feed screen
    Navigator.pushNamed(context, '/feed');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _mainController,
        _shimmerController,
        _pulseController,
      ]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: AnimatedScale(
                scale: _pulseAnimation.value,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withOpacity(0.4)
                            : Colors.black.withOpacity(0.08),
                        blurRadius: 32,
                        spreadRadius: 0,
                        offset: const Offset(0, 12),
                      ),
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        blurRadius: 60,
                        spreadRadius: -10,
                        offset: const Offset(0, 20),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.15)
                                : Colors.white.withOpacity(0.4),
                            width: 2,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDarkMode
                                ? [
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.05),
                                    Colors.white.withOpacity(0.1),
                                  ]
                                : [
                                    Colors.white.withOpacity(0.9),
                                    Colors.white.withOpacity(0.6),
                                    Colors.white.withOpacity(0.8),
                                  ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Animated shimmer overlay
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: CustomPaint(
                                  painter: DashboardShimmerPainter(
                                    progress: _shimmerAnimation.value,
                                    isDarkMode: isDarkMode,
                                  ),
                                ),
                              ),
                            ),
                            // Main content
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildHeader(theme, isDarkMode),
                                  const SizedBox(height: 16),
                                  ..._buildDashboardOptions(theme, isDarkMode),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.withOpacity(0.8),
                    Colors.orange.withOpacity(0.6),
                  ],
                ),
              ),
              child: const Icon(Icons.diamond, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(
                    'Profile Hub',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  TranslatedText(
                    'Create and manage your profiles',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.7)
                          : Colors.black.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildDashboardOptions(ThemeData theme, bool isDarkMode) {
    return [
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 1.0,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: _dashboardItems.length,
        itemBuilder: (context, index) {
          final item = _dashboardItems[index];
          final isHovered = _hoveredIndex == index;
          final isPressed = _pressedIndex == index;

          return MouseRegion(
            onEnter: (_) => setState(() => _hoveredIndex = index),
            onExit: (_) => setState(() => _hoveredIndex = -1),
            child: GestureDetector(
              onTapDown: (_) => setState(() => _pressedIndex = index),
              onTapUp: (_) {
                setState(() => _pressedIndex = -1);
                _handleDashboardAction(item);
              },
              onTapCancel: () => setState(() => _pressedIndex = -1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                transform: Matrix4.identity()
                  ..scale(
                    isPressed
                        ? 0.95
                        : isHovered
                        ? 1.05
                        : 1.0,
                  ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (isHovered)
                      BoxShadow(
                        color: item.gradientColors.first.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.black.withOpacity(0.2)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isHovered
                              ? item.gradientColors.first.withOpacity(0.4)
                              : Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDarkMode
                              ? [
                                  Colors.white.withOpacity(0.08),
                                  Colors.white.withOpacity(0.04),
                                ]
                              : [
                                  Colors.white.withOpacity(0.7),
                                  Colors.white.withOpacity(0.4),
                                ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: item.gradientColors,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: item.gradientColors.first
                                        .withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                item.getIconData(),
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Title
                            TranslatedText(
                              item.title,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 1),

                            // Subtitle
                            TranslatedText(
                              item.subtitle,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 8,
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.7)
                                    : Colors.black.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ];
  }
}

class _DashboardOption {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;

  _DashboardOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });
}

class DashboardShimmerPainter extends CustomPainter {
  final double progress;
  final bool isDarkMode;

  DashboardShimmerPainter({required this.progress, required this.isDarkMode});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDarkMode
            ? [
                Colors.transparent,
                Colors.white.withOpacity(0.05),
                Colors.transparent,
              ]
            : [
                Colors.transparent,
                Colors.white.withOpacity(0.2),
                Colors.transparent,
              ],
        stops: [
          math.max(0.0, progress - 0.4),
          progress,
          math.min(1.0, progress + 0.4),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
