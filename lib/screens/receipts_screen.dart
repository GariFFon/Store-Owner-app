import 'package:exanor/components/store_main_drawer.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/screens/receipt_details_screen.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class ReceiptsScreen extends StatefulWidget {
  final String storeId;
  final String? storeName;
  final VoidCallback? onMenuPressed;

  const ReceiptsScreen({
    super.key,
    required this.storeId,
    this.storeName,
    this.onMenuPressed,
  });

  @override
  State<ReceiptsScreen> createState() => _ReceiptsScreenState();
}

class _ReceiptsScreenState extends State<ReceiptsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<dynamic> _receipts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasNextPage = false;
  int _currentPage = 1;
  String? _errorMessage;
  int _totalItems = 0;

  // Debounce search
  // Timer? _debounce;
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _fetchReceipts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    // _debounce?.cancel();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasNextPage) {
      _fetchReceipts(isLoadMore: true);
    }
  }

  Future<void> _fetchReceipts({bool isLoadMore = false}) async {
    if (isLoadMore) {
      if (_isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final result = await StoreOwnerApiService.getReceipts(
        widget.storeId,
        page: isLoadMore ? _currentPage + 1 : 1,
        searchQuery: _searchController.text,
      );

      final receipts = result['response'] as List<dynamic>? ?? [];
      final pagination = result['pagination'] as Map<String, dynamic>? ?? {};

      if (mounted) {
        setState(() {
          if (isLoadMore) {
            _receipts.addAll(receipts);
            _currentPage++;
          } else {
            _receipts = receipts;
            _currentPage = 1;
          }

          _hasNextPage = pagination['has_next'] == true;
          _totalItems = pagination['total_items'] as int? ?? 0;

          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = null;
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

  void _onSearchChanged(String query) {
    // Basic debounce could be added here if needed
    // For now, let's just trigger fresh search on submit or change?
    // User requested "Search by voucher number"
  }

  String _formatDate(String? date) {
    if (date == null) return '';
    try {
      final parsed = DateTime.parse(date);
      return DateFormat('MMM d, yyyy').format(parsed);
    } catch (_) {
      return date;
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '₹0.00';
    return '₹${double.tryParse(amount.toString())?.toStringAsFixed(2) ?? amount}';
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
        drawer: StoreMainDrawer(
          storeId: widget.storeId,
          storeName: widget.storeName ?? 'Store',
        ),
        extendBodyBehindAppBar: true,
        primary: false,
        backgroundColor: Colors.grey[50],
        body: Column(
          children: [
            _buildExpandedBanner(theme),

            // Search Bar (Conditional)
            if (_isSearchExpanded)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 14),
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search by voucher number...',
                        hintStyle: TextStyle(
                          color: Colors.blueGrey[300],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.blueGrey[400],
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _fetchReceipts(),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                },
                child: _buildBody(theme),
              ),
            ),
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
                  Icons.receipt_long_outlined,
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
                24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ROW 1: HEADER (Menu, Title)
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
                      const SizedBox(width: 16),

                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TranslatedText(
                              'Receipts',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.5,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.2),
                                ),
                              ),
                              child: const TranslatedText(
                                'HISTORY',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.green,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Filter Button
                      SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TranslatedText(
                              'FILTER',
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Filters coming soon'),
                                  ),
                                );
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
                                  Icons.tune_rounded,
                                  size: 24,
                                  color: Colors.blueGrey[700],
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
                                    _fetchReceipts();
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading && _receipts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _receipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchReceipts(),
              child: const TranslatedText('Retry'),
            ),
          ],
        ),
      );
    }

    if (_receipts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_outlined, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            const TranslatedText('No receipts found'),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          // Table Layout for larger screens
          return Column(
            children: [
              // Table Header
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.05),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _buildTableHeaderText('DATE')),
                    Expanded(flex: 2, child: _buildTableHeaderText('VOUCHER')),
                    Expanded(
                      flex: 4,
                      child: _buildTableHeaderText('PARTY NAME'),
                    ),
                    Expanded(flex: 3, child: _buildTableHeaderText('ACCOUNT')),
                    Expanded(flex: 2, child: _buildTableHeaderText('AMOUNT')),
                    Expanded(flex: 2, child: _buildTableHeaderText('STATUS')),
                    const SizedBox(width: 40), // Action placeholder
                  ],
                ),
              ),
              // Table Body
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _fetchReceipts(),
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _receipts.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, thickness: 0.5),
                    itemBuilder: (context, index) {
                      if (index == _receipts.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final receipt = _receipts[index];
                      return _buildTabletReceiptRow(
                        theme,
                        receipt,
                        index == _receipts.length - 1,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        } else {
          // List View for mobile
          return RefreshIndicator(
            onRefresh: () => _fetchReceipts(),
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _receipts.length + (_isLoadingMore ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == _receipts.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final receipt = _receipts[index];
                return _buildReceiptRow(theme, receipt);
              },
            ),
          );
        }
      },
    );
  }

  Widget _buildTableHeaderText(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey[500],
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTabletReceiptRow(ThemeData theme, dynamic receipt, bool isLast) {
    final isPosted = receipt['is_posted'] == true;
    final statusColor = isPosted ? Colors.green : Colors.orange;

    return Material(
      color: Colors.white,
      shape: isLast
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            )
          : null,
      child: InkWell(
        onTap: () async {
          _searchFocusNode.unfocus();
          FocusScope.of(context).unfocus();
          await Future.delayed(
            const Duration(milliseconds: 100),
          ); // Allow keyboard to hide

          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReceiptDetailsScreen(receipt: receipt),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
              left: BorderSide(color: Colors.grey.withOpacity(0.1)),
              right: BorderSide(color: Colors.grey.withOpacity(0.1)),
            ),
          ),
          child: Row(
            children: [
              // Date
              Expanded(
                flex: 2,
                child: Text(
                  _formatDate(receipt['date']),
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Voucher
              Expanded(
                flex: 2,
                child: Text(
                  receipt['voucher_number'] ?? 'N/A',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Party
              Expanded(
                flex: 4,
                child: Text(
                  receipt['party_name'] ?? 'Unknown Party',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Account
              Expanded(
                flex: 3,
                child: Text(
                  receipt['receipt_account'] ?? '',
                  style: const TextStyle(fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Amount
              Expanded(
                flex: 2,
                child: Text(
                  _formatCurrency(receipt['amount']),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Status
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isPosted ? 'Posted' : 'Unposted',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ),
              // Action
              SizedBox(
                width: 40,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(ThemeData theme, dynamic receipt) {
    // Premium Card Style
    final isPosted = receipt['is_posted'] == true;
    final statusColor = isPosted ? Colors.green : Colors.orange;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5FCF7), // Subtle green background
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.green.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              // Unfocus keyboard if open to prevent it from popping up when returning
              _searchFocusNode.unfocus();
              FocusScope.of(context).unfocus();
              await Future.delayed(
                const Duration(milliseconds: 100),
              ); // Allow keyboard to hide

              if (!mounted) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReceiptDetailsScreen(receipt: receipt),
                ),
              );
            },
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Green Side Line
                  Container(width: 6, color: Colors.green),

                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon Box
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: Colors.green,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Text Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Row: Party Name & Amount
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        receipt['party_name'] ??
                                            'Unknown Party',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                          height: 1.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatCurrency(receipt['amount']),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: Color(
                                          0xFF14532D,
                                        ), // Darker green
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Middle Row: Voucher & Date
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.2),
                                        ),
                                      ),
                                      child: Text(
                                        "#${receipt['voucher_number'] ?? 'N/A'}",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green[800],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 12,
                                      color: Colors.blueGrey[400],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDate(receipt['date']),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.blueGrey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Bottom Row: Account & Status
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons
                                                .account_balance_wallet_outlined,
                                            size: 14,
                                            color: Colors.blueGrey[400],
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              receipt['receipt_account'] ?? '',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.blueGrey[600],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Status Badge - simplified
                                    if (isPosted)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            size: 14,
                                            color: Colors.green,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'POSTED',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green[700],
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(
                                        'UNPOSTED',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                          letterSpacing: 0.5,
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
