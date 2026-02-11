import 'dart:async';
import 'package:exanor/models/payment_models.dart';
import 'package:exanor/services/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class PaymentScreen extends StatefulWidget {
  final String storeId;

  const PaymentScreen({super.key, required this.storeId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool _isLoading = true;
  List<PaymentVoucher> _allVouchers = [];
  bool _isSearchExpanded = false;
  List<PaymentVoucher> _filteredVouchers = [];

  // Stats
  double _totalAmount = 0.0;
  int _postedCount = 0;
  int _totalCount = 0;

  String _activeFilter = 'All'; // All, Posted, Draft

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchPayments() async {
    setState(() => _isLoading = true);
    try {
      final response = await PaymentService.fetchPayments(
        storeId: widget.storeId,
        page: 1,
        pageSize: 100, // Fetch a reasonable amount
      );
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
    _totalAmount = _allVouchers.fold(0.0, (sum, v) => sum + v.amount);
    _postedCount = _allVouchers.where((v) => v.isPosted).length;
    _totalCount = _allVouchers.length;
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
            v.partyName.toLowerCase().contains(query);
        final matchesFilter =
            _activeFilter == 'All' ||
            (_activeFilter == 'Posted' && v.isPosted) ||
            (_activeFilter == 'Draft' && !v.isPosted);

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  void _showDetails(PaymentVoucher voucher) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) =>
          PaymentDetailsDialog(voucher: voucher, storeId: widget.storeId),
    );
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktopOrTablet = width >= 768;

    // Theme: Blue (Consistent with App)
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
            // 1. Interactive Banner
            _buildInteractiveBanner(primaryColor, lightBg, watermarkColor),

            // 2. Search Bar (Conditional)
            if (_isSearchExpanded)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by voucher or party...',
                    prefixIcon: Icon(Icons.search, color: primaryColor),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),

            // 2. Main Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchPayments,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Stats
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: _buildStatsSection(
                          isDesktopOrTablet,
                          primaryColor,
                        ),
                      ),
                    ),

                    // Filters
                    SliverToBoxAdapter(
                      child: _buildFilterSegments(primaryColor),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Table Header
                    if (isDesktopOrTablet && _filteredVouchers.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _buildTableHeader(primaryColor),
                      ),

                    // List/Grid
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
                                Icons.payment_outlined,
                                size: 48,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No payments found",
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
                                ? _buildTableRow(
                                    _filteredVouchers[index],
                                    index,
                                    primaryColor,
                                  )
                                : Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildMobileCard(
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

  // ============== 1. BANNER ==============
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
            right: -20,
            top: -10,
            child: Transform.rotate(
              angle: -math.pi / 8,
              child: Icon(
                Icons.payments_rounded,
                size: 200,
                color: watermark.withOpacity(0.6),
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
                      onTap: () => Navigator.pop(context),
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
                            "Payments",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "History & Transactions",
                            style: TextStyle(
                              fontSize: 12,
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Search Button
                    SizedBox(
                      width: 70,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
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
                                  _applyFilters();
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
    );
  }

  // ============== 2. STATS ==============
  Widget _buildStatsSection(bool isWide, Color primary) {
    final countCard = _buildStatBox(
      "Total Payments",
      _totalCount.toString(),
      Icons.receipt_long,
      Colors.indigo,
    );

    final amountCard = _buildStatBox(
      "Total Amount",
      _formatCurrency(_totalAmount),
      Icons.attach_money,
      primary,
      isHero: true,
    );

    final postedCard = _buildStatBox(
      "Posted",
      _postedCount.toString(),
      Icons.check_circle_outline,
      Colors.green,
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: countCard),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: amountCard),
          const SizedBox(width: 16),
          Expanded(child: postedCard),
        ],
      );
    }

    return Column(
      children: [
        SizedBox(width: double.infinity, child: amountCard),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: countCard),
            const SizedBox(width: 12),
            Expanded(child: postedCard),
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
        mainAxisAlignment: MainAxisAlignment.center,
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
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============== 3. FILTERS ==============
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

  // ============== 4. TABLE HEADER ==============
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
            Expanded(flex: 3, child: Text('PARTY', style: _headerStyle)),
            Expanded(flex: 2, child: Text('ACCOUNT', style: _headerStyle)),
            Expanded(flex: 2, child: Text('AMOUNT', style: _headerStyle)),
            Expanded(flex: 1, child: Text('STATUS', style: _headerStyle)),
            const SizedBox(width: 40), // Spacer for chevron
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

  // ============== 5. TABLE ROW ==============
  Widget _buildTableRow(PaymentVoucher v, int index, Color primary) {
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
                DateFormat.yMMMd().format(DateTime.parse(v.date)),
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(v.partyName, style: const TextStyle(fontSize: 14)),
            ),
            Expanded(
              flex: 2,
              child: Text(
                v.paymentAccount,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '₹${v.amount.toStringAsFixed(2)}',
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

  // ============== 6. MOBILE CARD ==============
  Widget _buildMobileCard(PaymentVoucher v, Color primary) {
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
                    child: Center(
                      child: Icon(Icons.payment_rounded, color: primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.partyName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          v.voucherNumber,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
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
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '₹${v.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
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

// ============== PAYMENT DETAILS DIALOG (Premium Redesign) ==============
class PaymentDetailsDialog extends StatefulWidget {
  final PaymentVoucher voucher;
  final String storeId;

  const PaymentDetailsDialog({
    super.key,
    required this.voucher,
    required this.storeId,
  });

  @override
  State<PaymentDetailsDialog> createState() => _PaymentDetailsDialogState();
}

class _PaymentDetailsDialogState extends State<PaymentDetailsDialog> {
  bool _isLoading = true;
  PaymentDetail? _detail;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final detail = await PaymentService.viewPayment(
        voucherId: widget.voucher.voucherId,
        storeId: widget.storeId,
      );
      if (mounted) {
        setState(() {
          _detail = detail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF2563EB);
    // Use detail data if available, otherwise fallback to voucher data
    final isPosted = _detail?.isPosted ?? widget.voucher.isPosted;
    final amount = _detail?.amount ?? widget.voucher.amount;
    final dateStr = _detail?.date ?? widget.voucher.date;
    final partyName = _detail?.party.name ?? widget.voucher.partyName;
    final partyType = _detail?.party.type ?? widget.voucher.partyType;
    final narration = _detail?.narration ?? widget.voucher.narration;

    // Additional fields from detail
    final financialYear = _detail?.financialYear;
    final voucherType = _detail?.voucherType;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 750),
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
            // Header
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
                          isPosted ? 'POSTED' : 'DRAFT',
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
                    '₹${amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat.yMMMd().format(DateTime.parse(dateStr)),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(child: Text("Error: $_errorMessage"))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader("PARTY DETAILS"),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      partyName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      partyType ?? 'Party',
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
                          const SizedBox(height: 16),

                          const SizedBox(height: 32),

                          _buildSectionHeader("PAYMENT INFORMATION"),
                          const SizedBox(height: 16),
                          // New Fields: Financial Year, Voucher Type, Status
                          if (financialYear != null) ...[
                            _buildInfoRow(
                              "Financial Year",
                              financialYear,
                              Icons.calendar_today_outlined,
                              Colors.blueGrey,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (voucherType != null) ...[
                            _buildInfoRow(
                              "Voucher Type",
                              voucherType,
                              Icons.category_outlined,
                              Colors.purple,
                            ),
                            const SizedBox(height: 16),
                          ],
                          _buildInfoRow(
                            "Status",
                            isPosted ? "Posted" : "Draft",
                            isPosted
                                ? Icons.check_circle_outline
                                : Icons.edit_note,
                            isPosted ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            "Voucher No.",
                            widget.voucher.voucherNumber,
                            Icons.confirmation_number_outlined,
                            themeColor,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            "Account",
                            widget
                                .voucher
                                .paymentAccount, // Keep original or update if in detail
                            Icons.account_balance_wallet_outlined,
                            Colors.orange,
                          ),

                          const SizedBox(height: 32),
                          _buildLedgerEntries(_detail!),

                          if (narration != null && narration.isNotEmpty) ...[
                            const SizedBox(height: 32),
                            _buildSectionHeader("NARRATION"),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey[200]!),
                              ),
                              child: Text(
                                narration,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ],
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

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLedgerEntries(PaymentDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("LEDGER ENTRIES"),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'ACCOUNT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'DEBIT',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'CREDIT',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey[200]),

              // Entries
              ...detail.ledgerEntries.map((entry) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              entry.account,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              entry.debit > 0
                                  ? '₹${entry.debit.toStringAsFixed(2)}'
                                  : '-',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              entry.credit > 0
                                  ? '₹${entry.credit.toStringAsFixed(2)}'
                                  : '-',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (entry != detail.ledgerEntries.last)
                      Divider(height: 1, color: Colors.grey[200]),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
