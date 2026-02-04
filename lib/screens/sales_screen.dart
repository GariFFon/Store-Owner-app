import 'dart:async';
import 'package:exanor/models/sales_models.dart';
import 'package:exanor/services/sales_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class SalesScreen extends StatefulWidget {
  final String storeId;

  const SalesScreen({super.key, required this.storeId});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  List<Voucher> _allVouchers = [];
  List<Voucher> _filteredVouchers = [];

  // Stats
  double _totalRevenue = 0.0;
  double _totalTax = 0.0;
  int _postedCount = 0;

  String _activeFilter = 'All'; // All, Posted, Draft

  @override
  void initState() {
    super.initState();
    _fetchSales();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchSales() async {
    setState(() => _isLoading = true);
    try {
      final response = await SalesService.fetchSales(storeId: widget.storeId);
      if (mounted) {
        setState(() {
          _allVouchers = response.vouchers;
          _applyFilters();
          _calculateStats();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateStats() {
    _totalRevenue = _allVouchers.fold(0.0, (sum, v) => sum + v.grandTotal);
    _totalTax = _allVouchers.fold(
      0.0,
      (sum, v) => sum + (v.taxBreakdown?.totalTax ?? 0.0),
    );
    _postedCount = _allVouchers.where((v) => v.isPosted).length;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _applyFilters();
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _activeFilter = filter;
      _applyFilters();
    });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredVouchers = _allVouchers.where((v) {
        final matchesSearch =
            v.voucherNumber.toLowerCase().contains(query) ||
            (v.customer?.name ?? '').toLowerCase().contains(query);
        final matchesFilter =
            _activeFilter == 'All' ||
            (_activeFilter == 'Posted' && v.isPosted) ||
            (_activeFilter == 'Draft' && !v.isPosted);

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _showDetails(Voucher voucher) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => SalesDetailsDialog(voucher: voucher),
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    // Breakpoint at 768 (iPad portrait) to show table on tablet
    final width = MediaQuery.of(context).size.width;
    final isDesktopOrTablet = width >= 768;

    // Theme: Blue for Sales
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
            // 1. Watermark Banner
            _buildInteractiveBanner(primaryColor, lightBg, watermarkColor),

            // 2. Main Scroll View
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchSales,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Stats Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: _buildStatsSection(
                          isDesktopOrTablet,
                          primaryColor,
                        ),
                      ),
                    ),

                    // Filter Segments
                    SliverToBoxAdapter(
                      child: _buildFilterSegments(primaryColor),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Table Header for Desktop/Tablet
                    if (isDesktopOrTablet && _filteredVouchers.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _buildTableHeader(primaryColor),
                      ),

                    // Sales List / Table Rows
                    if (_isLoading)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_filteredVouchers.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 48,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No sales found",
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: isDesktopOrTablet
                            ? EdgeInsets.zero
                            : const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => isDesktopOrTablet
                                ? _buildSaleTableRow(
                                    _filteredVouchers[index],
                                    index,
                                    primaryColor,
                                  )
                                : Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildSaleCard(
                                      _filteredVouchers[index],
                                      primaryColor,
                                    ),
                                  ),
                            childCount: _filteredVouchers.length,
                          ),
                        ),
                      ),

                    const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============== 1. HEADER (Copied & Adapted) ==============
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
          // Watermark
          Positioned(
            right: -30,
            top: -20,
            child: Transform.rotate(
              angle: -math.pi / 6,
              child: Icon(
                Icons.receipt_long_rounded,
                size: 220,
                color: watermark.withOpacity(0.8),
              ),
            ),
          ),

          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 12,
              20,
              20,
            ),
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
                          color: Colors.white.withOpacity(0.5),
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
                              color: Colors.black87,
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
                            "Sales",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "Invoices & Revenue",
                            style: TextStyle(
                              fontSize: 12,
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Add Button (Placeholder if needed)
                  ],
                ),

                const SizedBox(height: 24),

                // Search
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search by voucher or customer...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Icon(Icons.search_rounded, color: primary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============== 2. STATS SECTION ==============
  Widget _buildStatsSection(bool isWide, Color primary) {
    final countCard = _buildStatBox(
      "Invoices",
      _allVouchers.length.toString(),
      Icons.receipt,
      Colors.blue,
    );

    final revenueCard = _buildStatBox(
      "Revenue",
      _formatCurrency(_totalRevenue),
      Icons.attach_money,
      primary,
      isCurrency: true,
      isHero: true,
    );

    final taxCard = _buildStatBox(
      "Total Tax",
      _formatCurrency(_totalTax),
      Icons.percent,
      Colors.purple,
      isCurrency: true,
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: countCard),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: revenueCard),
          const SizedBox(width: 16),
          Expanded(child: taxCard),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(width: double.infinity, child: revenueCard),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: countCard),
            const SizedBox(width: 12),
            Expanded(child: taxCard),
          ],
        ),
      ],
    );
  }

  Widget _buildStatBox(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isCurrency = false,
    bool isHero = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isHero ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHero ? color.withOpacity(0.2) : Colors.grey[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: isCurrency ? 20 : 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============== 3. FILTER SEGMENTS ==============
  Widget _buildFilterSegments(Color primary) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildFilterChip("All", _activeFilter == 'All', primary),
          const SizedBox(width: 10),
          _buildFilterChip("Posted", _activeFilter == 'Posted', Colors.green),
          const SizedBox(width: 10),
          _buildFilterChip("Draft", _activeFilter == 'Draft', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isActive, Color color) {
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: (val) => _onFilterChanged(label),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      visualDensity: VisualDensity.compact,
    );
  }

  // ============== 4. TABLE HEADER (Desktop) ==============
  Widget _buildTableHeader(Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text('VOUCHER', style: _headerStyle)),
            Expanded(flex: 2, child: Text('DATE', style: _headerStyle)),
            Expanded(flex: 3, child: Text('CUSTOMER', style: _headerStyle)),
            Expanded(flex: 2, child: Text('AMOUNT', style: _headerStyle)),
            Expanded(flex: 1, child: Text('STATUS', style: _headerStyle)),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  TextStyle get _headerStyle => TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 12,
    color: Colors.grey[500],
    letterSpacing: 0.5,
  );

  // ============== 5. TABLE ROW (Desktop) ==============
  Widget _buildSaleTableRow(Voucher v, int index, Color primary) {
    final isLast = index == _filteredVouchers.length - 1;
    return GestureDetector(
      onTap: () => _showDetails(v),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            left: BorderSide(color: Colors.grey[200]!),
            right: BorderSide(color: Colors.grey[200]!),
            bottom: BorderSide(color: Colors.grey[200]!),
          ),
          borderRadius: isLast
              ? const BorderRadius.vertical(bottom: Radius.circular(12))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                v.voucherNumber,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                v.date,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                v.customer?.name ?? 'Unknown',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '₹${v.grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: v.isPosted
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  v.isPosted ? 'Posted' : 'Draft',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: v.isPosted ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ),
            const SizedBox(
              width: 40,
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.chevron_right, size: 18, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============== 6. CARD (Mobile) ==============
  Widget _buildSaleCard(Voucher v, Color primary) {
    return GestureDetector(
      onTap: () => _showDetails(v),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Icon(Icons.receipt, color: primary)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.voucherNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          v.customer?.name ?? 'Unknown Customer',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat.yMMMd().format(DateTime.parse(v.date)),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey[100]),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: v.isPosted
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      v.isPosted ? 'POSTED' : 'DRAFT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: v.isPosted ? Colors.green : Colors.orange,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    '₹${v.grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============== SALES DETAILS DIALOG (Premium Redesign) ==============
class SalesDetailsDialog extends StatefulWidget {
  final Voucher voucher;

  const SalesDetailsDialog({super.key, required this.voucher});

  @override
  State<SalesDetailsDialog> createState() => _SalesDetailsDialogState();
}

class _SalesDetailsDialogState extends State<SalesDetailsDialog> {
  bool _isTaxExpanded = false;

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF2563EB); // Blue-600

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with Gradient
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [themeColor, themeColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.voucher.isPosted ? 'POSTED' : 'DRAFT',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "TOTAL AMOUNT",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${widget.voucher.grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: Colors.white.withOpacity(0.8),
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat.yMMMd().format(
                          DateTime.parse(widget.voucher.date),
                        ),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.confirmation_number_outlined,
                        color: Colors.white.withOpacity(0.8),
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.voucher.voucherNumber,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Customer Section
                      _buildSectionHeader("CUSTOMER DETAILS"),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person, color: Colors.grey),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.voucher.customer?.name ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  widget.voucher.customer?.partyType ??
                                      'Customer',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Items Section
                      _buildSectionHeader("ITEMS PURCHASED"),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[200]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            ...widget.voucher.items.map((item) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[100]!,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: themeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        "${item.quantity.toInt()}x",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: themeColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName ?? 'Item',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (item.inventory?.hsnCode != null)
                                            Text(
                                              "HSN: ${item.inventory?.hsnCode}",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[400],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₹${item.amount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Tax Breakdown Section
                      if (widget.voucher.taxBreakdown != null) ...[
                        _buildSectionHeader("TAX BREAKDOWN"),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isTaxExpanded = !_isTaxExpanded;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              children: [
                                // Toggle Header
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.grey[300]!,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.percent,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            "Total Tax",
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            '₹${widget.voucher.taxBreakdown!.totalTax.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            _isTaxExpanded
                                                ? Icons.keyboard_arrow_up
                                                : Icons.keyboard_arrow_down,
                                            size: 20,
                                            color: Colors.grey[500],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Expandable Content
                                if (_isTaxExpanded) ...[
                                  Divider(
                                    height: 1,
                                    indent: 16,
                                    endIndent: 16,
                                    color: Colors.grey[200],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        _buildVerticalTaxRow(
                                          "CGST",
                                          widget
                                              .voucher
                                              .taxBreakdown!
                                              .totalCgst,
                                        ),
                                        const SizedBox(height: 12),
                                        _buildVerticalTaxRow(
                                          "SGST",
                                          widget
                                              .voucher
                                              .taxBreakdown!
                                              .totalSgst,
                                        ),
                                        const SizedBox(height: 12),
                                        _buildVerticalTaxRow(
                                          "IGST",
                                          widget
                                              .voucher
                                              .taxBreakdown!
                                              .totalIgst,
                                        ),
                                        const SizedBox(height: 12),
                                        _buildVerticalTaxRow(
                                          "CESS",
                                          widget
                                              .voucher
                                              .taxBreakdown!
                                              .totalCess,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],

                      // Payment Summary
                      _buildSectionHeader("PAYMENT SUMMARY"),
                      const SizedBox(height: 16),
                      _buildSummaryRow(
                        "Subtotal",
                        '₹${widget.voucher.totalAmount.toStringAsFixed(2)}',
                      ),
                      _buildSummaryRow(
                        "Tax (GST)",
                        '₹${(widget.voucher.taxBreakdown?.totalTax ?? 0).toStringAsFixed(2)}',
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(),
                      ),
                      _buildSummaryRow(
                        "Grand Total",
                        '₹${widget.voucher.grandTotal.toStringAsFixed(2)}',
                        isTotal: true,
                        color: themeColor,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey[400],
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isTotal = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalTaxRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
            fontFamily: 'RobotoMono', // Optional monospace for alignment
          ),
        ),
      ],
    );
  }
}
