import 'dart:math' as math;

import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/screens/orders_list_screen.dart';
import 'package:exanor/screens/purchase_screen.dart';
import 'package:exanor/screens/receipts_screen.dart';
import 'package:exanor/components/store_main_drawer.dart';
import 'package:exanor/screens/store_owner_pos_screen.dart';
import 'package:exanor/screens/assistant_screen.dart';

import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:exanor/services/notification_service.dart';
import 'package:exanor/utils/keyboard_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StoreOwnerDashboardScreen extends StatefulWidget {
  final String storeId;
  final String storeName;

  const StoreOwnerDashboardScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<StoreOwnerDashboardScreen> createState() =>
      _StoreOwnerDashboardScreenState();
}

class _StoreOwnerDashboardScreenState extends State<StoreOwnerDashboardScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isAssistantOpen = false;
  bool _isShortcutOverlayVisible = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<AssistantScreenState> _assistantKey =
      GlobalKey<AssistantScreenState>();
  final DesktopActionController _posActionController =
      DesktopActionController();
  final FocusNode _dashboardFocusNode = FocusNode();
  List<Map<String, dynamic>> _tabs = [];

  // Animation controllers for the Assistant tab icon
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadTabs();

    _posActionController.restoreFocus = () {
      if (mounted) {
        _dashboardFocusNode.requestFocus();
      }
    };

    // Create notification token after authentication
    NotificationService.createNotificationToken();
  }

  void _initAnimations() {
    // Pulse animation - subtle scale effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Rotate animation - subtle rotation for sparkle effect
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );
    _rotateAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(parent: _rotateController, curve: Curves.linear));
    _rotateController.repeat();

    // Glow animation - pulsing glow effect
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    _glowController.repeat(reverse: true);
  }

  void _loadTabs() {
    setState(() {
      // Get base tabs from remote config or fallback
      try {
        _tabs = List<Map<String, dynamic>>.from(
          FirebaseRemoteConfigService.getStoreOwnerBottomNavTabs(),
        );
      } catch (e) {
        // Fallback if remote config service fails or returns unmodifiable list
        _tabs = [
          {
            'id': 'pos',
            'label': 'POS',
            'icon': 'point_of_sale_outlined',
            'activeIcon': 'point_of_sale',
          },
          {
            'id': 'orders',
            'label': 'Orders',
            'icon': 'receipt_long_outlined',
            'activeIcon': 'receipt_long',
          },
          {
            'id': 'purchases',
            'label': 'Purchases',
            'icon': 'shopping_bag_outlined',
            'activeIcon': 'shopping_bag',
          },
          {
            'id': 'receipts',
            'label': 'Receipts',
            'icon': 'receipt_long_outlined',
            'activeIcon': 'receipt_long',
          },
        ];
      }

      // Ensure Assistant tab is always present and correctly configured
      _tabs.removeWhere((tab) => tab['id'] == 'assistant');
      _tabs.add({
        'id': 'assistant',
        'label': 'Assistant',
        'icon': 'assistant',
        'activeIcon': 'assistant_active',
      });
    });
  }

  /// Helper to get icon data from string name
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'point_of_sale':
        return Icons.point_of_sale;
      case 'point_of_sale_outlined':
        return Icons.point_of_sale_outlined;
      case 'receipt_long':
        return Icons.receipt_long;
      case 'receipt_long_outlined':
        return Icons.receipt_long_outlined;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'shopping_bag_outlined':
        return Icons.shopping_bag_outlined;
      case 'home':
        return Icons.home;
      case 'home_outlined':
        return Icons.home_outlined;
      case 'person':
        return Icons.person;
      case 'person_outline':
        return Icons.person_outline;
      case 'assistant':
      case 'assistant_active':
        return Icons.auto_awesome;
      default:
        return Icons.circle;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _glowController.dispose();
    _dashboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _buildWithShortcuts(context, theme);
  }

  Widget _buildWithShortcuts(BuildContext context, ThemeData theme) {
    Widget child;

    // If no tabs configured, fallback to just POS screen
    if (_tabs.isEmpty) {
      child = StoreOwnerPOSScreen(
        storeId: widget.storeId,
        storeName: widget.storeName,
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        desktopActionController: _posActionController,
      );
    } else {
      // Build the screens based on tabs
      // We use IndexedStack so screens preserve state
      final screens = _tabs.map((tab) {
        final id = tab['id'];
        if (id == 'pos') {
          return StoreOwnerPOSScreen(
            storeId: widget.storeId,
            storeName: widget.storeName,
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
            desktopActionController: _posActionController,
          );
        } else if (id == 'orders') {
          return OrdersListScreen(
            storeId: widget.storeId,
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
          );
        } else if (id == 'purchases') {
          return PurchaseScreen(
            storeId: widget.storeId,
            storeName: widget.storeName,
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
          );
        } else if (id == 'receipts') {
          return ReceiptsScreen(
            storeId: widget.storeId,
            storeName: widget.storeName,
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
          );
        }
        return Container(); // Fallback for unknown IDs
      }).toList();

      final scaffold = Scaffold(
        key: _scaffoldKey,
        drawer: StoreMainDrawer(
          storeId: widget.storeId,
          storeName: widget.storeName,
          onTabSelected: (tabId) {
            // Find tab index by ID
            final index = _tabs.indexWhere((t) => t['id'] == tabId);
            if (index != -1) {
              setState(() {
                _currentIndex = index;
                // Close assistant if opening another tab
                if (tabId != 'assistant') {
                  _isAssistantOpen = false;
                }
              });
              return true; // We handled the navigation
            }
            return false; // Fallback to normal navigation
          },
        ),
        body: IndexedStack(index: _currentIndex, children: screens),
        bottomNavigationBar: __buildBottomNavigationBar(theme, _tabs),
      );

      child = Stack(
        children: [
          // 1. The main App Scaffold
          scaffold,

          // 2. Assistant Overlay (Covering EVERYTHING including bottom nav)
          if (_isAssistantOpen)
            Positioned.fill(
              child: AssistantScreen(
                key: _assistantKey,
                storeId: widget.storeId,
                storeName: widget.storeName,
                onClose: () {
                  setState(() {
                    _isAssistantOpen = false;
                  });
                  _assistantKey.currentState?.stopAssistant();
                },
              ),
            ),
        ],
      );
    }

    final wrappedChild = WillPopScope(
      onWillPop: () async {
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const TranslatedText('Exit App'),
              content: const TranslatedText(
                'Are you sure you want to close the app?',
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const TranslatedText(
                    'NO',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const TranslatedText(
                    'YES',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
        return shouldPop ?? false;
      },
      child: Stack(
        children: [
          child,
          // Keyboard shortcuts overlay
          if (_isShortcutOverlayVisible)
            KeyboardShortcutsOverlay(
              onClose: () => setState(() => _isShortcutOverlayVisible = false),
            ),
        ],
      ),
    );

    // Wrap with desktop keyboard shortcuts
    return DesktopShortcutWrapper(
      focusNode: _dashboardFocusNode,
      callbacks: ShortcutCallbacks(
        onSearch: () {
          // Switch to POS tab and focus search
          final posIndex = _tabs.indexWhere((t) => t['id'] == 'pos');
          if (posIndex != -1) {
            setState(() {
              _currentIndex = posIndex;
              _isAssistantOpen = false;
            });
          }
          _posActionController.focusSearch?.call();
        },
        onRefresh: () {
          _posActionController.refreshProducts?.call();
        },
        onOpenMenu: () {
          _scaffoldKey.currentState?.openDrawer();
        },
        onSwitchTab: (index) {
          if (index < _tabs.length) {
            final tabId = _tabs[index]['id'];
            if (tabId == 'assistant') {
              setState(() => _isAssistantOpen = true);
            } else {
              setState(() {
                _currentIndex = index;
                _isAssistantOpen = false;
              });
            }
          }
        },
        onOpenAssistant: () {
          setState(() => _isAssistantOpen = true);
        },
        onEscape: () {
          if (_isShortcutOverlayVisible) {
            setState(() => _isShortcutOverlayVisible = false);
          } else if (_isAssistantOpen) {
            setState(() => _isAssistantOpen = false);
            _assistantKey.currentState?.stopAssistant();
          }
        },
      ),
      child: CallbackShortcuts(
        bindings: {
          // Ctrl+/ → Show shortcut overlay
          const SingleActivator(LogicalKeyboardKey.slash, control: true): () {
            setState(
              () => _isShortcutOverlayVisible = !_isShortcutOverlayVisible,
            );
          },
        },
        child: wrappedChild,
      ),
    );
  }

  Widget __buildBottomNavigationBar(
    ThemeData theme,
    List<Map<String, dynamic>> tabs,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: true,
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(tabs.length, (index) {
              final tab = tabs[index];
              final isSelected = _currentIndex == index;
              final activeColor = theme.primaryColor;
              final inactiveColor = isDark
                  ? Colors.white54
                  : Colors.grey.shade500;
              final isAssistant = tab['id'] == 'assistant';

              return Expanded(
                child: InkWell(
                  onTap: () {
                    // Check if tapping assistant
                    if (tab['id'] == 'assistant') {
                      setState(() {
                        _isAssistantOpen = true;
                      });
                    } else {
                      setState(() {
                        _currentIndex = index;
                        // Close assistant if switching to other tabs (optional,
                        // but usually good UX to not keep it open)
                        // _isAssistantOpen = false;
                      });
                    }
                  },
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isAssistant)
                        _buildAnimatedAssistantIcon(
                          isSelected:
                              _isAssistantOpen, // Use overlay state for selection
                          activeColor: activeColor,
                          inactiveColor: inactiveColor,
                          isDark: isDark,
                        )
                      else
                        Icon(
                          _getIconData(
                            isSelected
                                ? (tab['activeIcon'] ?? tab['icon'])
                                : tab['icon'],
                          ),
                          color: isSelected ? activeColor : inactiveColor,
                          size: 26,
                        ),
                      const SizedBox(height: 4),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        style: TextStyle(
                          color: isSelected ? activeColor : inactiveColor,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                        ),
                        child: TranslatedText(
                          tab['label'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  /// Build the animated AI Assistant icon with futuristic effects
  Widget _buildAnimatedAssistantIcon({
    required bool isSelected,
    required Color activeColor,
    required Color inactiveColor,
    required bool isDark,
  }) {
    // Gradient colors for the AI assistant icon
    const List<Color> gradientColors = [
      Color(0xFF6366F1), // Indigo
      Color(0xFF8B5CF6), // Violet
      Color(0xFFA855F7), // Purple
    ];

    return AnimatedBuilder(
      animation: Listenable.merge([
        _pulseAnimation,
        _rotateAnimation,
        _glowAnimation,
      ]),
      builder: (context, child) {
        return SizedBox(
          width: 32,
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow effect (only when selected)
              if (isSelected)
                Container(
                  width: 28 * _pulseAnimation.value,
                  height: 28 * _pulseAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors[1].withOpacity(
                          _glowAnimation.value * 0.6,
                        ),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

              // Rotating sparkle particles (only when selected)
              if (isSelected) ...[
                for (int i = 0; i < 3; i++)
                  Transform.rotate(
                    angle: _rotateAnimation.value + (i * math.pi * 2 / 3),
                    child: Transform.translate(
                      offset: Offset(12 * _pulseAnimation.value, 0),
                      child: Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: gradientColors[i].withOpacity(
                            _glowAnimation.value,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],

              // Main icon with gradient (when selected) or plain (when not)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                transform: Matrix4.identity()
                  ..scale(
                    isSelected ? _pulseAnimation.value : 1.0,
                    isSelected ? _pulseAnimation.value : 1.0,
                  ),
                transformAlignment: Alignment.center,
                child: isSelected
                    ? ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: gradientColors,
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcIn,
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 26,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.auto_awesome_outlined,
                        size: 24,
                        color: inactiveColor,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
