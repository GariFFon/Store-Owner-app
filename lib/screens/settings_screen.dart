import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:exanor/models/store_bank_details.dart';
import 'package:exanor/models/financial_year.dart';
import 'dart:math' as math;

class SettingsScreen extends StatefulWidget {
  final String storeId;

  const SettingsScreen({super.key, required this.storeId});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Orders Tab State
  List<Map<String, dynamic>> _orderMethods = [];
  bool _isOrdersLoading = false;
  String? _ordersError;

  // Order Method Templates
  List<Map<String, dynamic>> _orderMethodTemplates = [];
  bool _isTemplatesLoading = false;

  // Payment Tab State
  List<Map<String, dynamic>> _paymentMethods = [];
  bool _isPaymentsLoading = false;
  String? _paymentsError;

  // Payment Method Templates
  List<Map<String, dynamic>> _paymentMethodTemplates = [];
  bool _isPaymentTemplatesLoading = false;

  // Notification Tab State
  Map<String, dynamic> _notificationSettings = {};
  bool _isNotificationsLoading = false;
  String? _notificationsError;

  // Payout Tab State
  List<StoreBankDetails> _payoutAccounts = [];
  List<FinancialYear> _financialYears = [];
  String? _selectedFinancialYearId;
  bool _isPayoutsLoading = false;
  String? _payoutsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(_handleTabSelection);
    // Initial fetch for default tab if needed, but usually rely on tab selection or explicit call
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _storeNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;

    switch (_tabController.index) {
      case 1: // ORDERS
        _fetchOrderMethods();
        break;
      case 2: // PAYMENTS
        _fetchPaymentMethods();
        break;
      case 3: // PAYOUTS
        _fetchPayoutAccounts();
        _fetchFinancialYears();
        break;
      case 5: // NOTIFICATIONS
        _fetchNotificationSettings();
        break;
    }
  }

  Future<void> _fetchOrderMethods() async {
    setState(() {
      _isOrdersLoading = true;
      _ordersError = null;
    });

    try {
      final response = await ApiService.post(
        '/order-method-settings/',
        body: {
          "view": true,
          "create": false,
          "order_method_creation_data": {},
          "store_id": widget.storeId,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['order_methods'] != null) {
          setState(() {
            _orderMethods = List<Map<String, dynamic>>.from(
              data['order_methods'],
            );
            _isOrdersLoading = false;
          });
        } else {
          setState(() => _isOrdersLoading = false);
        }
      } else {
        setState(() {
          _ordersError = 'Failed to load order methods';
          _isOrdersLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _ordersError = 'Error: $e';
        _isOrdersLoading = false;
      });
    }
  }

  Future<void> _fetchOrderMethodTemplates() async {
    setState(() => _isTemplatesLoading = true);
    try {
      final response = await ApiService.post(
        '/order-method-template/',
        body: {"query": {}, "store_id": widget.storeId},
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          setState(() {
            _orderMethodTemplates = List<Map<String, dynamic>>.from(
              data['response'],
            );
            _isTemplatesLoading = false;
          });
        } else {
          setState(() => _isTemplatesLoading = false);
        }
      } else {
        setState(() => _isTemplatesLoading = false);
      }
    } catch (e) {
      setState(() => _isTemplatesLoading = false);
    }
  }

  Future<void> _fetchPaymentMethods() async {
    setState(() {
      _isPaymentsLoading = true;
      _paymentsError = null;
    });

    try {
      final response = await ApiService.post(
        '/payment-method/',
        body: {
          "view": true,
          "store_id": widget.storeId,
          "query": {"is_enabled": true},
          "order_by": "id", // Keep consistent ordering
          "limit": 500,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          setState(() {
            _paymentMethods = List<Map<String, dynamic>>.from(data['response']);
            _isPaymentsLoading = false;
          });
        } else {
          setState(() => _isPaymentsLoading = false);
        }
      } else {
        setState(() {
          _paymentsError = 'Failed to load payment methods';
          _isPaymentsLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _paymentsError = 'Error: $e';
        _isPaymentsLoading = false;
      });
    }
  }

  Future<void> _fetchPaymentMethodTemplates() async {
    setState(() => _isPaymentTemplatesLoading = true);
    try {
      final response = await ApiService.post(
        '/payment-method-template/',
        body: {"store_id": widget.storeId},
        useBearerToken: true,
      );
      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          setState(() {
            _paymentMethodTemplates = List<Map<String, dynamic>>.from(
              data['response'],
            );
            _isPaymentTemplatesLoading = false;
          });
        } else {
          setState(() => _isPaymentTemplatesLoading = false);
        }
      } else {
        setState(() => _isPaymentTemplatesLoading = false);
      }
    } catch (e) {
      setState(() => _isPaymentTemplatesLoading = false);
    }
  }

  Future<void> _fetchNotificationSettings() async {
    setState(() {
      _isNotificationsLoading = true;
      _notificationsError = null;
    });

    try {
      final response = await ApiService.put(
        '/update-store-settings/',
        body: {
          "store_id": widget.storeId,
          "data_to_be_updated": {},
          "view": true,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['current_state'] != null) {
          setState(() {
            _notificationSettings = Map<String, dynamic>.from(
              data['current_state'],
            );
            _isNotificationsLoading = false;
          });
        } else {
          setState(() => _isNotificationsLoading = false);
        }
      } else {
        setState(() {
          _notificationsError = 'Failed to load settings';
          _isNotificationsLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _notificationsError = 'Error: $e';
        _isNotificationsLoading = false;
      });
    }
  }

  Future<void> _fetchFinancialYears() async {
    try {
      final response = await StoreOwnerApiService.getFinancialYears(
        widget.storeId,
        limit: 50,
      );
      if (response['response'] != null) {
        setState(() {
          _financialYears = (response['response'] as List)
              .map((e) => FinancialYear.fromJson(e))
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching financial years: $e');
    }
  }

  Future<void> _fetchPayoutAccounts() async {
    setState(() {
      _isPayoutsLoading = true;
      _payoutsError = null;
    });

    try {
      final accounts = await StoreOwnerApiService.getStoreBankDetails(
        widget.storeId,
        financialYearId: _selectedFinancialYearId,
      );
      setState(() {
        _payoutAccounts = accounts
            .map((e) => StoreBankDetails.fromJson(e))
            .toList();
        _isPayoutsLoading = false;
      });
    } catch (e) {
      setState(() {
        _payoutsError = 'Error: $e';
        _isPayoutsLoading = false;
      });
    }
  }

  // Logic Handlers
  Future<void> _updateOrderMethodStatus(String id, bool val) async {
    // Optimistic Update
    setState(() {
      final index = _orderMethods.indexWhere((e) => e['id'] == id);
      if (index != -1) _orderMethods[index]['is_enabled'] = val;
    });
    try {
      await ApiService.put(
        '/order-method-settings/',
        body: {
          "store_id": widget.storeId,
          "order_method_id": id,
          "data_to_be_updated": {"is_enabled": val},
        },
        useBearerToken: true,
      );
    } catch (e) {
      // Revert
      setState(() {
        final index = _orderMethods.indexWhere((e) => e['id'] == id);
        if (index != -1) _orderMethods[index]['is_enabled'] = !val;
      });
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<bool> _submitOrderMethod({
    required bool isEditing,
    String? orderMethodId,
    required String basePrice,
    String? templateId,
    required String chargesPerKm,
    required String chargesPerMin,
    required String minOrder,
    required String maxOrder,
    required String maxRange,
  }) async {
    Map<String, dynamic> dataToBeUpdated = {
      "base_price": double.tryParse(basePrice) ?? 0,
      "charges_per_km": double.tryParse(chargesPerKm) ?? 0,
      "charges_per_min": double.tryParse(chargesPerMin) ?? 0,
      "min_order_value": double.tryParse(minOrder) ?? 0,
      "max_order_value": double.tryParse(maxOrder) ?? 0,
      "max_delivery_range_in_km": double.tryParse(maxRange) ?? 0,
    };

    if (templateId != null) {
      dataToBeUpdated["order_method_template_id"] = templateId;
    }

    try {
      if (isEditing) {
        await ApiService.put(
          '/order-method-settings/',
          body: {
            "store_id": widget.storeId,
            "order_method_id": orderMethodId,
            "data_to_be_updated": dataToBeUpdated,
          },
          useBearerToken: true,
        );
      } else {
        if (templateId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a template name')),
          );
          return false;
        }

        final response = await ApiService.post(
          '/order-method-settings/',
          body: {
            "store_id": widget.storeId,
            "create": true,
            "view": false,
            "order_method_creation_data": {
              "base_price": double.tryParse(basePrice) ?? 0,
              "order_method_template_id": templateId,
              "charges_per_km": double.tryParse(chargesPerKm) ?? 0,
              "charges_per_min": double.tryParse(chargesPerMin) ?? 0,
              "min_order_value": double.tryParse(minOrder) ?? 0,
              "max_order_value": double.tryParse(maxOrder) ?? 0,
              "max_delivery_range_in_km": double.tryParse(maxRange) ?? 0,
            },
          },
          useBearerToken: true,
        );
        if (response['statusCode'] == 409) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  response['data']['response'] ?? 'Duplicate entry',
                ),
              ),
            );
          }
          return false;
        }
      }
      return true;
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      return false;
    }
  }

  Future<void> _updatePaymentMethodStatus(String id, bool val) async {
    setState(() {
      final index = _paymentMethods.indexWhere((e) => e['id'] == id);
      if (index != -1) _paymentMethods[index]['is_enabled'] = val;
    });

    try {
      final response = await ApiService.put(
        '/payment-method/',
        body: {
          "store_id": widget.storeId,
          "payment_method_id": id,
          "data_to_be_updated": {"is_enabled": val},
        },
        useBearerToken: true,
      );

      bool success = false;
      if (response['statusCode'] == 200 && response['data'] != null) {
        if (response['data']['status'] == 200) {
          success = true;
        }
      }

      if (!success) {
        setState(() {
          final index = _paymentMethods.indexWhere((e) => e['id'] == id);
          if (index != -1) _paymentMethods[index]['is_enabled'] = !val;
        });
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update status')),
          );
      }
    } catch (e) {
      setState(() {
        final index = _paymentMethods.indexWhere((e) => e['id'] == id);
        if (index != -1) _paymentMethods[index]['is_enabled'] = !val;
      });
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _updateNotificationSetting(String key, bool val) async {
    final oldVal = _notificationSettings[key];
    setState(() {
      _notificationSettings[key] = val;
    });

    try {
      await ApiService.put(
        '/update-store-settings/',
        body: {
          "store_id": widget.storeId,
          "data_to_be_updated": {key: val},
          "view": true,
        },
        useBearerToken: true,
      );
    } catch (e) {
      setState(() {
        _notificationSettings[key] = oldVal;
      });
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF2563EB); // Blue-600
    final lightBg = const Color(0xFFEFF6FF); // Blue-50
    final watermarkColor = const Color(0xFFDBEAFE); // Blue-100

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            // 1. Immersive Header
            _buildInteractiveBanner(primaryColor, lightBg, watermarkColor),

            // 2. Stylish Tabs
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: primaryColor,
                indicatorWeight: 3,
                labelColor: primaryColor,
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 0,
                ),
                tabs: const [
                  Tab(text: "GENERAL"),
                  Tab(text: "ORDERS"),
                  Tab(text: "PAYMENTS"),
                  Tab(text: "PAYOUTS"),
                  Tab(text: "SHIPPING"),
                  Tab(text: "ALERTS"),
                ],
              ),
            ),

            // 3. Content Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildContentWrapper(_buildGeneralTab()),
                  _buildContentWrapper(_buildOrdersTab()),
                  _buildContentWrapper(_buildPaymentsTab()),
                  _buildContentWrapper(_buildPayoutsTab()),
                  _buildContentWrapper(
                    _buildPlaceholderTab('Shipping configuration coming soon'),
                  ),
                  _buildContentWrapper(_buildNotificationsTab()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentWrapper(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: child,
    );
  }

  Widget _buildInteractiveBanner(Color primary, Color bg, Color watermark) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -20,
            child: Transform.rotate(
              angle: -math.pi / 6,
              child: Icon(
                Icons.settings_suggest_rounded,
                size: 200,
                color: watermark.withOpacity(0.8),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                              0.5,
                            ), // Semi-transparent white
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.blueGrey.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.only(right: 2),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.blueGrey,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Settings",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E293B), // Slate-800
                                letterSpacing: -0.5,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Configure Store Preferences",
                              style: TextStyle(
                                fontSize: 12,
                                color: primary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
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

  // --- TAB CONTENTS ---

  Widget _buildGeneralTab() {
    return Column(
      children: [
        _buildSectionHeader('Store Profile'),
        const SizedBox(height: 16),
        _buildCard(
          child: Column(
            children: [
              _buildModernInput(
                label: "Store Name",
                controller: _storeNameController,
                icon: Icons.store_rounded,
              ),
              const SizedBox(height: 20),
              _buildModernInput(
                label: "Phone Number",
                controller: _phoneController,
                icon: Icons.phone_rounded,
              ),
              const SizedBox(height: 20),
              _buildModernInput(
                label: "Email Address",
                controller: _emailController,
                icon: Icons.email_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {},
              child: const Text(
                "DISCARD",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "Save Changes",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOrdersTab() {
    if (_isOrdersLoading)
      return const Center(child: CircularProgressIndicator());
    if (_ordersError != null)
      return Center(
        child: Text(_ordersError!, style: const TextStyle(color: Colors.red)),
      );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Order Methods'),
            ElevatedButton.icon(
              onPressed: () => _showOrderMethodBottomSheet(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'New Method',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2563EB),
                elevation: 0,
                side: BorderSide(color: Colors.grey[200]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_orderMethods.isEmpty)
          _buildEmptyState("No order methods configured.")
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _orderMethods.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final method = _orderMethods[index];
              return _buildControlCard(
                title: method['order_method_name'] ?? 'Unknown',
                subtitle: method['is_enabled'] == true ? 'Active' : 'Inactive',
                value: method['is_enabled'] ?? false,
                onChanged: (val) => _updateOrderMethodStatus(method['id'], val),
                onEdit: () => _showOrderMethodBottomSheet(orderMethod: method),
                icon: Icons.local_shipping_rounded,
              );
            },
          ),
      ],
    );
  }

  Widget _buildPaymentsTab() {
    if (_isPaymentsLoading)
      return const Center(child: CircularProgressIndicator());
    if (_paymentsError != null)
      return Center(
        child: Text(_paymentsError!, style: const TextStyle(color: Colors.red)),
      );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Payment Gateways'),
            ElevatedButton.icon(
              onPressed: () => _showPaymentMethodBottomSheet(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'Add Gateway',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2563EB),
                elevation: 0,
                side: BorderSide(color: Colors.grey[200]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_paymentMethods.isEmpty)
          _buildEmptyState("No payment methods configured.")
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _paymentMethods.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final method = _paymentMethods[index];
              return _buildControlCard(
                title: method['payment_method_name'] ?? 'Unknown',
                subtitle:
                    method['levy_payment_gateway_charges_on_customer'] == true
                    ? 'Surcharge enabled'
                    : 'Standard',
                value: method['is_enabled'] ?? false,
                onChanged: (val) =>
                    _updatePaymentMethodStatus(method['id'], val),
                onEdit: () =>
                    _showPaymentMethodBottomSheet(paymentMethod: method),
                icon: Icons.payments_rounded,
                isPayment: true,
                imageUrl: method['img_url'],
              );
            },
          ),
      ],
    );
  }

  Widget _buildPayoutsTab() {
    if (_isPayoutsLoading)
      return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        _buildSectionHeader('Bank Accounts'),
        const SizedBox(height: 16),
        if (_payoutAccounts.isEmpty)
          _buildEmptyState("No bank accounts linked.")
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _payoutAccounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final account = _payoutAccounts[index];
              return _buildCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.bankName ?? 'Bank Account',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'XXXX-XXXX-${account.accountNumberOrUpiId.substring(math.max(0, account.accountNumberOrUpiId.length - 4))}',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            account.ifscCode ?? '',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 32),
        _buildSectionHeader('Financial Years'),
        const SizedBox(height: 16),
        if (_financialYears.isEmpty)
          const Text("No financial years found")
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _financialYears.map((fy) {
              return Chip(
                label: Text(fy.displayName),
                backgroundColor: const Color(0xFFF1F5F9),
                side: BorderSide.none,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildNotificationsTab() {
    if (_isNotificationsLoading)
      return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        _buildSectionHeader('Email Alerts'),
        const SizedBox(height: 16),
        _buildSwitchTile(
          "Order Confirmation",
          "Receive email when a new order is placed.",
          "send_email_after_order_placement",
          Icons.mark_email_read_rounded,
        ),
        const SizedBox(height: 12),
        _buildSwitchTile(
          "Inventory Alerts",
          "Get notified when stock is low.",
          "send_inventory_alert_via_email",
          Icons.inventory_2_rounded,
        ),

        const SizedBox(height: 32),
        _buildSectionHeader('System Preferences'),
        const SizedBox(height: 16),
        _buildSwitchTile(
          "Auto-Accept Orders",
          "Automatically confirm incoming orders.",
          "auto_accept_orders",
          Icons.verified_rounded,
        ),
      ],
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildModernInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: "Enter $label",
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlCard({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required VoidCallback onEdit,
    required IconData icon,
    bool isPayment = false,
    String? imageUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: value
              ? const Color(0xFF2563EB).withOpacity(0.2)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          if (isPayment && imageUrl != null)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: value
                    ? const Color(0xFF2563EB).withOpacity(0.1)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: value
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF94A3B8),
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: value
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_rounded, color: Colors.grey[400], size: 20),
            onPressed: onEdit,
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF2563EB),
              activeTrackColor: const Color(0xFFDBEAFE),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    String key,
    IconData icon,
  ) {
    final value = _notificationSettings[key] ?? false;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: value ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (val) => _updateNotificationSetting(key, val),
            activeColor: const Color(0xFF10B981),
            activeTrackColor: const Color(0xFFD1FAE5),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTab(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // --- BOTTOM SHEETS ---
  // (Re-using logic from original file but updated visually to match)

  Future<void> _showOrderMethodBottomSheet({
    Map<String, dynamic>? orderMethod,
  }) async {
    final isEditing = orderMethod != null;
    if (_orderMethodTemplates.isEmpty) await _fetchOrderMethodTemplates();
    if (!mounted) return;

    final basePriceController = TextEditingController(
      text: orderMethod?['base_price']?.toString() ?? '0',
    );
    final chargesPerKmController = TextEditingController(
      text: orderMethod?['charges_per_km']?.toString() ?? '0',
    );
    final chargesPerMinController = TextEditingController(
      text: orderMethod?['charges_per_min']?.toString() ?? '0',
    );
    final minOrderValueController = TextEditingController(
      text: orderMethod?['min_order_value']?.toString() ?? '0',
    );
    final maxOrderValueController = TextEditingController(
      text: orderMethod?['max_order_value']?.toString() ?? '500',
    );
    final maxDeliveryRangeController = TextEditingController(
      text: orderMethod?['max_delivery_range_in_km']?.toString() ?? '10',
    );
    String? selectedTemplateId = orderMethod?['order_method_template_id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // For custom styling
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isEditing ? 'Edit Order Method' : 'New Order Method',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildBottomSheetInput(
                    label: "Base Price",
                    controller: basePriceController,
                  ),
                  const SizedBox(height: 16),

                  // Template Dropdown
                  Text(
                    "Template",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedTemplateId,
                        isExpanded: true,
                        hint: Text(
                          "Select Template",
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                        items: _orderMethodTemplates
                            .map<DropdownMenuItem<String>>(
                              (t) => DropdownMenuItem(
                                value: t['id'],
                                child: Text(
                                  t['order_method_name'] ?? 'Unknown',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setSheetState(() => selectedTemplateId = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildBottomSheetInput(
                          label: "Cost / KM",
                          controller: chargesPerKmController,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildBottomSheetInput(
                          label: "Cost / Min",
                          controller: chargesPerMinController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBottomSheetInput(
                          label: "Min Order",
                          controller: minOrderValueController,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildBottomSheetInput(
                          label: "Max Order",
                          controller: maxOrderValueController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildBottomSheetInput(
                    label: "Max Range (KM)",
                    controller: maxDeliveryRangeController,
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        bool success = await _submitOrderMethod(
                          isEditing: isEditing,
                          orderMethodId: orderMethod?['id'],
                          basePrice: basePriceController.text,
                          templateId: selectedTemplateId,
                          chargesPerKm: chargesPerKmController.text,
                          chargesPerMin: chargesPerMinController.text,
                          minOrder: minOrderValueController.text,
                          maxOrder: maxOrderValueController.text,
                          maxRange: maxDeliveryRangeController.text,
                        );
                        if (success && mounted) {
                          Navigator.pop(context);
                          _fetchOrderMethods();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "SAVE METHOD",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showPaymentMethodBottomSheet({
    Map<String, dynamic>? paymentMethod,
  }) async {
    final isEditing = paymentMethod != null;
    if (_paymentMethodTemplates.isEmpty) await _fetchPaymentMethodTemplates();
    if (!mounted) return;

    String? selectedTemplateId = paymentMethod?['payment_method_template_id'];
    bool levyCharges =
        paymentMethod?['levy_payment_gateway_charges_on_customer'] ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isEditing ? 'Edit Payment Method' : 'New Payment Method',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: levyCharges,
                        onChanged: (v) =>
                            setSheetState(() => levyCharges = v ?? false),
                        activeColor: const Color(0xFF2563EB),
                        side: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Pass gateway charges to customer",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Template Dropdown
                Text(
                  "Payment Provider",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedTemplateId,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded),
                      hint: Text(
                        "Select Provider",
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                      items: _paymentMethodTemplates
                          .map<DropdownMenuItem<String>>(
                            (t) => DropdownMenuItem(
                              value: t['id'],
                              child: Text(
                                t['payment_method_name'] ?? 'Unknown',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: isEditing
                          ? null
                          : (val) =>
                                setSheetState(() => selectedTemplateId = val),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (selectedTemplateId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a payment provider'),
                          ),
                        );
                        return;
                      }

                      // Construct payload (simplified from original logic, assuming basic structure)
                      Map<String, dynamic> data = {
                        "levy_payment_gateway_charges_on_customer": levyCharges,
                      };
                      if (!isEditing) {
                        data["payment_method_template_id"] = selectedTemplateId;
                      }

                      // Using simplified API call logic to match _submitOrderMethod style
                      try {
                        if (isEditing) {
                          await ApiService.put(
                            '/payment-method/',
                            body: {
                              "store_id": widget.storeId,
                              "payment_method_id": paymentMethod?['id'],
                              "data_to_be_updated": data,
                            },
                            useBearerToken: true,
                          );
                        } else {
                          await ApiService.post(
                            '/payment-method/',
                            body: {
                              "store_id": widget.storeId,
                              "create": true,
                              "view": false,
                              "payment_method_creation_data": data,
                            },
                            useBearerToken: true,
                          );
                        }
                        if (mounted) {
                          Navigator.pop(context);
                          _fetchPaymentMethods();
                        }
                      } catch (e) {
                        if (mounted)
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "SAVE CONFIGURATION",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomSheetInput({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              hintText: "0",
              hintStyle: TextStyle(color: Colors.grey[400]),
            ),
          ),
        ),
      ],
    );
  }
}
