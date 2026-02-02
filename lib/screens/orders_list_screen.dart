import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/screens/order_details_screen.dart';

import 'package:exanor/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

import 'package:exanor/components/store_main_drawer.dart';

class OrdersListScreen extends StatefulWidget {
  final String? storeId;
  final VoidCallback? onMenuPressed;

  const OrdersListScreen({super.key, this.storeId, this.onMenuPressed});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _orders = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasNextPage = false;
  int _currentPage = 1;
  String? _effectiveStoreId;
  String? _storeName; // Added to store the store name

  String? _errorMessage;
  List<dynamic> _statusOptions = [];
  String? _selectedStatus;
  bool _isLoadingStatusOptions = false;

  // Search state
  bool _isSearchExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  // Date Filter State
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _init();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _init() {
    _effectiveStoreId = widget.storeId; // Use the required storeId
    _fetchStoreName(); // Fetch store name
    _fetchStatusOptions();
    _fetchOrders();
  }

  Future<void> _fetchStoreName() async {
    if (_effectiveStoreId == null) return;
    try {
      final response = await ApiService.get(
        '/stores/${_effectiveStoreId}/',
        useBearerToken: true,
      );
      if (response['data'] != null &&
          response['data']['status'] == 200 &&
          mounted) {
        setState(() {
          _storeName = response['data']['response']['name'];
        });
      }
    } catch (e) {
      print("❌ Error fetching store name: $e");
    }
  }

  // Default fallback status options
  static const List<Map<String, dynamic>> _defaultStatusOptions = [
    {'status': 'order_placed', 'status_title_for_seller': 'Order Placed'},
    {'status': 'order_confirmed', 'status_title_for_seller': 'Confirmed'},
    {'status': 'order_preparing', 'status_title_for_seller': 'Preparing'},
    {'status': 'order_ready', 'status_title_for_seller': 'Ready'},
    {'status': 'order_completed', 'status_title_for_seller': 'Completed'},
    {'status': 'order_cancelled', 'status_title_for_seller': 'Cancelled'},
  ];

  Future<void> _fetchStatusOptions() async {
    if (_effectiveStoreId == null) return;

    setState(() => _isLoadingStatusOptions = true);

    try {
      final requestBody = {"store_id": _effectiveStoreId, "store_access": true};

      final response = await ApiService.post(
        '/order-status-options/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null &&
          response['data']['status'] == 200 &&
          mounted) {
        final List<dynamic> apiOptions = response['data']['response'] ?? [];
        setState(() {
          // Use API options if available, otherwise use defaults
          _statusOptions = apiOptions.isNotEmpty
              ? apiOptions
              : _defaultStatusOptions;
          _isLoadingStatusOptions = false;
        });
      } else {
        // API failed, use default options
        if (mounted) {
          setState(() {
            _statusOptions = _defaultStatusOptions;
            _isLoadingStatusOptions = false;
          });
        }
      }
    } catch (e) {
      print("❌ Error fetching status options: $e");
      // On error, use default options
      if (mounted) {
        setState(() {
          _statusOptions = _defaultStatusOptions;
          _isLoadingStatusOptions = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoadingMore &&
        _hasNextPage) {
      _fetchOrders(isLoadMore: true);
    }
  }

  Future<void> _fetchOrders({bool isLoadMore = false}) async {
    if (isLoadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final Map<String, dynamic> query = {};
      if (_selectedStatus != null) {
        query['status'] = _selectedStatus;
      }
      // Assuming backend supports search in query for now, if not keep as is
      if (_searchController.text.isNotEmpty) {
        // query['search'] = _searchController.text;
      }

      if (_selectedDateRange != null) {
        query['start_date'] = DateFormat(
          'yyyy-MM-dd',
        ).format(_selectedDateRange!.start);
        query['end_date'] = DateFormat(
          'yyyy-MM-dd',
        ).format(_selectedDateRange!.end);
      }

      final requestBody = {
        "query": query,
        "page": isLoadMore ? _currentPage + 1 : 1,
        "store_id": _effectiveStoreId,
        "store_access": true,
      };

      final result = await ApiService.post(
        '/orders/',
        body: requestBody,
        useBearerToken: true,
      );

      if (result['data'] != null && result['data']['status'] == 200) {
        final data = result['data'];
        final List<dynamic> newOrders = data['response'] ?? [];
        final pagination = data['pagination'];

        if (mounted) {
          setState(() {
            if (isLoadMore) {
              _orders.addAll(newOrders);
              _currentPage++;
            } else {
              _orders = newOrders;
              _currentPage = 1;
            }

            if (pagination != null) {
              _hasNextPage = pagination['has_next'] ?? false;
            } else {
              _hasNextPage = false;
            }

            _isLoading = false;
            _isLoadingMore = false;
            _errorMessage = null;
          });
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to load orders');
      }
    } catch (e) {
      print('Error fetching orders: $e');
      if (mounted) {
        setState(() {
          if (!isLoadMore) {
            _errorMessage = e.toString();
            _isLoading = false;
          }
          _isLoadingMore = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'order_placed':
        return Colors.blue;
      case 'order_confirmed':
        return Colors.orange;
      case 'order_preparing':
        return Colors.amber;
      case 'order_ready':
        return Colors.cyan;
      case 'order_completed':
        return Colors.green;
      case 'order_cancelled':
        return Colors.red;
      case 'order_returned':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Future<void> _selectDateRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 1)), // Allow today
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _fetchOrders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        extendBodyBehindAppBar: true, // Force body to top of screen
        primary: false, // Don't reserve safe area for app bar
        backgroundColor: Colors.grey[50], // Match POS background
        drawer: widget.onMenuPressed != null
            ? null
            : StoreMainDrawer(
                storeId: _effectiveStoreId ?? '',
                storeName: _storeName ?? 'Store',
              ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Expanded Banner with Menu & Status Buttons
            _buildExpandedBanner(theme),

            // 2. Search Bar (Conditional)
            if (_isSearchExpanded)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search orders...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (_) => _fetchOrders(),
                ),
              ),

            // 3. Orders List
            Expanded(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedBanner(ThemeData theme) {
    const lightBlueBg = Color(0xFFEFF6FF);
    const watermarkColor = Color(0xFFDBEAFE);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: lightBlueBg,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRect(
        child: Stack(
          children: [
            // Watermark
            Positioned(
              right: -30,
              top: -10,
              child: Transform.rotate(
                angle: -math.pi / 6,
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 180,
                  color: watermarkColor.withOpacity(0.6),
                ),
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                MediaQuery.of(context).padding.top + 8,
                12,
                12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ROW 1: HEADER (Menu, Title, Search)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Menu Button
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TranslatedText(
                            'MENU',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.blueGrey[400],
                              letterSpacing: 1.2,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.menu_rounded,
                              color: Colors.blueGrey,
                              size: 32,
                            ),
                            onPressed: () {
                              if (widget.onMenuPressed != null) {
                                widget.onMenuPressed!();
                              } else {
                                _scaffoldKey.currentState?.openDrawer();
                              }
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TranslatedText(
                              'Store Orders',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.5,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.2),
                                ),
                              ),
                              child: TranslatedText(
                                'HISTORY',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.blue,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Date Filter Button
                      SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TranslatedText(
                              _selectedDateRange != null ? 'CLEAR' : 'DATE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: _selectedDateRange != null
                                    ? Colors.red[400]
                                    : Colors.blueGrey[400],
                                letterSpacing: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () {
                                if (_selectedDateRange != null) {
                                  setState(() {
                                    _selectedDateRange = null;
                                  });
                                  _fetchOrders();
                                } else {
                                  _selectDateRange();
                                }
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _selectedDateRange != null
                                      ? Colors.red[50]
                                      : Colors.white,
                                  border: Border.all(
                                    color: _selectedDateRange != null
                                        ? Colors.red.withOpacity(0.2)
                                        : Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueGrey.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _selectedDateRange != null
                                      ? Icons.close
                                      : Icons.calendar_today_rounded,
                                  size: 24,
                                  color: _selectedDateRange != null
                                      ? Colors.red
                                      : Colors.blueGrey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Search Button
                      SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TranslatedText(
                              'SEARCH',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.blueGrey[400],
                                letterSpacing: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isSearchExpanded = !_isSearchExpanded;
                                  if (!_isSearchExpanded) {
                                    _searchController.clear();
                                    _fetchOrders();
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueGrey.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isSearchExpanded
                                      ? Icons.close
                                      : Icons.search_rounded,
                                  size: 24,
                                  color: Colors.blueGrey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ROW 2 & 3: Status Buttons (Embedded)
                  _buildStatusButtonsGrid(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButtonsGrid(ThemeData theme) {
    if (_isLoadingStatusOptions) {
      return const Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final List<Map<String, dynamic>> allOptions = [
      {'label': 'All', 'id': null},
      ..._statusOptions.map(
        (opt) => {
          'label': opt['status_title_for_seller'] ?? opt['status'] ?? 'Unknown',
          'id': opt['status'],
        },
      ),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: allOptions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final opt = allOptions[index];
          final isSelected = _selectedStatus == opt['id'];
          return Center(
            child: InkWell(
              onTap: () {
                if (!isSelected) {
                  setState(() {
                    _selectedStatus = opt['id'];
                    _fetchOrders();
                  });
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[700] : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: isSelected ? Colors.blue[800]! : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: TranslatedText(
                  opt['label'] ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.blueGrey[700],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: TranslatedText(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchOrders(),
              child: const TranslatedText('Retry'),
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: Colors.black.withOpacity(0.1),
            ),
            const SizedBox(height: 16),
            TranslatedText(
              'No orders found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use GridView for Tablet/Desktop (width > 600)
        if (constraints.maxWidth > 600) {
          return GridView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400, // Slightly narrower for better density
              mainAxisExtent: 260, // Reduced height for more compact view
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _orders.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _orders.length) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildPremiumOrderCard(
                theme,
                _orders[index],
                isGrid: true,
              );
            },
          );
        } else {
          // Use ListView for Mobile
          return ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              bottom: 30,
              left: 16,
              right: 16,
              top: 16,
            ),
            itemCount: _orders.length + (_isLoadingMore ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              if (index == _orders.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _buildPremiumOrderCard(theme, _orders[index]);
            },
          );
        }
      },
    );
  }

  Widget _buildPremiumOrderCard(
    ThemeData theme,
    dynamic order, {
    bool isGrid = false,
  }) {
    final status = order['status'] ?? 'Unknown';

    // User Info (Instead of Store Info)
    final userName =
        order['user_name'] ??
        order['customer_name'] ??
        order['user_first_name'] ??
        order['name'] ??
        (order['billing_details'] != null
            ? order['billing_details']['name']
            : null) ??
        'Guest Customer';

    final userAddress =
        order['address'] ??
        (order['billing_details'] != null
            ? "${order['billing_details']['area'] ?? ''} ${order['billing_details']['city'] ?? ''}"
            : 'No Address');

    final userImage = order['user_image'] ?? order['customer_image'];

    // Items
    var items = [];
    if (order['product_names'] != null) {
      final names = order['product_names'].toString().split(',');
      items = names
          .where((n) => n.trim().isNotEmpty)
          .map((name) => {'product_name': name.trim(), 'quantity': 1})
          .toList();
    } else if (order['products'] != null) {
      items = order['products'] as List;
    }

    // Date & Total
    final timestamp = order['timestamp'] ?? order['created_at'];
    String date = 'Date Unknown';
    if (timestamp != null) {
      try {
        final DateTime parsed = DateTime.parse(timestamp.toString());
        date = DateFormat('dd MMM yyyy, hh:mm a').format(parsed);
      } catch (e) {
        date = timestamp.toString();
      }
    }

    final totalAmount = order['total'] ?? order['grand_total'] ?? 0;
    final total =
        '₹${double.tryParse(totalAmount.toString())?.toStringAsFixed(2) ?? '0.00'}';

    final cardBg = Colors.white;
    final statusColor = _getStatusColor(status);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.zero,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Left accent strip - visual status indicator
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
          // Main card content
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderDetailsScreen(
                      orderId: order['id'],
                      storeId: order['store_id'] ?? _effectiveStoreId ?? '',
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.zero,
              child: Column(
                mainAxisSize: isGrid ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  // 1. Header: User Image + Name + Status
                  Padding(
                    padding: isGrid
                        ? const EdgeInsets.fromLTRB(16, 12, 16, 8)
                        : const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[100],
                            image: userImage != null
                                ? DecorationImage(
                                    image: NetworkImage(userImage),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: userImage == null
                              ? Icon(
                                  Icons.person_rounded,
                                  color: Colors.grey[400],
                                  size: 26,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  userAddress,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status Badge (Moved outside header for grid or kept similar?)
                  // For consistent height, maybe keep it fixed or absolute?
                  // Let's keep layout simple.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(child: _buildDashedLine(theme)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: statusColor.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            (order['order_status_title'] ?? status)
                                .toString()
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Items List
                  if (isGrid) ...[
                    // Fixed height/content for grid to prevent scatter
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4, // Reduced padding
                        ),
                        child: items.isEmpty
                            ? Center(
                                child: Text(
                                  "No Items",
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...items.take(2).map<Widget>((item) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.grey[400],
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              "${item['quantity'] ?? 1} x ${item['product_name'] ?? item['name'] ?? ''}",
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.black87
                                                    .withOpacity(0.7),
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  if (items.length > 2)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        left: 12,
                                      ),
                                      child: Text(
                                        "+ ${items.length - 2} more",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                      ),
                    ),
                  ] else ...[
                    // Mobile layout (Flexible)
                    if (items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Column(
                          children: [
                            ...items.take(3).map<Widget>((item) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "${item['quantity'] ?? 1} x ${item['product_name'] ?? item['name'] ?? ''}",
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87.withOpacity(
                                            0.7,
                                          ),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (items.length > 3)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  left: 18,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    "+ ${items.length - 3} more items",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.primaryColor,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildDashedLine(theme),
                  ),

                  // 3. Footer: Date, Total
                  // For Grid, push this to bottom
                  if (isGrid) const SizedBox(height: 8),

                  Padding(
                    padding: isGrid
                        ? const EdgeInsets.fromLTRB(16, 8, 16, 12)
                        : const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              date,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              total,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),

                        // View Details Button (Small)
                        SizedBox(
                          height: 36,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => OrderDetailsScreen(
                                    orderId: order['id'],
                                    storeId:
                                        order['store_id'] ??
                                        _effectiveStoreId ??
                                        '',
                                  ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Colors.grey.withOpacity(0.3),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Details",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedLine(ThemeData theme) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.grey[300]),
              ),
            );
          }),
        );
      },
    );
  }
}
