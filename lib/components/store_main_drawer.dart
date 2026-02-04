import 'package:exanor/screens/gst_rates_screen.dart';
import 'package:exanor/screens/orders_list_screen.dart';
import 'package:exanor/screens/overview_screen.dart';
import 'package:exanor/screens/payment_screen.dart';
import 'package:exanor/screens/purchase_screen.dart';
import 'package:exanor/screens/receipts_screen.dart';
import 'package:exanor/screens/sales_screen.dart';
import 'package:exanor/screens/store_selection_screen.dart';
import 'package:exanor/screens/settings_screen.dart';
import 'package:exanor/screens/gst_reports_screen.dart';
import 'package:exanor/screens/coupons_screen.dart';
import 'package:exanor/screens/staff_management_screen.dart';
import 'package:exanor/screens/financial_years_screen.dart';
import 'package:exanor/screens/suppliers_list_screen.dart';
import 'package:exanor/screens/customers_list_screen.dart';
import 'package:exanor/screens/inventory_screen.dart';
// import 'package:exanor/screens/auth/login_screen.dart'; // Assuming login screen exists
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoreMainDrawer extends StatefulWidget {
  final String storeId;
  final String storeName;
  final String? ownerName;

  const StoreMainDrawer({
    super.key,
    required this.storeId,
    required this.storeName,
    this.ownerName,
  });

  @override
  State<StoreMainDrawer> createState() => _StoreMainDrawerState();
}

class _StoreMainDrawerState extends State<StoreMainDrawer> {
  String? _ownerName;

  @override
  void initState() {
    super.initState();
    _ownerName = widget.ownerName;
    if (_ownerName == null) {
      _fetchOwnerName();
    }
  }

  Future<void> _fetchOwnerName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firstName = prefs.getString('first_name') ?? '';
      final lastName = prefs.getString('last_name') ?? '';
      if (mounted) {
        setState(() {
          _ownerName = '$firstName $lastName'.trim();
          if (_ownerName!.isEmpty) {
            _ownerName = 'Store Owner';
          }
        });
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      width: MediaQuery.of(context).size.width * 0.85 > 340
          ? 340
          : MediaQuery.of(context).size.width * 0.85,
      child: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Column(
                children: [
                  // Title Row with Gradient Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.primaryColor,
                                  Colors.blue.shade400,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Menu',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey.shade50,
                          padding: const EdgeInsets.all(8),
                        ),
                        icon: const Icon(
                          Icons.close,
                          size: 22,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Store Info Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.store_rounded,
                            color: theme.primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.storeName,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (_ownerName != null)
                                Text(
                                  _ownerName!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // MENU OPTIONS
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                children: [
                  // SWITCH STORE
                  _buildDrawerItem(
                    icon: Icons.store_mall_directory_outlined,
                    title: 'Switch Store',
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('selected_store_id');
                      await prefs.remove('selected_store_name');

                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StoreSelectionScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    isDestructive: true,
                  ),
                  const SizedBox(height: 20),

                  _buildSectionTitle('DASHBOARD'),
                  _buildDrawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Overview',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OverviewScreen(
                            storeId: widget.storeId,
                            ownerName: _ownerName ?? 'Store Owner',
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.point_of_sale_rounded,
                    title: 'Sales Panel (POS)',
                    // Main screen
                    onTap: () => Navigator.pop(context),
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('INVENTORY & SALES'),
                  _buildDrawerItem(
                    icon: Icons.inventory_2_outlined,
                    title: 'Products',
                    onTap: () {},
                  ),
                  _buildDrawerItem(
                    icon: Icons.local_shipping_outlined,
                    title: 'Orders',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              OrdersListScreen(storeId: widget.storeId),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.confirmation_number_outlined,
                    title: 'Coupons',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              CouponsScreen(storeId: widget.storeId),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.warehouse_outlined,
                    title: 'Inventory',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              InventoryScreen(storeId: widget.storeId),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('ADMINISTRATION'),

                  // Accounting
                  _buildExpansionGroup(
                    title: 'Accounting',
                    icon: Icons.account_balance_wallet_outlined,
                    children: [
                      _buildDrawerItem(
                        icon: Icons.shopping_bag_outlined,
                        title: 'Purchases',
                        isSmall: true,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PurchaseScreen(
                                storeId: widget.storeId,
                                storeName: widget.storeName,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.receipt_long_outlined,
                        title: 'Sales',
                        isSmall: true,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SalesScreen(storeId: widget.storeId),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.payment,
                        title: 'Payments',
                        isSmall: true,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PaymentScreen(storeId: widget.storeId),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.receipt,
                        title: 'Receipts',
                        isSmall: true,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReceiptsScreen(
                                storeId: widget.storeId,
                                storeName: widget.storeName,
                              ),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.storefront_outlined,
                        title: 'Suppliers',
                        isSmall: true,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  SuppliersListScreen(storeId: widget.storeId),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.people_outline,
                        title: 'Customers',
                        isSmall: true,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CustomersListScreen(storeId: widget.storeId),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.menu_book_outlined,
                        title: 'Ledger',
                        isSmall: true,
                        onTap: () {},
                      ),
                      _buildDrawerItem(
                        icon: Icons.description_outlined,
                        title: 'Invoices',
                        isSmall: true,
                        onTap: () {},
                      ),
                      _buildDrawerItem(
                        icon: Icons.bar_chart,
                        title: 'Reports',
                        isSmall: true,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Coming Soon')),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.calendar_month_outlined,
                        title: 'Financial Years',
                        isSmall: true,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FinancialYearsScreen(storeId: widget.storeId),
                            ),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.percent_rounded,
                        title: 'GST Rates',
                        isSmall: true,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  GstRatesScreen(storeId: widget.storeId),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Reports
                  _buildExpansionGroup(
                    title: 'Reports',
                    icon: Icons.analytics_outlined,
                    children: [
                      _buildDrawerItem(
                        icon: Icons.bar_chart,
                        title: 'GST Report',
                        isSmall: true,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  GstReportsScreen(storeId: widget.storeId),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 16),

                  _buildDrawerItem(
                    icon: Icons.manage_accounts_outlined,
                    title: 'Staff Management',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              StaffManagementScreen(storeId: widget.storeId),
                        ),
                      );
                    },
                  ),

                  _buildDrawerItem(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SettingsScreen(storeId: widget.storeId),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Logout
                  _buildDrawerItem(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    isDestructive: true,
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();
                      if (context.mounted) {
                        // Try to navigate to login if route exists, else confirm logout
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StoreSelectionScreen(),
                          ), // Fallback to store selection or login
                          (route) => false,
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              alignment: Alignment.center,
              child: Text(
                'Exanor Retail POS',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey[500],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildExpansionGroup({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          maintainState: true,
          dense: true,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey[800],
            ),
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.grey[700]),
          ),
          children: children,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    bool isDestructive = false,
    bool isSmall = false,
    bool isGroupHeaderStyle = false,
    Color? iconColor,
    Color? textColor,
  }) {
    final effectiveColor = isDestructive
        ? Colors.red
        : (isSelected ? Theme.of(context).primaryColor : Colors.grey[800]);

    final effectiveIconColor =
        iconColor ??
        (isDestructive
            ? Colors.red
            : (isSelected ? Theme.of(context).primaryColor : Colors.grey[700]));

    final bgColor = isSelected
        ? Theme.of(context).primaryColor.withOpacity(0.08)
        : Colors.transparent;

    final double leftMargin = isSmall ? 20 : 0;

    return Container(
      margin: EdgeInsets.only(bottom: 4, left: leftMargin),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isGroupHeaderStyle || (!isSmall && !isSelected))
                ? Colors.grey.shade50
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: isSmall ? 18 : 20, color: effectiveIconColor),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: isSmall ? 14 : 15,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: textColor ?? effectiveColor,
          ),
        ),
      ),
    );
  }
}
