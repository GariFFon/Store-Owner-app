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

  // Constants
  final List<String> _accountTypes = [
    'Savings Bank Account',
    'Current Account',
    'Cash Account',
    'BHIM UPI',
    'PayTM UPI',
    'PhonePe UPI',
    'Google Pay UPI',
    'Amazon Pay UPI',
    'Other Payment Methods',
  ];
  final List<String> _holderTypes = ['Individual', 'Company'];

  // Tab State
  String _activeTab = 'General';

  @override
  void initState() {
    super.initState();
    // Initial fetch
    _onTabChanged('General');
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _onTabChanged(String tab) {
    setState(() => _activeTab = tab);

    switch (tab) {
      case 'Orders':
        _fetchOrderMethods();
        break;
      case 'Payments':
        _fetchPaymentMethods();
        break;
      case 'Payouts':
        _fetchPayoutAccounts();
        _fetchFinancialYears();
        break;
      case 'Alerts':
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
        financialYearId: _selectedFinancialYearId == 'all'
            ? null
            : _selectedFinancialYearId,
      );
      setState(() {
        _payoutAccounts = accounts
            .map((e) => StoreBankDetails.fromJson(e))
            .toList();
        _isPayoutsLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _payoutsError = 'Error: $e';
          _isPayoutsLoading = false;
        });
      }
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
            _buildInteractiveBannerNew(primaryColor, lightBg, watermarkColor),

            // 2. Content Body
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _onTabChanged(_activeTab),
                child: CustomScrollView(
                  slivers: [
                    // Tab Peel
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                        child: _buildFilterSegments(primaryColor),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Content
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverToBoxAdapter(
                        child: _buildActiveTabContent(),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 'General':
        return _buildGeneralTab();
      case 'Orders':
        return _buildOrdersTab();
      case 'Payments':
        return _buildPaymentsTab();
      case 'Payouts':
        return _buildPayoutsTab();
      case 'Shipping':
        return _buildPlaceholderTab('Shipping configuration coming soon');
      case 'Alerts':
        return _buildNotificationsTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildInteractiveBannerNew(Color primary, Color bg, Color watermark) {
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

  // --- Filter Chips ---

  Widget _buildFilterSegments(Color primary) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip("General", "General", primary),
          const SizedBox(width: 10),
          _buildFilterChip("Orders", "Orders", primary),
          const SizedBox(width: 10),
          _buildFilterChip("Payments", "Payments", primary),
          const SizedBox(width: 10),
          _buildFilterChip("Payouts", "Payouts", primary),
          const SizedBox(width: 10),
          _buildFilterChip("Shipping", "Shipping", primary),
          const SizedBox(width: 10),
          _buildFilterChip("Alerts", "Alerts", primary),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String tabId, Color color) {
    final isActive = _activeTab == tabId;
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: (_) => _onTabChanged(tabId),
      backgroundColor: Colors.white,
      selectedColor: color.withOpacity(0.1),
      labelStyle: TextStyle(
        color: isActive ? color : Colors.grey[600],
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isActive ? color.withOpacity(0.3) : Colors.grey[200]!,
        ),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      visualDensity: VisualDensity.compact,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Store Images Section
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Store Logo",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_rounded,
                                  color: Colors.blue[300],
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Update Logo",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Store Banner",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Transform(
                                  transform: Matrix4.rotationZ(-0.1),
                                  child: Icon(
                                    Icons.image_rounded,
                                    color: Colors.indigo[300],
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

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
    if (_payoutsError != null)
      return Center(
        child: Text(_payoutsError!, style: const TextStyle(color: Colors.red)),
      );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Payout Accounts'),
            ElevatedButton.icon(
              onPressed: () => _showPayoutAccountBottomSheet(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text(
                'Add Account',
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

        // Financial Year Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFinancialYearId ?? 'all',
              isExpanded: true,
              hint: const Text("Filter by Financial Year"),
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text(
                    "All Accounts (No FY Filter)",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ..._financialYears.map((fy) {
                  return DropdownMenuItem(
                    value: fy.id,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          fy.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (fy.isCurrentFy)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green[100]!),
                            ),
                            child: const Text(
                              "Active",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() => _selectedFinancialYearId = val);
                _fetchPayoutAccounts();
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        if (_payoutAccounts.isEmpty)
          _buildEmptyState("No payout accounts found.")
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _payoutAccounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final account = _payoutAccounts[index];
              final isCash =
                  account.bankName?.toUpperCase().contains('CASH') == true ||
                  account.id == 'cash';

              return _buildCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isCash
                                ? Colors.amber[50]
                                : Colors.indigo[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isCash
                                ? Icons.payments_rounded
                                : Icons.account_balance_rounded,
                            color: isCash ? Colors.amber[700] : Colors.indigo,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.bankName ??
                                    (isCash ? 'CASH' : 'Bank Account'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isCash
                                    ? 'Cash Account'
                                    : account.accountTypeChoices.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.edit_rounded,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          onPressed: () =>
                              _showPayoutAccountBottomSheet(account: account),
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 0.5),
                    _buildDetailRow(
                      "Account Number",
                      account.accountNumberOrUpiId,
                    ),
                    if (!isCash) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow("IFSC Code", account.ifscCode ?? '-'),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        "Account Holder",
                        account.accountHolderName,
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        "Holder Type",
                        account.accountHolderType.toUpperCase(),
                        isBadge: true,
                      ),
                    ],
                    if (account.isDefault) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.green[100]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Colors.green,
                            ),
                            SizedBox(width: 4),
                            Text(
                              "Default Account",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBadge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationsTab() {
    if (_isNotificationsLoading)
      return const Center(child: CircularProgressIndicator());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Online Ordering Group
        _buildNotificationGroup(
          title: 'ONLINE ORDERING',
          icon: Icons.shopping_cart_rounded,
          color: const Color(0xFF3B82F6), // Blue
          children: [
            _buildModernSwitchTile(
              title: "Accept Web Orders",
              subtitle: "Allow customers to order from your website",
              icon: Icons.language_rounded,
              iconColor: const Color(0xFF3B82F6),
              settingsKey: "is_accepting_web_orders",
            ),
            _buildTileDivider(),
            _buildModernSwitchTile(
              title: "Accept POS Orders",
              subtitle: "Allow creating orders from Point of Sale",
              icon: Icons.point_of_sale_rounded,
              iconColor: const Color(0xFF8B5CF6),
              settingsKey: "is_accepting_pos_orders",
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Branding & Marketing Group
        _buildNotificationGroup(
          title: 'BRANDING & MARKETING',
          icon: Icons.campaign_rounded,
          color: const Color(0xFFF59E0B), // Amber
          children: [
            _buildModernSwitchTile(
              title: "Branded Invoices",
              subtitle: "Use your store logo on invoices",
              icon: Icons.receipt_long_rounded,
              iconColor: const Color(0xFF10B981),
              settingsKey: "enable_branded_invoice",
            ),
            _buildTileDivider(),
            _buildModernSwitchTile(
              title: "Marketing Materials",
              subtitle: "Enable branded marketing content",
              icon: Icons.campaign_rounded,
              iconColor: const Color(0xFFF59E0B),
              settingsKey: "enable_branded_marketing_materials",
            ),
            _buildTileDivider(),
            _buildModernSwitchTile(
              title: "Sponsored Listings",
              subtitle: "Boost visibility as a sponsored store",
              icon: Icons.auto_awesome_rounded,
              iconColor: const Color(0xFFEC4899),
              settingsKey: "is_sponsored",
            ),
            _buildTileDivider(),
            _buildModernSwitchTile(
              title: "Featured Store",
              subtitle: "Mark store as featured in listings",
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFEAB308),
              settingsKey: "is_featured",
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Communication Group
        _buildNotificationGroup(
          title: 'COMMUNICATION',
          icon: Icons.notifications_active_rounded,
          color: const Color(0xFF10B981), // Emerald
          children: [
            _buildModernSwitchTile(
              title: "Send Invoice via Email",
              subtitle: "Automatically email invoices to customers",
              icon: Icons.email_outlined,
              iconColor: const Color(0xFF6366F1),
              settingsKey: "send_invoice_in_email",
            ),
            _buildTileDivider(),
            _buildModernSwitchTile(
              title: "Send Invoice via SMS",
              subtitle: "Send invoice link via SMS",
              icon: Icons.sms_rounded,
              iconColor: const Color(0xFF06B6D4),
              settingsKey: "send_invoice_in_sms",
            ),
            _buildTileDivider(),
            _buildModernSwitchTile(
              title: "Push Notifications",
              subtitle: "Send order updates via app notifications",
              icon: Icons.notifications_active_rounded,
              iconColor: const Color(0xFFEF4444),
              settingsKey: "send_invoice_in_push_notification",
            ),
          ],
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  /// Build a notification settings group with header
  Widget _buildNotificationGroup({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group Header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        // Group Card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  /// Modern switch tile for grouped notifications
  Widget _buildModernSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String settingsKey,
  }) {
    final value = _notificationSettings[settingsKey] ?? false;

    return InkWell(
      onTap: () => _updateNotificationSetting(settingsKey, !value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Icon Container with colored background
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            // Toggle Switch
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: value,
                onChanged: (val) =>
                    _updateNotificationSetting(settingsKey, val),
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFF10B981),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFE2E8F0),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Divider for notification tiles
  Widget _buildTileDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 70, // Align with text start (after icon)
      endIndent: 16,
      color: const Color(0xFFF1F5F9),
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

  Future<void> _showPayoutAccountBottomSheet({
    StoreBankDetails? account,
  }) async {
    final isEditing = account != null;
    if (!mounted) return;

    final bankNameController = TextEditingController(
      text: account?.bankName ?? '',
    );
    final accountNumberController = TextEditingController(
      text: account?.accountNumberOrUpiId ?? '',
    );
    final ifscCodeController = TextEditingController(
      text: account?.ifscCode ?? '',
    );
    final holderNameController = TextEditingController(
      text: account?.accountHolderName ?? '',
    );
    final addressController = TextEditingController(
      text: account?.accountHolderAddress ?? '',
    );
    final cityController = TextEditingController(
      text: account?.accountHolderCity ?? '',
    );
    final stateController = TextEditingController(
      text: account?.accountHolderState ?? '',
    );
    final countryController = TextEditingController(
      text: account?.accountHolderCountry ?? 'India',
    );
    final openingBalanceController = TextEditingController(
      text: account?.openingBalance?.toString() ?? '',
    );

    String? selectedSheetFinancialYearId;

    // Default values

    String selectedAccountType = 'Savings Bank Account';
    if (account != null) {
      final type = account.accountTypeChoices.toLowerCase();
      if (type.contains('savings')) {
        selectedAccountType = 'Savings Bank Account';
      } else if (type.contains('current')) {
        selectedAccountType = 'Current Account';
      } else if (type.contains('cash')) {
        selectedAccountType = 'Cash Account';
      } else {
        selectedAccountType = _accountTypes.firstWhere(
          (t) => t.toLowerCase() == type,
          orElse: () => 'Savings Bank Account', // Default fallback
        );
      }
    }

    // Ensure selection is valid
    if (!_accountTypes.contains(selectedAccountType)) {
      selectedAccountType = 'Savings Bank Account';
    }

    String selectedHolderType = account != null
        ? (account.accountHolderType.isNotEmpty
              ? account.accountHolderType[0].toUpperCase() +
                    account.accountHolderType.substring(1).toLowerCase()
              : 'Individual')
        : 'Individual';

    bool isDefault = account?.isDefault ?? false;
    bool isActive = account?.isActive ?? true;

    if (!_holderTypes.contains(selectedHolderType)) {
      selectedHolderType = 'Individual';
    }

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
                    isEditing
                        ? 'Edit Payout Account'
                        : 'Add New Payout Account',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildDropdownInput(
                    label: "Account Type",
                    value: selectedAccountType,
                    items: _accountTypes,
                    onChanged: (val) =>
                        setSheetState(() => selectedAccountType = val!),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildBottomSheetInput(
                          label: "Bank Name",
                          controller: bankNameController,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildBottomSheetInput(
                          label: "Account Number",
                          controller: accountNumberController,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildBottomSheetInput(
                          label: "IFSC Code",
                          controller: ifscCodeController,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildBottomSheetInput(
                          label: "Account Holder Name",
                          controller: holderNameController,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownInput(
                          label: "Holder Type",
                          value: selectedHolderType,
                          items: _holderTypes,
                          onChanged: (val) =>
                              setSheetState(() => selectedHolderType = val!),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildBottomSheetInput(
                          label: "City",
                          controller: cityController,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Financial Year (Optional)",
                        style: TextStyle(
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
                            value: selectedSheetFinancialYearId,
                            isExpanded: true,
                            hint: Text(
                              "Select Financial Year",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                            ),
                            items: _financialYears.map((fy) {
                              return DropdownMenuItem(
                                value: fy.id,
                                child: Text(fy.displayName),
                              );
                            }).toList(),
                            onChanged: (val) => setSheetState(
                              () => selectedSheetFinancialYearId = val,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildBottomSheetInput(
                    label: "Opening Balance (Optional)",
                    controller: openingBalanceController,
                  ),

                  const SizedBox(height: 16),
                  _buildBottomSheetInput(
                    label: "Address",
                    controller: addressController,
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildBottomSheetInput(
                          label: "State",
                          controller: stateController,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildBottomSheetInput(
                          label: "Country",
                          controller: countryController,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  // Toggles
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Set as Default",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "Use this account for all payouts by default",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: isDefault,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (val) =>
                                  setSheetState(() => isDefault = val),
                            ),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Active",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "Enable this account for payouts",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: isActive,
                              activeColor: const Color(0xFF2563EB),
                              onChanged: (val) =>
                                  setSheetState(() => isActive = val),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Basic Validation
                        if (bankNameController.text.isEmpty ||
                            accountNumberController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill mandatory fields'),
                            ),
                          );
                          return;
                        }

                        final success = isEditing
                            ? await StoreOwnerApiService.updateStoreBankDetails(
                                storeId: widget.storeId,
                                bankDetailsId: account.id,
                                accountType: selectedAccountType,
                                bankName: bankNameController.text,
                                accountNumber: accountNumberController.text,
                                ifscCode: ifscCodeController.text,
                                holderName: holderNameController.text,
                                holderType: selectedHolderType,
                                city: cityController.text,
                                address: addressController.text,
                                state: stateController.text,
                                country: countryController.text,
                                isDefault: isDefault,
                                isActive: isActive,
                                financialYearId: selectedSheetFinancialYearId,
                                openingBalance: double.tryParse(
                                  openingBalanceController.text,
                                ),
                              )
                            : await StoreOwnerApiService.createStoreBankDetails(
                                storeId: widget.storeId,
                                accountType: selectedAccountType,
                                bankName: bankNameController.text,
                                accountNumber: accountNumberController.text,
                                ifscCode: ifscCodeController.text,
                                holderName: holderNameController.text,
                                holderType: selectedHolderType,
                                city: cityController.text,
                                address: addressController.text,
                                state: stateController.text,
                                country: countryController.text,
                                isDefault: isDefault,
                                isActive: isActive,
                                financialYearId: selectedSheetFinancialYearId,
                                openingBalance: double.tryParse(
                                  openingBalanceController.text,
                                ),
                              );

                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEditing
                                    ? 'Account Updated'
                                    : 'Account Created',
                              ),
                            ),
                          );
                          Navigator.pop(context);
                          _fetchPayoutAccounts();
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Operation Failed. Please try again.',
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isEditing ? "UPDATE ACCOUNT" : "CREATE ACCOUNT",
                        style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildDropdownInput({
    required String label,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
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
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              hintText: "Enter value",
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
