import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/screens/orders_list_screen.dart';
import 'package:exanor/screens/purchase_screen.dart';
import 'package:exanor/screens/receipts_screen.dart';
import 'package:exanor/components/store_main_drawer.dart';
import 'package:exanor/screens/store_owner_pos_screen.dart';

import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

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

class _StoreOwnerDashboardScreenState extends State<StoreOwnerDashboardScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _tabs = [];

  @override
  void initState() {
    super.initState();
    _loadTabs();
  }

  void _loadTabs() {
    setState(() {
      _tabs = FirebaseRemoteConfigService.getStoreOwnerBottomNavTabs();
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
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget child;

    // If no tabs configured, fallback to just POS screen
    if (_tabs.isEmpty) {
      child = StoreOwnerPOSScreen(
        storeId: widget.storeId,
        storeName: widget.storeName,
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
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
          );
        } else if (id == 'orders') {
          return OrdersListScreen(
            storeId: widget.storeId,
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
          );
        } else if (id == 'purchases') {
          return PurchaseScreen(storeId: widget.storeId);
        } else if (id == 'receipts') {
          return ReceiptsScreen(storeId: widget.storeId);
        }
        return Container(); // Fallback for unknown IDs
      }).toList();

      child = Scaffold(
        key: _scaffoldKey,
        drawer: StoreMainDrawer(
          storeId: widget.storeId,
          storeName: widget.storeName,
        ),
        body: IndexedStack(index: _currentIndex, children: screens),
        bottomNavigationBar: __buildBottomNavigationBar(theme, _tabs),
      );
    }

    return WillPopScope(
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
      child: child,
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

              return Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
}
