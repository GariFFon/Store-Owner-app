import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/screens/add_purchase_order_screen.dart';
import 'package:exanor/screens/product_details_screen.dart';
import 'package:exanor/screens/purchase_details_screen.dart';
import 'package:exanor/screens/supplier_details_screen.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:exanor/screens/intelligence_upload_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PurchaseScreen extends StatefulWidget {
  final String storeId;

  const PurchaseScreen({super.key, required this.storeId});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _vouchers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  // ignore: unused_field
  bool _hasNextPage = false;
  int _limit = 50;
  int _offset = 0;
  int _count = 0;

  DateTimeRange? _selectedDateRange;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _fetchPurchases();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
        });
      }
    } catch (e) {
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
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _fetchPurchases();
    }
  }

  void _clearFilter() {
    setState(() {
      _selectedDateRange = null;
    });
    _fetchPurchases();
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
      // Navigate to Supplier Details Screen
      final supplierResult = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              SupplierDetailsScreen(data: result, storeId: widget.storeId),
        ),
      );

      // If user clicked Continue on Supplier Details, show Product Details
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

        // If user clicked Continue on Product Details, go to Add Purchase Order Screen with data
        if (productContinue == true && mounted) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText(
          'Purchases',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'manual') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AddPurchaseOrderScreen(storeId: widget.storeId),
                    ),
                  );
                } else if (value == 'ai') {
                  _handleAiPurchase();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    const TranslatedText(
                      'New Purchase',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'manual',
                  child: Row(
                    children: [
                      Icon(Icons.edit_note, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      const TranslatedText('Manually'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'ai',
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      const TranslatedText('With AI'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(theme),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _selectDateRange,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedDateRange != null
                            ? '${DateFormat('MMM d, yyyy').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, yyyy').format(_selectedDateRange!.end)}'
                            : 'Filter by Date',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    if (_selectedDateRange != null)
                      GestureDetector(
                        onTap: () {
                          // Prevent triggering the parent onTap
                          // But here onTap is on InkWell, so we might need a separate button
                        },
                        child: InkWell(
                          onTap: _clearFilter,
                          child: Icon(
                            Icons.close,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_drop_down,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
              child: Text(_errorMessage!, textAlign: TextAlign.center),
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
              color: theme.colorScheme.onSurface.withOpacity(0.2),
            ),
            const SizedBox(height: 16),
            TranslatedText(
              'No purchases found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            if (_selectedDateRange != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _clearFilter,
                child: const TranslatedText('Clear Filter'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchPurchases(),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _vouchers.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _vouchers.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final voucher = _vouchers[index];
          return _buildPurchaseCard(theme, voucher);
        },
      ),
    );
  }

  Widget _buildPurchaseCard(ThemeData theme, dynamic voucher) {
    final paymentStatus =
        voucher['payment_info']?['payment_status'] ?? 'UNKNOWN';
    final statusColor = _getStatusColor(paymentStatus);
    final supplierName = voucher['supplier']?['name'] ?? 'Unknown Supplier';

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplierName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '#${voucher['voucher_number']}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${voucher['grand_total']}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          voucher['date'] ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: theme.dividerColor.withOpacity(0.1)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        paymentStatus,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (voucher['status'] == 'PENDING')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Verify Pending',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
