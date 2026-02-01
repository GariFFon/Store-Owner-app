import 'package:flutter/material.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/api_service.dart';

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
                      _buildPlaceholderTab('Payments'),
                      _buildPlaceholderTab('Payouts'),
                      _buildPlaceholderTab('Shipping'),
                      _buildPlaceholderTab('Notifications'),
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
              onPressed: () {},
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
                      // Implement toggle logic here if needed separate from EDIT
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
                    onPressed: () {},
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
}
