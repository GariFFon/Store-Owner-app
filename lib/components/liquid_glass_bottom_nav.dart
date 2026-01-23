import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/api_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exanor/components/dashboard_section.dart';
import 'package:exanor/components/language_selector.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/screens/qr_scanner_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:async'; // Added for Timer

// Badge types for navigation items
enum BadgeType {
  none,
  freeBadge,
  goldenBadge,
  newBadge,
  hotBadge,
  topBadge,
  offerBadge,
  saleBadge,
  limitedBadge,
  premiumBadge,
  alertBadge,
  infoBadge,
  successBadge,
  warningBadge,
}

// Navigation tab model for remote config
class BottomNavTab {
  final String id;
  final String label;
  final String icon;
  final String activeIcon;
  final String action;
  final String? actionData;
  final BadgeType badgeType;
  final String? badgeText;
  final String? badgeColor;
  final int index;

  BottomNavTab({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.action,
    this.actionData,
    required this.badgeType,
    this.badgeText,
    this.badgeColor,
    required this.index,
  });

  factory BottomNavTab.fromJson(Map<String, dynamic> json) {
    BadgeType parseBadgeType(String badgeTypeStr) {
      switch (badgeTypeStr.toLowerCase()) {
        case 'freebadge':
          return BadgeType.freeBadge;
        case 'goldenbadge':
          return BadgeType.goldenBadge;
        case 'newbadge':
          return BadgeType.newBadge;
        case 'hotbadge':
          return BadgeType.hotBadge;
        case 'topbadge':
          return BadgeType.topBadge;
        case 'offerbadge':
          return BadgeType.offerBadge;
        case 'salebadge':
          return BadgeType.saleBadge;
        case 'limitedbadge':
          return BadgeType.limitedBadge;
        case 'premiumbadge':
          return BadgeType.premiumBadge;
        case 'alertbadge':
          return BadgeType.alertBadge;
        case 'infobadge':
          return BadgeType.infoBadge;
        case 'successbadge':
          return BadgeType.successBadge;
        case 'warningbadge':
          return BadgeType.warningBadge;
        default:
          return BadgeType.none;
      }
    }

    return BottomNavTab(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      icon: json['icon'] ?? 'help_outline',
      activeIcon: json['activeIcon'] ?? 'help',
      action: json['action'] ?? 'navigate',
      actionData: json['actionData'],
      badgeType: parseBadgeType(json['badgeType'] ?? 'none'),
      badgeText: json['badgeText'],
      badgeColor: json['badgeColor'],
      index: json['index'] ?? 0,
    );
  }

  // Method to get IconData from string dynamically
  IconData getIconData(String iconName) {
    // Handle Icons.iconName format
    if (iconName.startsWith('Icons.')) {
      final cleanIconName = iconName.substring(6); // Remove "Icons." prefix
      return _getIconByName(cleanIconName);
    }

    // Handle direct icon name
    return _getIconByName(iconName);
  }

  IconData _getIconByName(String iconName) {
    // Use reflection-like approach to get icon from Icons class
    try {
      // Convert snake_case to camelCase if needed
      String processedName = iconName;

      // Map of icon names to IconData
      const iconMap = {
        // Home icons
        'home_outlined': Icons.home_outlined,
        'home': Icons.home,

        // Person/User icons
        'person_add_outlined': Icons.person_add_outlined,
        'person_add': Icons.person_add,
        'person_outline': Icons.person_outline,
        'person': Icons.person,

        // Gift/Card icons
        'card_giftcard_outlined': Icons.card_giftcard_outlined,
        'card_giftcard': Icons.card_giftcard,

        // Translation icons
        'translate_outlined': Icons.translate_outlined,
        'translate': Icons.translate,

        // Play/Media icons
        'play_circle_outline': Icons.play_circle_outline,
        'play_circle_filled': Icons.play_circle_filled,
        'video_library_outlined': Icons.video_library_outlined,
        'video_library': Icons.video_library,

        // Communication icons
        'chat_bubble_outline': Icons.chat_bubble_outline,
        'chat_bubble': Icons.chat_bubble,
        'notifications_outlined': Icons.notifications_outlined,
        'notifications': Icons.notifications,

        // Feed icons
        'feed_outlined': Icons.feed_outlined,
        'feed': Icons.feed,

        // Transport/Taxi icons
        'local_taxi_outlined': Icons.local_taxi_outlined,
        'local_taxi': Icons.local_taxi,
        'directions_car_outlined': Icons.directions_car_outlined,
        'directions_car': Icons.directions_car,
        'airport_shuttle_outlined': Icons.airport_shuttle_outlined,
        'airport_shuttle': Icons.airport_shuttle,

        // Tasks/Work icons
        'task_outlined': Icons.task_outlined,
        'task': Icons.task,
        'assignment_outlined': Icons.assignment_outlined,
        'assignment': Icons.assignment,
        'work_outline': Icons.work_outline,
        'work': Icons.work,
        'list_alt_outlined': Icons.list_alt_outlined,
        'list_alt': Icons.list_alt,

        // Business icons
        'business_outlined': Icons.business_outlined,
        'business': Icons.business,
        'store_outlined': Icons.store_outlined,
        'store': Icons.store,

        // Navigation icons
        'menu': Icons.menu,
        'menu_outlined': Icons.menu_outlined,
        'more_horiz': Icons.more_horiz,
        'more_vert': Icons.more_vert,

        // Common icons
        'help_outline': Icons.help_outline,
        'help': Icons.help,
        'info_outline': Icons.info_outline,
        'info': Icons.info,
        'settings_outlined': Icons.settings_outlined,
        'settings': Icons.settings,
        'search_outlined': Icons.search_outlined,
        'search': Icons.search,
        'favorite_outline': Icons.favorite_outline,
        'favorite': Icons.favorite,
        'star_outline': Icons.star_outline,
        'star': Icons.star,
        'bookmark_outline': Icons.bookmark_outline,
        'bookmark': Icons.bookmark,
        'shopping_cart_outlined': Icons.shopping_cart_outlined,
        'shopping_cart': Icons.shopping_cart,
        'location_on_outlined': Icons.location_on_outlined,
        'location_on': Icons.location_on,
        'phone_outlined': Icons.phone_outlined,
        'phone': Icons.phone,
        'email_outlined': Icons.email_outlined,
        'email': Icons.email,
        'camera_alt_outlined': Icons.camera_alt_outlined,
        'camera_alt': Icons.camera_alt,
        'photo_camera_outlined': Icons.photo_camera_outlined,
        'photo_camera': Icons.photo_camera,
        'add_circle_outline': Icons.add_circle_outline,
        'add_circle': Icons.add_circle,
        'remove_circle_outline': Icons.remove_circle_outline,
        'remove_circle': Icons.remove_circle,
        'edit_outlined': Icons.edit_outlined,
        'edit': Icons.edit,
        'delete_outline': Icons.delete_outline,
        'delete': Icons.delete,
        'share_outlined': Icons.share_outlined,
        'share': Icons.share,
        'download_outlined': Icons.download_outlined,
        'download': Icons.download,
        'upload_outlined': Icons.upload_outlined,
        'upload': Icons.upload,
        'visibility_outlined': Icons.visibility_outlined,
        'visibility': Icons.visibility,
        'visibility_off_outlined': Icons.visibility_off_outlined,
        'visibility_off': Icons.visibility_off,
        'lock_outline': Icons.lock_outline,
        'lock': Icons.lock,
        'lock_open_outlined': Icons.lock_open_outlined,
        'lock_open': Icons.lock_open,
      };

      return iconMap[processedName] ?? Icons.help_outline;
    } catch (e) {
      print('Error getting icon for name: $iconName, error: $e');
      return Icons.help_outline;
    }
  }

  IconData get iconData => getIconData(icon);
  IconData get activeIconData => getIconData(activeIcon);
}

// Constants for easy customization
class LiquidGlassNavConstants {
  // Blur values
  static const double mainBlur = 15.0;
  static const double selectedItemBlur = 6.0;

  // Main glass transparency (dark mode)
  static const double darkModeMainOpacity1 = 0.08;
  static const double darkModeMainOpacity2 = 0.02;
  static const double darkModeMainOpacity3 = 0.05;

  // Main glass transparency (light mode)
  static const double lightModeMainOpacity1 = 0.4;
  static const double lightModeMainOpacity2 = 0.15;
  static const double lightModeMainOpacity3 = 0.25;

  // Selected item transparency (dark mode)
  static const double darkModeSelectedOpacity1 = 0.12;
  static const double darkModeSelectedOpacity2 = 0.03;
  static const double darkModeSelectedOpacity3 = 0.08;

  // Selected item transparency (light mode)
  static const double lightModeSelectedOpacity1 = 0.6;
  static const double lightModeSelectedOpacity2 = 0.25;
  static const double lightModeSelectedOpacity3 = 0.4;

  // Border transparency
  static const double darkModeBorderOpacity = 0.15;
  static const double lightModeBorderOpacity = 0.5;

  // Shadow transparency
  static const double darkModeShadowOpacity = 0.2;
  static const double lightModeShadowOpacity = 0.08;
  static const double darkModeHighlightOpacity = 0.05;
  static const double lightModeHighlightOpacity = 0.4;
}

class RegistrationBottomSheet extends StatefulWidget {
  final VoidCallback onClose;

  const RegistrationBottomSheet({super.key, required this.onClose});

  @override
  State<RegistrationBottomSheet> createState() =>
      _RegistrationBottomSheetState();
}

class _RegistrationBottomSheetState extends State<RegistrationBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _closeBottomSheet() {
    widget.onClose();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Container(
          height:
              screenSize.height *
              0.75, // Increased to accommodate new dashboard design
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.4)
                    : Colors.black.withOpacity(0.15),
                blurRadius: 25,
                spreadRadius: 0,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDarkMode
                        ? [
                            Colors.white.withOpacity(0.12),
                            Colors.white.withOpacity(0.05),
                            Colors.white.withOpacity(0.08),
                          ]
                        : [
                            Colors.white.withOpacity(0.8),
                            Colors.white.withOpacity(0.4),
                            Colors.white.withOpacity(0.6),
                          ],
                  ),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.15)
                        : Colors.white.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.3)
                            : Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Shimmer.fromColors(
                              baseColor: Colors.amber[600]!.withOpacity(0.7),
                              highlightColor: Colors.amber[200]!,
                              period: const Duration(milliseconds: 1500),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.diamond,
                                    color: Colors.amber[600],
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: TranslatedText(
                                      'Register',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber[600],
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _closeBottomSheet,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.1),
                              ),
                              child: Icon(
                                Icons.close,
                                size: 20,
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.8)
                                    : Colors.black.withOpacity(0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dashboard section
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: const DashboardSection(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class LiquidGlassBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const LiquidGlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<LiquidGlassBottomNav> createState() => _LiquidGlassBottomNavState();
}

class _LiquidGlassBottomNavState extends State<LiquidGlassBottomNav>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  late AnimationController _glitterController;
  late List<Animation<double>> _glitterAnimations;
  late AnimationController _pulsateController;
  late Animation<double> _pulsateAnimation;

  // Auto-scroll animation controller
  late AnimationController _autoScrollController;
  late Animation<double> _autoScrollAnimation;
  Timer? _idleTimer;
  bool _isAutoScrolling = false;
  bool _hasAutoScrolled = false;

  final ScrollController _scrollController = ScrollController();
  late List<GlobalKey> _itemKeys;
  int _referralRewardAmount = 100; // Default value
  List<BottomNavTab> _navigationTabs = [];

  @override
  void initState() {
    super.initState();
    _loadNavigationTabs();
  }

  void _loadNavigationTabs() {
    try {
      // Load navigation tabs from remote config
      final tabsData = FirebaseRemoteConfigService.getBottomNavBarTabs();
      _navigationTabs = tabsData
          .map((json) => BottomNavTab.fromJson(json))
          .toList();

      // Sort by index to ensure correct order
      _navigationTabs.sort((a, b) => a.index.compareTo(b.index));

      print(
        '📱 Loaded ${_navigationTabs.length} navigation tabs from remote config',
      );
    } catch (e) {
      print('❌ Error loading navigation tabs: $e');
      // Fallback to default tabs
      _navigationTabs = _getDefaultTabs();
    }

    // Initialize keys and controllers based on tab count
    _itemKeys = List.generate(_navigationTabs.length, (index) => GlobalKey());

    _controllers = List.generate(
      _navigationTabs.length,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: this,
      ),
    );

    _animations = _controllers
        .map(
          (controller) =>
              CurvedAnimation(parent: controller, curve: Curves.elasticOut),
        )
        .toList();

    // Initialize blinking animation for badges
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    // Initialize shimmer animation for golden badge
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    // Initialize glitter animation
    _glitterController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _glitterAnimations = List.generate(
      6,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _glitterController,
          curve: Interval(
            index * 0.1,
            (index * 0.1) + 0.4,
            curve: Curves.easeInOut,
          ),
        ),
      ),
    );

    // Initialize pulsate animation for FREE badge
    _pulsateController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulsateAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulsateController, curve: Curves.easeInOut),
    );

    // Initialize auto-scroll animation
    _autoScrollController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );
    _autoScrollAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _autoScrollController, curve: Curves.easeInOut),
    );

    // Start animation for the initially selected item
    if (widget.currentIndex < _controllers.length) {
      _controllers[widget.currentIndex].forward();
    }

    // Start animations
    _blinkController.repeat(reverse: true);
    _shimmerController.repeat();
    _glitterController.repeat();
    _pulsateController.repeat(reverse: true);

    // Start idle timer for auto-scroll
    _startIdleTimer();

    // Load referral reward amount
    _loadReferralRewardAmount();
  }

  List<BottomNavTab> _getDefaultTabs() {
    return [
      BottomNavTab(
        id: 'home',
        label: 'Home',
        icon: 'home_outlined',
        activeIcon: 'home',
        action: 'navigate',
        actionData: '/home',
        badgeType: BadgeType.none,
        index: 0,
      ),
      BottomNavTab(
        id: 'register',
        label: 'Register',
        icon: 'person_add_outlined',
        activeIcon: 'person_add',
        action: 'showRegistration',
        badgeType: BadgeType.freeBadge,
        index: 1,
      ),
      BottomNavTab(
        id: 'refer',
        label: 'Refer & Earn',
        icon: 'card_giftcard_outlined',
        activeIcon: 'card_giftcard',
        action: 'navigate',
        actionData: '/refer_and_earn',
        badgeType: BadgeType.goldenBadge,
        index: 2,
      ),
      BottomNavTab(
        id: 'translate',
        label: 'Translate',
        icon: 'translate_outlined',
        activeIcon: 'translate',
        action: 'showLanguageSelector',
        badgeType: BadgeType.none,
        index: 3,
      ),
    ];
  }

  void _loadReferralRewardAmount() {
    try {
      setState(() {
        _referralRewardAmount =
            FirebaseRemoteConfigService.getReferralRewardAmount();
      });
    } catch (e) {
      // Keep default value if error occurs
      print('Error loading referral reward amount: $e');
    }
  }

  @override
  void didUpdateWidget(LiquidGlassBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      if (oldWidget.currentIndex < _controllers.length) {
        _controllers[oldWidget.currentIndex].reverse();
      }
      if (widget.currentIndex < _controllers.length) {
        _controllers[widget.currentIndex].forward();
        _scrollToItem(widget.currentIndex);
      }
    }
  }

  void _scrollToItem(int index) {
    if (index < _itemKeys.length && _itemKeys[index].currentContext != null) {
      final RenderBox renderBox =
          _itemKeys[index].currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final screenWidth = MediaQuery.of(context).size.width;
      final itemWidth = renderBox.size.width;

      final targetScroll = position.dx - (screenWidth / 2) + (itemWidth / 2);

      _scrollController.animateTo(
        targetScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _handleTabAction(BottomNavTab tab) {
    // Reset idle timer on user interaction
    _resetIdleTimer();

    // Provide haptic feedback
    HapticFeedback.lightImpact();

    switch (tab.action) {
      case 'showRegistration':
        _showRegistrationPopup();
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
      case 'navigate':
        if (tab.actionData != null && tab.actionData!.isNotEmpty) {
          if (tab.actionData == '/refer_and_earn') {
            _showReferEarnScreen();
          } else if (tab.actionData == '/feed') {
            _showFeedScreen();
          } else {
            Navigator.pushNamed(context, tab.actionData!).then((_) {
              // Reset to home tab when returning
              widget.onTap(0);
            });
          }
        } else {
          // Default navigation - just call the onTap
          widget.onTap(tab.index);
        }
        break;
      default:
        // Default behavior - call onTap
        widget.onTap(tab.index);
        break;
    }
  }

  void _showRegistrationPopup() {
    // Set register tab as selected when bottom sheet opens
    widget.onTap(1);

    _showRegistrationBottomSheet();
  }

  void _showRegistrationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RegistrationBottomSheet(
        onClose: () {
          // Reset to home tab when bottom sheet closes
          widget.onTap(0);
        },
      ),
    ).then((_) {
      // Ensure we reset to home tab when bottom sheet is dismissed
      widget.onTap(0);
    });
  }

  void _showReferEarnScreen() {
    // Navigate to refer and earn screen
    Navigator.pushNamed(context, '/refer_and_earn').then((_) {
      // Reset to home tab when returning
      widget.onTap(0);
    });
  }

  void _showLanguageSelector() {
    // Set translate tab as selected when language selector opens
    widget.onTap(3);

    showLanguageSelector(
      context,
      onLanguageSelected: (language) {
        // Language selected, reset to home tab
        widget.onTap(0);
      },
    ).then((_) {
      // Ensure we reset to home tab when language selector is dismissed
      widget.onTap(0);
    });
  }

  void _showFeedScreen() {
    // Navigate to feed screen
    Navigator.pushNamed(context, '/feed').then((_) {
      // Reset to home tab when returning
      widget.onTap(0);
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    _blinkController.dispose();
    _shimmerController.dispose();
    _glitterController.dispose();
    _pulsateController.dispose();
    _autoScrollController.dispose();
    _idleTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // Auto-scroll functionality
  void _startIdleTimer() {
    if (_hasAutoScrolled) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isAutoScrolling && !_hasAutoScrolled) {
        _performAutoScroll();
      }
    });
  }

  void _resetIdleTimer() {
    if (_isAutoScrolling) {
      _autoScrollController.stop();
      _isAutoScrolling = false;
    }
    _startIdleTimer();
  }

  void _performAutoScroll() async {
    if (!mounted || _navigationTabs.length <= 3)
      return; // Don't auto-scroll if few items

    _isAutoScrolling = true;

    // Calculate scroll positions
    final double maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      _isAutoScrolling = false;
      _startIdleTimer();
      return;
    }

    try {
      // Scroll to end
      await _scrollController.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 2000),
        curve: Curves.easeInOut,
      );

      if (!mounted) return;

      // Small pause at the end
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // Scroll back to beginning
      await _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 2000),
        curve: Curves.easeInOut,
      );

      if (!mounted) return;

      _isAutoScrolling = false;
      _hasAutoScrolled = true;
      // _startIdleTimer(); // Do not restart timer, just do it once.
    } catch (e) {
      _isAutoScrolling = false;
      // _startIdleTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;
    final bottomSheetHeight = screenSize.height * 0.75; // 75% of screen height

    // Adjust bottom padding: if we have safe area (like iOS home indicator or gesture nav),
    // reduce the margin so it doesn't look too high.
    final double bottomMargin = safeArea.bottom > 0 ? 0 : 12;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomMargin),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Navigation Pill (3/4 width)
          Expanded(
            flex: 4, // Changed from 3 to 4 as requested (4/5 width)
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  36,
                ), // Slightly reduced radius for 72px height
                boxShadow: [
                  BoxShadow(
                    color: isDarkMode
                        ? Colors.black.withOpacity(0.4)
                        : Colors.black.withOpacity(0.15),
                    blurRadius: 25,
                    spreadRadius: 0,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: LiquidGlassNavConstants.mainBlur,
                    sigmaY: LiquidGlassNavConstants.mainBlur,
                  ),
                  child: Container(
                    height: 72, // Set height to 72 as requested
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      // Enhanced frosted glass effect
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDarkMode
                            ? [
                                Colors.white.withOpacity(
                                  LiquidGlassNavConstants.darkModeMainOpacity1,
                                ),
                                Colors.white.withOpacity(
                                  LiquidGlassNavConstants.darkModeMainOpacity2,
                                ),
                                Colors.white.withOpacity(
                                  LiquidGlassNavConstants.darkModeMainOpacity3,
                                ),
                              ]
                            : [
                                Colors.white.withOpacity(
                                  LiquidGlassNavConstants.lightModeMainOpacity1,
                                ),
                                Colors.white.withOpacity(
                                  LiquidGlassNavConstants.lightModeMainOpacity2,
                                ),
                                Colors.white.withOpacity(
                                  LiquidGlassNavConstants.lightModeMainOpacity3,
                                ),
                              ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      // Multiple borders for glass effect
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white.withOpacity(
                                LiquidGlassNavConstants.darkModeBorderOpacity,
                              )
                            : Colors.white.withOpacity(
                                LiquidGlassNavConstants.lightModeBorderOpacity,
                              ),
                        width: 1.5,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        // Inner glass layer
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDarkMode
                              ? [
                                  Colors.white.withOpacity(0.05),
                                  Colors.transparent,
                                  Colors.white.withOpacity(0.02),
                                ]
                              : [
                                  Colors.white.withOpacity(0.2),
                                  Colors.transparent,
                                  Colors.white.withOpacity(0.1),
                                ],
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Horizontally scrollable navigation items
                          NotificationListener<ScrollNotification>(
                            onNotification: (scrollNotification) {
                              if (scrollNotification
                                  is ScrollStartNotification) {
                                _resetIdleTimer();
                              }
                              return false;
                            },
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical:
                                      4, // Reduced from 8 to fit in 60px height
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: _buildNavigationItems(),
                                ),
                              ),
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

          const SizedBox(width: 12),

          // QR Scanner FAB (1/5 width)
          Expanded(
            flex: 1,
            child: Center(
              // Center to keep it circular within the flex space
              child: _buildQrFab(isDarkMode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrFab(bool isDarkMode) {
    return GestureDetector(
      onTap: () async {
        // Always try to request permission first.
        final status = await Permission.camera.request();

        if (status.isGranted) {
          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QRScannerScreen()),
            );
          }
        } else {
          // If permission is denied (permanently or otherwise), prompt user to settings
          if (context.mounted) {
            final isPermanentlyDenied = status.isPermanentlyDenied;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isPermanentlyDenied
                      ? 'Camera permission is permanently denied. Please enable it in settings.'
                      : 'Camera permission is required to scan QR codes. Please enable it in settings.',
                ),
                action: SnackBarAction(
                  label: 'Settings',
                  onPressed: () => openAppSettings(),
                ),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      child: Container(
        height: 72, // Match nav bar height
        width: 72, // Match height to be circular
        decoration: BoxDecoration(
          shape: BoxShape.circle, // Ensure it's perfectly round
          color: Theme.of(
            context,
          ).colorScheme.primary, // Use colorScheme.primary for consistency
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 0,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.qr_code_scanner_rounded,
            size: 24, // Reduced
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required GlobalKey key,
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required BadgeType badgeType,
  }) {
    final isSelected = widget.currentIndex == index;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return GestureDetector(
      key: key,
      onTap: () {
        // Get the tab configuration for this index
        if (index < _navigationTabs.length) {
          final tab = _navigationTabs[index];
          _handleTabAction(tab);
        } else {
          // Fallback to default behavior
          widget.onTap(index);
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: isSelected
                ? BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: LiquidGlassNavConstants.selectedItemBlur,
                      sigmaY: LiquidGlassNavConstants.selectedItemBlur,
                    ),
                    child: Container(
                      width: 48, // Reduced from 64
                      height: 48, // Reduced from 64
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        // Enhanced glass effect for selected state
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
                                  theme.colorScheme.primary.withOpacity(0.15),
                                  theme.colorScheme.primary.withOpacity(0.05),
                                  theme.colorScheme.primary.withOpacity(0.1),
                                ],
                        ),
                        // Replaced 3D floating effect with thin border as requested
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.2)
                              : theme.colorScheme.primary.withOpacity(0.3),
                          width: 1.0,
                        ),
                      ),
                      child: _buildNavItemContent(
                        index,
                        icon,
                        activeIcon,
                        label,
                        isSelected,
                        theme,
                        isDarkMode,
                      ),
                    ),
                  )
                : Container(
                    width: 48, // Reduced from 64
                    height: 48, // Reduced from 64
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _buildNavItemContent(
                      index,
                      icon,
                      activeIcon,
                      label,
                      isSelected,
                      theme,
                      isDarkMode,
                    ),
                  ),
          ),
          // Badges for different nav items
          if (badgeType == BadgeType.freeBadge) _buildFreeBadge(),
          if (badgeType == BadgeType.goldenBadge) _buildGoldenBadge(),
          if (badgeType != BadgeType.none &&
              badgeType != BadgeType.freeBadge &&
              badgeType != BadgeType.goldenBadge)
            _buildCustomBadge(index),
        ],
      ),
    );
  }

  Widget _buildNavItemContent(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
    bool isSelected,
    ThemeData theme,
    bool isDarkMode,
  ) {
    return AnimatedBuilder(
      animation: _animations[index],
      builder: (context, child) {
        return Transform.scale(
          scale: isSelected ? 1.0 + (_animations[index].value * 0.1) : 1.0,
          child: Container(
            height: 48, // Reduced from 64
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    key: ValueKey(isSelected),
                    size: 24,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : isDarkMode
                        ? Colors.white.withOpacity(0.8)
                        : Colors.black.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                TranslatedText(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : isDarkMode
                        ? Colors.white.withOpacity(0.8)
                        : Colors.black.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFreeBadge() {
    return Positioned(
      top: 2,
      right: 2,
      child: AnimatedBuilder(
        animation: _pulsateAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulsateAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(_blinkAnimation.value),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(_blinkAnimation.value * 0.6),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                'FREE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGoldenBadge() {
    return Positioned(
      top: -2,
      right: -2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Glitter effects around the badge
          ..._buildGlitterEffects(),

          // Main golden badge with shimmer
          AnimatedBuilder(
            animation: _shimmerAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.amber.shade300,
                      Colors.amber.shade600,
                      Colors.orange.shade400,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 3,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Shimmer overlay
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Transform.translate(
                          offset: Offset(_shimmerAnimation.value * 50, 0),
                          child: Container(
                            width: 20,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withOpacity(0.4),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Badge text
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '₹',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$_referralRewardAmount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGlitterEffects() {
    return _glitterAnimations.asMap().entries.map((entry) {
      final index = entry.key;
      final animation = entry.value;

      // Create random positions around the badge
      final double angle = (index * 60.0) * (pi / 180.0); // Convert to radians
      final double radius = 25.0 + (index % 2) * 10.0;
      final double x = radius * cos(angle);
      final double y = radius * sin(angle);

      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          return Positioned(
            left: x + 15,
            top: y + 10,
            child: Opacity(
              opacity: animation.value,
              child: Transform.scale(
                scale: 0.5 + (animation.value * 0.5),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.amber.shade200,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.6),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildNavigationItems() {
    List<Widget> items = [];
    for (int i = 0; i < _navigationTabs.length; i++) {
      final tab = _navigationTabs[i];
      items.add(
        _buildNavItem(
          key: _itemKeys[i],
          index: i,
          icon: tab.iconData,
          activeIcon: tab.activeIconData,
          label: tab.label,
          badgeType: tab.badgeType,
        ),
      );
      if (i < _navigationTabs.length - 1) {
        items.add(const SizedBox(width: 24));
      }
    }
    return items;
  }

  Widget _buildCustomBadge(int index) {
    if (index >= _navigationTabs.length) return const SizedBox.shrink();

    final tab = _navigationTabs[index];
    final badgeText = tab.badgeText ?? _getDefaultBadgeText(tab.badgeType);
    final badgeColor = _getBadgeColor(tab.badgeType, tab.badgeColor);

    return Positioned(
      top: 2,
      right: 2,
      child: AnimatedBuilder(
        animation: _getBadgeAnimation(tab.badgeType),
        builder: (context, child) {
          return Transform.scale(
            scale: _getBadgeScale(tab.badgeType),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(_getBadgeOpacity(tab.badgeType)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: badgeColor.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: badgeColor.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _getDefaultBadgeText(BadgeType badgeType) {
    switch (badgeType) {
      case BadgeType.newBadge:
        return 'NEW';
      case BadgeType.hotBadge:
        return 'HOT';
      case BadgeType.topBadge:
        return 'TOP';
      case BadgeType.offerBadge:
        return 'OFFER';
      case BadgeType.saleBadge:
        return 'SALE';
      case BadgeType.limitedBadge:
        return 'LIMITED';
      case BadgeType.premiumBadge:
        return 'PRO';
      case BadgeType.alertBadge:
        return '!';
      case BadgeType.infoBadge:
        return 'i';
      case BadgeType.successBadge:
        return '✓';
      case BadgeType.warningBadge:
        return '⚠';
      default:
        return '';
    }
  }

  Color _getBadgeColor(BadgeType badgeType, String? customColor) {
    if (customColor != null && customColor.isNotEmpty) {
      try {
        String hex = customColor.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (e) {
        print('Invalid badge color: $customColor');
      }
    }

    switch (badgeType) {
      case BadgeType.newBadge:
        return Colors.green;
      case BadgeType.hotBadge:
        return Colors.red;
      case BadgeType.topBadge:
        return Colors.purple;
      case BadgeType.offerBadge:
        return Colors.orange;
      case BadgeType.saleBadge:
        return Colors.pink;
      case BadgeType.limitedBadge:
        return Colors.deepOrange;
      case BadgeType.premiumBadge:
        return Colors.indigo;
      case BadgeType.alertBadge:
        return Colors.red;
      case BadgeType.infoBadge:
        return Colors.blue;
      case BadgeType.successBadge:
        return Colors.green;
      case BadgeType.warningBadge:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  Animation<double> _getBadgeAnimation(BadgeType badgeType) {
    switch (badgeType) {
      case BadgeType.hotBadge:
      case BadgeType.alertBadge:
        return _blinkAnimation;
      case BadgeType.newBadge:
      case BadgeType.topBadge:
        return _pulsateAnimation;
      default:
        return _blinkAnimation;
    }
  }

  double _getBadgeScale(BadgeType badgeType) {
    switch (badgeType) {
      case BadgeType.hotBadge:
      case BadgeType.alertBadge:
        return 1.0;
      case BadgeType.newBadge:
      case BadgeType.topBadge:
        return _pulsateAnimation.value;
      default:
        return 1.0;
    }
  }

  double _getBadgeOpacity(BadgeType badgeType) {
    switch (badgeType) {
      case BadgeType.hotBadge:
      case BadgeType.alertBadge:
        return _blinkAnimation.value;
      default:
        return 1.0;
    }
  }
}

class ReferEarnBottomSheet extends StatefulWidget {
  final VoidCallback onClose;

  const ReferEarnBottomSheet({super.key, required this.onClose});

  @override
  State<ReferEarnBottomSheet> createState() => _ReferEarnBottomSheetState();
}

class _ReferEarnBottomSheetState extends State<ReferEarnBottomSheet>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _giftController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _giftBounceAnimation;

  String _referralCode = '';
  bool _isLoadingCode = true;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _giftController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _giftBounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _giftController, curve: Curves.elasticOut),
    );

    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _giftController.repeat(reverse: true);
    });

    _loadReferralCode();
  }

  Future<void> _loadReferralCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phoneNumber = prefs.getString('phone_number') ?? '';

      // Display full phone number as referral code
      if (phoneNumber.isNotEmpty) {
        setState(() {
          _referralCode = phoneNumber; // Display full phone number
          _isLoadingCode = false;
        });
      } else {
        setState(() {
          _referralCode = 'No phone number found';
          _isLoadingCode = false;
        });
      }
    } catch (e) {
      setState(() {
        _referralCode = 'Error loading phone number';
        _isLoadingCode = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _giftController.dispose();
    super.dispose();
  }

  Future<void> _closeBottomSheet() async {
    try {
      _giftController.stop();
      _giftController.reset();
      await _animationController.reverse();
      widget.onClose();
    } catch (e) {
      print('Error closing bottom sheet: $e');
      widget.onClose();
    }
  }

  void _copyReferralCode() {
    Clipboard.setData(ClipboardData(text: _referralCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const TranslatedText('Referral code copied to clipboard!'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareReferralCode() async {
    // Get the app download URL from remote config
    final appDownloadUrl = FirebaseRemoteConfigService.getAppDownloadUrl();

    final message =
        '''🎁 Join exanor and get ₹100 FREE ad credits!

Use my referral code: $_referralCode

Boost your professional profile, find amazing jobs, or grow your business with FREE advertising credits!

Download exanor: $appDownloadUrl

#exanor #FreeCredits #ReferAndEarn''';

    try {
      // Use native system share dialog
      await Share.share(
        message,
        subject: 'Join exanor - Get ₹100 FREE Credits!',
      );
    } catch (e) {
      // Fallback to clipboard if share fails
      Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const TranslatedText(
              'Referral message copied to clipboard!',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final safeArea = MediaQuery.of(context).padding;
    final bottomSheetHeight = screenSize.height * 0.75; // 75% of screen height

    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: () async {
            // Stop gift animation and close bottom sheet
            _giftController.stop();
            await _closeBottomSheet();
          },
          child: Container(
            width: screenSize.width,
            height: screenSize.height,
            color: Colors.black.withOpacity(0.3 * _fadeAnimation.value),
            child: Stack(
              children: [
                // Bottom sheet
                AnimatedBuilder(
                  animation: _slideAnimation,
                  builder: (context, child) {
                    return Positioned(
                      bottom: -bottomSheetHeight * _slideAnimation.value,
                      left: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {}, // Prevent tap propagation
                        child: Container(
                          height: bottomSheetHeight,
                          margin: const EdgeInsets.only(top: 60),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDarkMode
                                    ? Colors.black.withOpacity(0.4)
                                    : Colors.black.withOpacity(0.15),
                                blurRadius: 25,
                                spreadRadius: 0,
                                offset: const Offset(0, -10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(32),
                              topRight: Radius.circular(32),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: LiquidGlassNavConstants.mainBlur,
                                sigmaY: LiquidGlassNavConstants.mainBlur,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(32),
                                    topRight: Radius.circular(32),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isDarkMode
                                        ? [
                                            Colors.white.withOpacity(0.12),
                                            Colors.white.withOpacity(0.05),
                                            Colors.white.withOpacity(0.08),
                                          ]
                                        : [
                                            Colors.white.withOpacity(0.8),
                                            Colors.white.withOpacity(0.4),
                                            Colors.white.withOpacity(0.6),
                                          ],
                                  ),
                                  border: Border.all(
                                    color: isDarkMode
                                        ? Colors.white.withOpacity(0.15)
                                        : Colors.white.withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(),
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Handle bar
                                        Center(
                                          child: Container(
                                            width: 40,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: isDarkMode
                                                  ? Colors.white.withOpacity(
                                                      0.3,
                                                    )
                                                  : Colors.black.withOpacity(
                                                      0.3,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 32),

                                        // Title
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: TranslatedText(
                                                'Refer & Earn',
                                                style: theme
                                                    .textTheme
                                                    .headlineSmall
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDarkMode
                                                          ? Colors.white
                                                          : Colors.black87,
                                                    ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () async {
                                                // Stop gift animation and close bottom sheet
                                                _giftController.stop();
                                                _giftController.reset();
                                                await _closeBottomSheet();
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: isDarkMode
                                                      ? Colors.white
                                                            .withOpacity(0.1)
                                                      : Colors.black
                                                            .withOpacity(0.1),
                                                ),
                                                child: Icon(
                                                  Icons.close,
                                                  size: 20,
                                                  color: isDarkMode
                                                      ? Colors.white
                                                            .withOpacity(0.8)
                                                      : Colors.black
                                                            .withOpacity(0.8),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),

                                        // Benefits section
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            color: isDarkMode
                                                ? Colors.white.withOpacity(0.05)
                                                : Colors.black.withOpacity(
                                                    0.05,
                                                  ),
                                            border: Border.all(
                                              color: Colors.amber.withOpacity(
                                                0.3,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber
                                                          .withOpacity(0.2),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.stars,
                                                      color: Colors.amber,
                                                      size: 20,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: TranslatedText(
                                                      'Get ₹100 Ad Credits',
                                                      style: theme
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: isDarkMode
                                                                ? Colors.white
                                                                      .withOpacity(
                                                                        0.9,
                                                                      )
                                                                : Colors.black
                                                                      .withOpacity(
                                                                        0.9,
                                                                      ),
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 12),
                                              TranslatedText(
                                                'When you refer a user, you get ₹100 of ad credits which you can use to boost your professional, employee or business profile.',
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: isDarkMode
                                                          ? Colors.white
                                                                .withOpacity(
                                                                  0.7,
                                                                )
                                                          : Colors.black
                                                                .withOpacity(
                                                                  0.7,
                                                                ),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        // Referral code section
                                        TranslatedText(
                                          'Your Referral Code',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: isDarkMode
                                                    ? Colors.white.withOpacity(
                                                        0.9,
                                                      )
                                                    : Colors.black.withOpacity(
                                                        0.9,
                                                      ),
                                              ),
                                        ),
                                        const SizedBox(height: 12),

                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            color: isDarkMode
                                                ? Colors.white.withOpacity(0.05)
                                                : Colors.black.withOpacity(
                                                    0.05,
                                                  ),
                                            border: Border.all(
                                              color: isDarkMode
                                                  ? Colors.white.withOpacity(
                                                      0.1,
                                                    )
                                                  : Colors.black.withOpacity(
                                                      0.1,
                                                    ),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: _isLoadingCode
                                                    ? Container(
                                                        height: 20,
                                                        decoration: BoxDecoration(
                                                          color: isDarkMode
                                                              ? Colors.white
                                                                    .withOpacity(
                                                                      0.1,
                                                                    )
                                                              : Colors.black
                                                                    .withOpacity(
                                                                      0.1,
                                                                    ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                      )
                                                    : Text(
                                                        _referralCode,
                                                        style: theme
                                                            .textTheme
                                                            .headlineSmall
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: const Color(
                                                                0xFFFFD700,
                                                              ), // Golden color
                                                              letterSpacing: 2,
                                                            ),
                                                      ),
                                              ),
                                              const SizedBox(width: 12),
                                              GestureDetector(
                                                onTap: _copyReferralCode,
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: theme
                                                        .colorScheme
                                                        .primary
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.copy,
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        // Share button
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: _shareReferralCode,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  theme.colorScheme.primary,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              elevation: 0,
                                            ),
                                            icon: const Icon(Icons.share),
                                            label: const TranslatedText(
                                              'Share with Friends',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 16,
                                              ),
                                            ),
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
                ),
                // Gift icon hovering above bottom sheet with glass morphism
                if (_giftController.isAnimating)
                  AnimatedBuilder(
                    animation: _giftBounceAnimation,
                    builder: (context, child) {
                      return Positioned(
                        bottom:
                            bottomSheetHeight +
                            20 +
                            (15 * _giftBounceAnimation.value),
                        left: screenSize.width / 2 - 50,
                        child: Transform.scale(
                          scale: 0.9 + (0.2 * _giftBounceAnimation.value),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.5),
                                  blurRadius: 30,
                                  spreadRadius: 8,
                                  offset: const Offset(0, 15),
                                ),
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.3),
                                  blurRadius: 60,
                                  spreadRadius: 15,
                                  offset: const Offset(0, 25),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.amber.withOpacity(0.9),
                                        Colors.orange.withOpacity(0.8),
                                        Colors.deepOrange.withOpacity(0.7),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.white.withOpacity(0.3),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.card_giftcard,
                                        size: 50,
                                        color: Colors.white,
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
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
