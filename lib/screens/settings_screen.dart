import 'package:flutter/material.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:exanor/models/store_bank_details.dart';
import 'package:exanor/models/financial_year.dart';

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
    if (_tabController.index == 1 && !_tabController.indexIsChanging) {
      // 1 is the index for 'ORDERS' tab
      _fetchOrderMethods();
    } else if (_tabController.index == 2 && !_tabController.indexIsChanging) {
      // 2 is the index for 'PAYMENTS' tab
      _fetchPaymentMethods();
    } else if (_tabController.index == 5 && !_tabController.indexIsChanging) {
      // 5 is the index for 'NOTIFICATIONS' tab
      _fetchNotificationSettings();
    } else if (_tabController.index == 3 && !_tabController.indexIsChanging) {
      // 3 is the index for 'PAYOUTS' tab
      _fetchPayoutAccounts();
      _fetchFinancialYears();
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
          setState(() {
            // Handle case where status is not 200 but request succeeded
            _isOrdersLoading = false;
          });
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
    setState(() {
      _isTemplatesLoading = true;
    });

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
      print('Error fetching templates: $e');
      setState(() => _isTemplatesLoading = false);
    }
  }

  Future<void> _showOrderMethodBottomSheet({
    Map<String, dynamic>? orderMethod,
  }) async {
    // Determine if we are editing or adding
    final isEditing = orderMethod != null;

    // Fetch templates if needed
    if (_orderMethodTemplates.isEmpty) {
      await _fetchOrderMethodTemplates();
    }

    if (!mounted) return;

    // Controllers
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
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Edit Order Method' : 'Add Order Method',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildBottomSheetInput(
                      label: 'Base Price',
                      controller: basePriceController,
                    ),
                    const SizedBox(height: 16),

                    // Template Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedTemplateId,
                          isExpanded: true,
                          hint: const Text('Order Method Template'),
                          items: _orderMethodTemplates.map((template) {
                            return DropdownMenuItem<String>(
                              value: template['id'],
                              child: Text(
                                template['order_method_name'] ?? 'Unknown',
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setSheetState(() {
                              selectedTemplateId = val;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildBottomSheetInput(
                      label: 'Charges Per KM',
                      controller: chargesPerKmController,
                    ),
                    const SizedBox(height: 16),

                    _buildBottomSheetInput(
                      label: 'Charges Per Minute',
                      controller: chargesPerMinController,
                    ),
                    const SizedBox(height: 16),

                    _buildBottomSheetInput(
                      label: 'Min Order Value',
                      controller: minOrderValueController,
                    ),
                    const SizedBox(height: 16),

                    _buildBottomSheetInput(
                      label: 'Max Order Value',
                      controller: maxOrderValueController,
                    ),
                    const SizedBox(height: 16),

                    _buildBottomSheetInput(
                      label: 'Max Delivery Range (KM)',
                      controller: maxDeliveryRangeController,
                    ),
                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'CANCEL',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () async {
                            // Handle Submit
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
                              _fetchOrderMethods(); // Refresh list
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            minimumSize: const Size(100, 48),
                          ),
                          child: const Text(
                            'SUBMIT',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomSheetInput({
    required String label,
    required TextEditingController controller,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateOrderMethodStatus(
    String orderMethodId,
    bool isEnabled,
  ) async {
    // Optimistic Update
    setState(() {
      final index = _orderMethods.indexWhere(
        (element) => element['id'] == orderMethodId,
      );
      if (index != -1) {
        _orderMethods[index]['is_enabled'] = isEnabled;
      }
    });

    try {
      await ApiService.put(
        '/order-method-settings/',
        body: {
          "store_id": widget.storeId,
          "order_method_id": orderMethodId,
          "data_to_be_updated": {"is_enabled": isEnabled},
        },
        useBearerToken: true,
      );
    } catch (e) {
      // Revert on failure
      setState(() {
        final index = _orderMethods.indexWhere(
          (element) => element['id'] == orderMethodId,
        );
        if (index != -1) {
          _orderMethods[index]['is_enabled'] = !isEnabled;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
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
        // Creation Logic
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
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Duplicate Order Method'),
                content: Text(
                  response['data']['response'] ??
                      'Order method with this template already exists.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return false; // Exit so we don't close the sheet if error
        }
      }
      return true; // Success
    } catch (e) {
      print('Error submitting order method: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
      return false; // Exit on error
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
        // Check for nested response or direct current_state
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

  Future<void> _updateNotificationSetting(String key, bool value) async {
    // Optimistic Update
    final previousValue = _notificationSettings[key];
    setState(() {
      _notificationSettings[key] = value;
    });

    try {
      final response = await ApiService.put(
        '/update-store-settings/',
        body: {
          "store_id": widget.storeId,
          "data_to_be_updated": {key: value},
          "view": true,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 &&
          response['data'] != null &&
          response['data']['current_state'] != null) {
        setState(() {
          _notificationSettings = Map<String, dynamic>.from(
            response['data']['current_state'],
          );
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Store system settings updated successfully.'),
            ),
          );
        }
      } else {
        throw Exception('Failed to update');
      }
    } catch (e) {
      // Revert
      setState(() {
        _notificationSettings[key] = previousValue;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating: $e')));
      }
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
    if (_isPayoutsLoading) return;
    setState(() {
      _isPayoutsLoading = true;
      _payoutsError = null;
    });

    try {
      final accounts = await StoreOwnerApiService.getStoreBankDetails(
        widget.storeId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const TranslatedText('Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage your store settings and preferences',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),

              // Divider
              Divider(height: 1, color: Colors.grey[300]),

              // Tabs
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Colors.blue,
                  indicatorWeight: 3,
                  labelPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Text('GENERAL'),
                    Text('ORDERS'),
                    Text('PAYMENTS'),
                    Text('PAYOUTS'),
                    Text('SHIPPING'),
                    Text('NOTIFICATIONS'),
                  ],
                  onTap: (index) {
                    if (index == 1) {
                      _fetchOrderMethods();
                    } else if (index == 2) {
                      _fetchPaymentMethods();
                    }
                  },
                ),
              ),

              const SizedBox(height: 32),

              // Tab Content
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return IndexedStack(
                    index: _tabController.index,
                    children: [
                      _buildGeneralTab(),
                      _buildOrdersTab(),
                      _buildPaymentsTab(),
                      _buildPayoutsTab(),
                      _buildPlaceholderTab('Shipping'),
                      _buildNotificationsTab(),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(String title) {
    return Center(child: Text('Content for $title'));
  }

  Widget _buildGeneralTab() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Profile Section Title
          _buildSectionHeader(
            title: 'Store profile',
            description: 'Update your store profile and information here',
          ),
          const SizedBox(height: 24),
          Divider(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 24),

          // Store Name
          _buildInputRow(
            label: 'Store Name',
            description: 'Update your store name here',
            child: TextFormField(
              controller: _storeNameController,
              decoration: const InputDecoration(
                hintText: 'Store name',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          _buildDivider(),

          // Store Logo
          _buildInputRow(
            label: 'Store Logo',
            description: 'Update your store Logo here',
            child: Row(
              children: [
                _buildAvatarPlaceholder(),
                const SizedBox(width: 16),
                _buildUploadButton(),
                const SizedBox(width: 16),
                const Text(
                  'No file chosen',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          _buildDivider(),

          // Store Banner
          _buildInputRow(
            label: 'Store Banner',
            description: 'Update your store banner here',
            child: Row(
              children: [
                _buildAvatarPlaceholder(),
                const SizedBox(width: 16),
                _buildUploadButton(),
                const SizedBox(width: 16),
                const Text(
                  'No file chosen',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          _buildDivider(),

          // Contact Information
          _buildInputRow(
            label: 'Contact Information',
            description: 'Update your contact details here',
            child: TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                hintText: 'Phone Number',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          _buildDivider(),

          // Email Information
          _buildInputRow(
            label: 'Email Information',
            description: 'Update your email address here',
            child: TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                hintText: 'Email',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  side: const BorderSide(color: Colors.blue),
                ),
                child: const Text(
                  'CANCEL',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2), // Blue color
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  'SAVE CHANGES',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    if (_isOrdersLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_ordersError != null) {
      return Center(
        child: Column(
          children: [
            Text(_ordersError!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _fetchOrderMethods,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Tab Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildSectionHeader(
                title: 'Order settings',
                description: 'Manage order methods and their settings',
              ),
            ),
            OutlinedButton(
              onPressed: () {
                _showOrderMethodBottomSheet(); // Open for adding
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                side: const BorderSide(color: Colors.blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                '+ ADD ORDER METHOD',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Divider(height: 1, color: Colors.grey[200]),

        // Order Methods List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _orderMethods.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, color: Colors.grey[200]),
          itemBuilder: (context, index) {
            final method = _orderMethods[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          method['order_method_name'] ?? 'Unknown Method',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '(charges apply)', // Static for now as per image or could be dynamic
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: method['is_enabled'] ?? false,
                    onChanged: (val) {
                      _updateOrderMethodStatus(method['id'], val);
                    },
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF1976D2),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Enabled', // Or Disabled based on state, but image shows Enabled next to toggle
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(width: 24),
                  TextButton(
                    onPressed: () {
                      _showOrderMethodBottomSheet(orderMethod: method);
                    },
                    child: const Text(
                      'EDIT',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Divider(height: 1, color: Colors.grey[200]),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildInputRow({
    required String label,
    required String description,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive layout: on wide screens, side-by-side. On narrow, stacked.
          if (constraints.maxWidth > 600) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: _buildSectionHeader(
                    title: label,
                    description: description,
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(flex: 6, child: child),
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(title: label, description: description),
                const SizedBox(height: 16),
                child,
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.grey[200]);
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Colors.grey,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: Colors.white),
    );
  }

  Widget _buildUploadButton() {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: const BorderSide(color: Colors.blue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: const Text(
        'UPLOAD',
        style: TextStyle(
          color: Colors.blue,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
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
          "order_by": "id",
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
          setState(() {
            _isPaymentsLoading = false;
          });
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
    setState(() {
      _isPaymentTemplatesLoading = true;
    });

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
      print('Error fetching payment templates: $e');
      setState(() => _isPaymentTemplatesLoading = false);
    }
  }

  Widget _buildPaymentsTab() {
    if (_isPaymentsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_paymentsError != null) {
      return Center(
        child: Column(
          children: [
            Text(_paymentsError!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _fetchPaymentMethods,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Tab Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: _buildSectionHeader(
                title: 'Payment settings',
                description: 'Update your payment methods here',
              ),
            ),
            OutlinedButton(
              onPressed: () {
                _showPaymentMethodBottomSheet();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                side: const BorderSide(color: Colors.blue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                '+ ADD PAYMENT METHOD',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Divider(height: 1, color: Colors.grey[300]),
        const SizedBox(height: 24),

        Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payment Methods',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose your payment methods (charges apply)',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // List of Payment Methods
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _paymentMethods.length,
          separatorBuilder: (context, index) =>
              Divider(color: Colors.grey[200]),
          itemBuilder: (context, index) {
            final method = _paymentMethods[index];
            final imgUrl = method['img_url'];
            final isEnabled = method['is_enabled'] ?? false;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  // Toggle
                  Switch(
                    value: isEnabled,
                    onChanged: (val) {
                      _updatePaymentMethodStatus(method['id'], val);
                    },
                    activeColor: Colors.white,
                    activeTrackColor: Colors.blue,
                  ),
                  const SizedBox(width: 16),

                  // Icon/Image
                  if (imgUrl != null)
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                        image: DecorationImage(
                          image: NetworkImage(imgUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.payment, color: Colors.grey),
                    ),

                  const SizedBox(width: 16),

                  // Name
                  Expanded(
                    child: Text(
                      method['payment_method_name'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  // Edit Button
                  TextButton(
                    onPressed: () {
                      _showPaymentMethodBottomSheet(paymentMethod: method);
                    },
                    child: const Text('EDIT'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _updatePaymentMethodStatus(String id, bool isEnabled) async {
    // Optimistic Update
    setState(() {
      final index = _paymentMethods.indexWhere(
        (element) => element['id'] == id,
      );
      if (index != -1) {
        _paymentMethods[index]['is_enabled'] = isEnabled;
      }
    });

    try {
      final response = await ApiService.put(
        '/payment-method/',
        body: {
          "store_id": widget.storeId,
          "payment_method_id": id,
          "data_to_be_updated": {"is_enabled": isEnabled},
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
        // Revert on failure response
        setState(() {
          final index = _paymentMethods.indexWhere(
            (element) => element['id'] == id,
          );
          if (index != -1) {
            _paymentMethods[index]['is_enabled'] = !isEnabled;
          }
        });

        if (mounted) {
          String errorMessage = 'Failed to update status';
          if (response['data'] != null &&
              response['data']['response'] != null) {
            errorMessage = response['data']['response'].toString();
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage)));
        }
      }
    } catch (e) {
      // Revert on exception
      setState(() {
        final index = _paymentMethods.indexWhere(
          (element) => element['id'] == id,
        );
        if (index != -1) {
          _paymentMethods[index]['is_enabled'] = !isEnabled;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
    }
  }

  Future<void> _showPaymentMethodBottomSheet({
    Map<String, dynamic>? paymentMethod,
  }) async {
    final isEditing = paymentMethod != null;

    // Fetch templates if not already loaded
    if (_paymentMethodTemplates.isEmpty) {
      await _fetchPaymentMethodTemplates();
    }

    if (!mounted) return;

    String? selectedTemplateId = paymentMethod?['payment_method_template_id'];
    bool levyCharges =
        paymentMethod?['levy_payment_gateway_charges_on_customer'] ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Edit Payment Method' : 'Add Payment Method',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Levy Charges Checkbox
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: levyCharges,
                          onChanged: (val) {
                            setSheetState(() {
                              levyCharges = val ?? false;
                            });
                          },
                          side: const BorderSide(color: Colors.grey, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Flexible(
                        child: Text(
                          'Levy payment gateway charges on customer',
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (_isPaymentTemplatesLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Payment Method Template',
                        labelStyle: TextStyle(color: Colors.blue[700]),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.blue[700]!,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedTemplateId,
                          isExpanded: true,
                          hint: const Text('Select a template'),
                          icon: const Icon(Icons.arrow_drop_down),
                          items: _paymentMethodTemplates.map((template) {
                            return DropdownMenuItem<String>(
                              value: template['id'],
                              child: Text(
                                template['payment_method_name'] ?? 'Unknown',
                              ),
                            );
                          }).toList(),
                          onChanged: isEditing
                              ? null
                              : (val) {
                                  setSheetState(() {
                                    selectedTemplateId = val;
                                  });
                                },
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () async {
                          if (selectedTemplateId == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a template'),
                              ),
                            );
                            return;
                          }
                          bool success = await _submitPaymentMethod(
                            context: context,
                            isEditing: isEditing,
                            paymentMethodId: paymentMethod?['id'],
                            templateId: selectedTemplateId!,
                            levyCharges: levyCharges,
                          );

                          if (success && mounted) {
                            Navigator.pop(context);
                            _fetchPaymentMethods();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                        ),
                        child: const Text(
                          'SUBMIT',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<bool> _submitPaymentMethod({
    required BuildContext context,
    required bool isEditing,
    String? paymentMethodId,
    required String templateId,
    required bool levyCharges,
  }) async {
    try {
      if (isEditing) {
        final response = await ApiService.put(
          '/payment-method/',
          body: {
            "store_id": widget.storeId,
            "payment_method_id": paymentMethodId,
            "payment_method_creation_data": {
              "payment_method_template_id": templateId,
              "levy_payment_gateway_charges_on_customer": levyCharges,
            },
          },
          useBearerToken: true,
        );

        if (response['statusCode'] == 200) {
          final data = response['data'];
          if (data['status'] == 200) {
            return true;
          } else if (data['status'] == 403) {
            if (mounted) {
              showDialog(
                context: context,
                useRootNavigator: true,
                builder: (context) => AlertDialog(
                  title: const Text('Permission Denied'),
                  content: Text(data['response'] ?? 'Permission denied'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
            return false;
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(data['response'] ?? 'Failed to update')),
              );
            }
            return false;
          }
        } else if (response['statusCode'] == 403) {
          if (mounted) {
            showDialog(
              context: context,
              useRootNavigator: true,
              builder: (context) => AlertDialog(
                title: const Text('Permission Denied'),
                content: Text(
                  response['data']?['response'] ?? 'Permission denied',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return false;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error: ${response['data']?['response'] ?? 'Unknown error'}',
                ),
              ),
            );
          }
          return false;
        }
      } else {
        final response = await ApiService.post(
          '/payment-method/',
          body: {
            "store_id": widget.storeId,
            "create": true,
            "view": false,
            "payment_method_creation_data": {
              "payment_method_template_id": templateId,
              "is_enabled": true,
              "levy_payment_gateway_charges_on_customer": levyCharges,
            },
          },
          useBearerToken: true,
        );

        if (response['statusCode'] == 409) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Duplicate Payment Method'),
                content: const Text('Payment Method Already exists'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
          return false;
        } else if (response['statusCode'] == 200 ||
            response['statusCode'] == 201) {
          return true;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error: ${response['data']?['response'] ?? 'Unknown error'}',
                ),
              ),
            );
          }
          return false;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
      return false;
    }
  }

  Widget _buildNotificationsTab() {
    if (_isNotificationsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notificationsError != null) {
      return Center(
        child: Column(
          children: [
            Text(
              _notificationsError!,
              style: const TextStyle(color: Colors.red),
            ),
            ElevatedButton(
              onPressed: _fetchNotificationSettings,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Define the list of settings to display
    final settingsList = [
      {'key': 'is_accepting_web_orders', 'title': 'Is Accepting Web Orders'},
      {'key': 'is_accepting_pos_orders', 'title': 'Is Accepting Pos Orders'},
      {'key': 'enable_branded_invoice', 'title': 'Enable Branded Invoice'},
      {
        'key': 'enable_branded_marketing_materials',
        'title': 'Enable Branded Marketing Materials',
      },
      {'key': 'send_invoice_in_email', 'title': 'Send Invoice In Email'},
      {'key': 'send_invoice_in_sms', 'title': 'Send Invoice In Sms'},
      {
        'key': 'send_invoice_in_push_notification',
        'title': 'Send Invoice In Push Notification',
      },
      {'key': 'is_sponsored', 'title': 'Is Sponsored'},
      {'key': 'is_featured', 'title': 'Is Featured'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Notification settings',
          description: 'Manage notification settings here',
        ),
        const SizedBox(height: 24),
        Divider(height: 1, color: Colors.grey[200]),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: settingsList.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, color: Colors.grey[100]),
          itemBuilder: (context, index) {
            final setting = settingsList[index];
            final key = setting['key']!;
            final title = setting['title']!;
            final value = _notificationSettings[key] ?? false;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Toggle ${title.toLowerCase()} (charges apply)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Switch(
                    value: value,
                    onChanged: (val) => _updateNotificationSetting(key, val),
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF1976D2),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 30, // Fixed width for alignment
                    child: Text(
                      value ? 'On' : 'Off',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPayoutsTab() {
    if (_isPayoutsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_payoutsError != null) {
      return Center(
        child: Column(
          children: [
            Text(_payoutsError!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _fetchPayoutAccounts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payout Accounts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your bank accounts, wallets, and UPI for payouts',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Add account logic
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text(
                'Add Account',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Financial Year Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA), // Light greyish blue
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: Color(0xFF1976D2),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isSmallScreen = constraints.maxWidth < 450;
                    return Flex(
                      direction: isSmallScreen
                          ? Axis.vertical
                          : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: isSmallScreen ? double.infinity : 250,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedFinancialYearId,
                              hint: const Text(
                                'Financial Year (Optional)',
                                style: TextStyle(
                                  fontSize: 14,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              isExpanded: true,
                              items: _financialYears.map((fy) {
                                return DropdownMenuItem<String>(
                                  value: fy.id,
                                  child: Text(fy.displayName), // e.g. FY 2026
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedFinancialYearId = val;
                                });
                              },
                            ),
                          ),
                        ),
                        SizedBox(
                          width: isSmallScreen ? 0 : 16,
                          height: isSmallScreen ? 8 : 0,
                        ),
                        if (!isSmallScreen)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'Select a financial year to view opening balances',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                        else
                          Text(
                            'Select a financial year to view opening balances',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        LayoutBuilder(
          builder: (context, constraints) {
            // Responsive Grid
            int crossAxisCount = constraints.maxWidth > 800 ? 2 : 1;

            // If we have just a few items, we can just use a Wrap or Column for simplicity logic with LayoutBuilder
            // But GridView is cleaner for 2 columns.
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 1.8, // Adjust based on content
                mainAxisExtent: 260, // Fixed height for cards
              ),
              itemCount: _payoutAccounts.length,
              itemBuilder: (context, index) {
                final account = _payoutAccounts[index];
                return _buildPayoutAccountCard(account);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPayoutAccountCard(StoreBankDetails account) {
    bool isDefault = account.isDefault;
    bool isCash =
        account.accountTypeChoices.toLowerCase() == 'cash' ||
        account.bankName == null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCash
                      ? Icons.account_balance_wallet_outlined
                      : Icons.account_balance_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.bankName ?? 'Cash Account',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCash ? 'Cash Account' : 'Savings Bank Account',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: Colors.grey[600],
                onPressed: () {
                  // Edit action
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(height: 1, color: Colors.grey[200]),
          const SizedBox(height: 16),
          _buildDetailRow(
            'Account Number',
            account.accountNumberOrUpiId,
            isBold: true,
          ),
          if (!isCash)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _buildDetailRow(
                'IFSC Code',
                account.ifscCode ?? '-',
                isBold: true,
              ),
            ),
          const SizedBox(height: 8),
          _buildDetailRow(
            'Account Holder',
            account.accountHolderName,
            isBold: true,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Holder Type',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      account.accountHolderType,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1976D2),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isDefault) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 14, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'Default',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
