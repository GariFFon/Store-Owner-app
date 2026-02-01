import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/screens/add_purchase_order_screen.dart';
import 'package:exanor/screens/product_details_screen.dart';
import 'package:exanor/screens/purchase_details_screen.dart';
import 'package:exanor/screens/supplier_details_screen.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/components/store_main_drawer.dart';
import 'package:exanor/screens/intelligence_upload_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class PurchaseScreen extends StatefulWidget {
  final String storeId;

  const PurchaseScreen({super.key, required this.storeId});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _vouchers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasNextPage = false;
  int _limit = 50;
  int _offset = 0;
  int _count = 0;

  DateTimeRange? _selectedDateRange;
  String? _errorMessage;
  String? _storeName;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _fetchStoreName();
    _fetchPurchases();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchStoreName() async {
    try {
      final response = await ApiService.get(
        '/stores/${widget.storeId}/',
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

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasNextPage) {
      _fetchPurchases(isLoadMore: true);
    }
  }

  Future<void> _fetchPurchases({bool isLoadMore = false}) async {
    if (isLoadMore) {
      if (_isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final filters = <String, dynamic>{};
      if (_selectedDateRange != null) {
        filters['start_date'] = DateFormat(
          'yyyy-MM-dd',
        ).format(_selectedDateRange!.start);
        filters['end_date'] = DateFormat(
          'yyyy-MM-dd',
        ).format(_selectedDateRange!.end);
      }

      final result = await StoreOwnerApiService.getPurchaseEntries(
        widget.storeId,
        filters: filters,
        limit: _limit,
        offset: isLoadMore ? _offset + _limit : 0,
      );

      final vouchers = result['vouchers'] as List<dynamic>? ?? [];
      final count = result['count'] as int? ?? 0;
      // ignore: unused_local_variable
      final returned = result['returned'] as int? ?? 0;

      if (mounted) {
        setState(() {
          if (isLoadMore) {
            _vouchers.addAll(vouchers);
            _offset += _limit;
          } else {
            _vouchers = vouchers;
            _offset = 0;
          }
          _count = count;
          _hasNextPage = _vouchers.length < _count;
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      print('Error fetching purchases: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
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
      _fetchPurchases();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'PARTIAL':
        return Colors.blue;
      case 'CREDIT':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handleAiPurchase() async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IntelligenceUploadDialog(storeId: widget.storeId),
    );

    if (result != null && result is Map<String, dynamic> && mounted) {
      final supplierResult = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              SupplierDetailsScreen(data: result, storeId: widget.storeId),
        ),
      );

      if (supplierResult != null &&
          supplierResult['continue'] == true &&
          mounted) {
        final supplierStoreId = supplierResult['supplierStoreId']?.toString();

        final productContinue = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(
              data: result,
              storeId: widget.storeId,
              supplierStoreId: supplierStoreId,
            ),
          ),
        );

        if (productContinue == true && mounted) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddPurchaseOrderScreen(
                  storeId: widget.storeId,
                  aiData: result,
                ),
              ),
            );
          }
        }
      }
    }
  }

  void _showAddPurchaseMenu() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'New Purchase',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_note, color: Colors.blue),
              ),
              title: const Text('Manually'),
              subtitle: const Text('Enter details manually'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddPurchaseOrderScreen(storeId: widget.storeId),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.purple),
              ),
              title: const Text('With AI'),
              subtitle: const Text('Scan or upload invoice'),
              onTap: () {
                Navigator.pop(context);
                _handleAiPurchase();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
        extendBodyBehindAppBar: true,
        primary: false,
        backgroundColor: Colors.grey[50],
        drawer: StoreMainDrawer(
          storeId: widget.storeId,
          storeName: _storeName ?? 'Store',
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildExpandedBanner(theme),
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
                  Icons.shopping_bag_outlined,
                  size: 180,
                  color: watermarkColor.withOpacity(0.6),
                ),
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ROW 1: HEADER (Back/Menu, Title, filters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Menu Button (Replaced Back)
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
                                _scaffoldKey.currentState?.openDrawer();
                              },
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),

                        // Title
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TranslatedText(
                                'Purchases',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
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
                                child: const TranslatedText(
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
                        Column(
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
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () {
                                if (_selectedDateRange != null) {
                                  setState(() {
                                    _selectedDateRange = null;
                                  });
                                  _fetchPurchases();
                                } else {
                                  _selectDateRange();
                                }
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(10),
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
                                  size: 20,
                                  color: _selectedDateRange != null
                                      ? Colors.red
                                      : Colors.blueGrey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),

                        // New Purchase Button (Enhanced)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TranslatedText(
                              'NEW',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.blueGrey[400],
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: _showAddPurchaseMenu,
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      theme.primaryColor,
                                      theme.primaryColor.withOpacity(0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.primaryColor.withOpacity(
                                        0.4,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
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
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchPurchases(),
              child: const TranslatedText('Retry'),
            ),
          ],
        ),
      );
    }

    if (_vouchers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.black.withOpacity(0.1),
            ),
            const SizedBox(height: 16),
            TranslatedText(
              'No purchases found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
            if (_selectedDateRange != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedDateRange = null;
                  });
                  _fetchPurchases();
                },
                child: const TranslatedText('Clear Filter'),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 30, left: 16, right: 16, top: 16),
      itemCount: _vouchers.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == _vouchers.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return _buildPremiumPurchaseCard(theme, _vouchers[index]);
      },
    );
  }

  Widget _buildPremiumPurchaseCard(ThemeData theme, dynamic voucher) {
    final paymentStatus =
        voucher['payment_info']?['payment_status'] ?? 'UNKNOWN';
    final statusColor = _getStatusColor(paymentStatus);
    final supplierName = voucher['supplier']?['name'] ?? 'Unknown Supplier';
    final voucherNumber = voucher['voucher_number'] ?? 'No Voucher #';

    final grandTotal = voucher['grand_total'];
    final amount = '₹$grandTotal';

    final dateStr = voucher['date'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PurchaseDetailsScreen(
                  storeId: widget.storeId,
                  purchaseData: voucher as Map<String, dynamic>,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.store_mall_directory_rounded,
                        color: Colors.blue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplierName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '#$voucherNumber',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blueGrey[300],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          amount,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.blueGrey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        paymentStatus,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),

                    if (voucher['status'] == 'PENDING') ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          'Verify Pending',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
