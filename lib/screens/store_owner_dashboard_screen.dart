import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/screens/orders_list_screen.dart';
import 'package:exanor/screens/store_owner_pos_screen.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'package:flutter/material.dart';

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

    // If no tabs configured, fallback to just POS screen
    if (_tabs.isEmpty) {
      return StoreOwnerPOSScreen(
        storeId: widget.storeId,
        storeName: widget.storeName,
      );
    }

    // Build the screens based on tabs
    // We use IndexedStack so screens preserve state
    final screens = _tabs.map((tab) {
      final id = tab['id'];
      if (id == 'pos') {
        return StoreOwnerPOSScreen(
          storeId: widget.storeId,
          storeName: widget.storeName,
        );
      } else if (id == 'orders') {
        return OrdersListScreen(storeId: widget.storeId);
      }
      return Container(); // Fallback for unknown IDs
    }).toList();

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (index) {
                final tab = _tabs[index];
                final isSelected = _currentIndex == index;
                final color = isSelected
                    ? theme.primaryColor
                    : theme.disabledColor;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.primaryColor.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getIconData(
                            isSelected
                                ? (tab['activeIcon'] ?? tab['icon'])
                                : tab['icon'],
                          ),
                          color: color,
                        ),
                        const SizedBox(height: 4),
                        TranslatedText(
                          tab['label'] ?? '',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
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
      ),
    );
  }
}
