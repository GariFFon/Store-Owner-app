import 'dart:async';
import 'package:exanor/screens/create_supplier_bottom_sheet.dart';
import 'package:exanor/screens/supplier_report_screen.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class SuppliersListScreen extends StatefulWidget {
  final String? storeId;

  const SuppliersListScreen({super.key, this.storeId});

  @override
  State<SuppliersListScreen> createState() => _SuppliersListScreenState();
}

class _SuppliersListScreenState extends State<SuppliersListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  String? _storeId;
  List<dynamic> _parties = [];
  bool _isLoading = true;
  bool _isSearchExpanded = false;
  bool _isLoadingMore = false;
  bool _hasNextPage = false;
  int _currentPage = 1;
  String? _errorMessage;
  int _totalCount = 0;
  double _totalOutstanding = 0.0;

  // Filter State
  String _activeFilter = 'All';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveStoreId();
    });
  }

  void _resolveStoreId() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final id = widget.storeId ?? args?['storeId'];

    if (id != null) {
      if (mounted) {
        setState(() {
          _storeId = id;
        });
        _fetchParties();
      }
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = "Store ID is required";
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasNextPage) {
      _fetchParties(isLoadMore: true);
    }
  }

  /// After data loads, check if content fills the viewport.
  /// If not and there's more data, auto-load the next page.
  void _loadUntilScrollable() {
    if (!mounted || !_hasNextPage || _isLoadingMore || _isLoading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0 && _hasNextPage && !_isLoadingMore) {
        _fetchParties(isLoadMore: true);
      }
    });
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchParties();
    });
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _activeFilter = filter;
      _fetchParties();
    });
  }

  Future<void> _fetchParties({bool isLoadMore = false}) async {
    if (_storeId == null) return;

    if (isLoadMore) {
      if (_isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        if (!isLoadMore) _parties = [];
      });
    }

    try {
      final result = await StoreOwnerApiService.getParties(
        _storeId!,
        page: isLoadMore ? _currentPage + 1 : 1,
        filter: 'suppliers',
        searchQuery: _searchController.text,
      );

      final body = result['body'] ?? {};
      final parties = body['parties'] as List<dynamic>? ?? [];
      final pagination = body['pagination'] as Map<String, dynamic>? ?? {};

      if (mounted) {
        setState(() {
          if (isLoadMore) {
            _parties.addAll(parties);
            _currentPage++;
          } else {
            _parties = parties;
            _currentPage = 1;
          }

          _hasNextPage = pagination['has_next'] == true;
          _totalCount = body['count'] as int? ?? 0;

          _totalOutstanding = _parties.fold(0.0, (sum, party) {
            return sum +
                (double.tryParse(
                      party['total_outstanding']?.toString() ?? '0',
                    ) ??
                    0.0);
          });

          if (_activeFilter == 'Outstanding') {
            _parties = _parties.where((p) {
              final out =
                  double.tryParse(p['total_outstanding'].toString()) ?? 0;
              return out != 0;
            }).toList();
          } else if (_activeFilter == 'Settled') {
            _parties = _parties.where((p) {
              final out =
                  double.tryParse(p['total_outstanding'].toString()) ?? 0;
              return out == 0;
            }).toList();
          }

          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = null;
        });
        _loadUntilScrollable();
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

  String _formatCurrency(dynamic amount) {
    final value = double.tryParse(amount?.toString() ?? '0') ?? 0;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    // Theme: Back to Blue
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

            // 2. Search Bar (Conditional)
            if (_isSearchExpanded)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name, GSTIN...',
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

            // 2. Main Scroll View
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _fetchParties(),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Stats Section (Refined Layout)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: _buildStatsSection(isDesktop, primaryColor),
                      ),
                    ),

                    // Filter Segments
                    SliverToBoxAdapter(
                      child: _buildFilterSegments(primaryColor),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Table Header for Desktop
                    if (isDesktop && _parties.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _buildTableHeader(primaryColor),
                      ),

                    // Suppliers List / Table Rows
                    if (_isLoading && _parties.isEmpty)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_errorMessage != null && _parties.isEmpty)
                      SliverFillRemaining(
                        child: Center(child: Text(_errorMessage!)),
                      )
                    else if (_parties.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_off_outlined,
                                size: 48,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No suppliers found",
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
                        padding: isDesktop
                            ? EdgeInsets.zero
                            : const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => isDesktop
                                ? _buildSupplierTableRow(
                                    _parties[index],
                                    index,
                                    primaryColor,
                                  )
                                : Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _buildSupplierCard(
                                      _parties[index],
                                      primaryColor,
                                    ),
                                  ),
                            childCount: _parties.length,
                          ),
                        ),
                      ),

                    if (_isLoadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
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

  // ============== 1. HEADER ==============
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
                Icons.local_shipping_rounded,
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
                            "Suppliers",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "Network & Outstanding",
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
                                  _fetchParties();
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
                    const SizedBox(width: 8),
                    // Action Button
                    // Action Button
                    SizedBox(
                      width: 70,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'NEW',
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
                            onTap: () async {
                              if (_storeId == null) return;
                              final result = await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => CreateSupplierBottomSheet(
                                  storeId: _storeId!,
                                ),
                              );

                              if (result == true) {
                                _fetchParties();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primary,
                                border: Border.all(
                                  color: Colors.transparent,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                size: 24,
                                color: Colors.white,
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

  // ============== 2. STATS SECTION (Symmetric Layout) ==============
  Widget _buildStatsSection(bool isDesktop, Color primary) {
    // Mobile Layout:
    // [ Suppliers (Expanded) ] [ Active (Expanded) ]
    // [ Outstanding (Full Width)                   ]

    final supplierCard = _buildStatBox(
      "Suppliers",
      _totalCount.toString(),
      Icons.store_rounded,
      Colors.blue,
    );

    final activeCard = _buildStatBox(
      "Active",
      _parties.length.toString(),
      Icons.verified_rounded,
      Colors.green,
    );

    final outstandingCard = _buildStatBox(
      "Total Outstanding",
      "${_formatCurrency(_totalOutstanding.abs())}${_totalOutstanding == 0 ? '' : (_totalOutstanding > 0 ? ' Cr' : ' Dr')}",
      Icons.account_balance_wallet_rounded,
      Colors.orange,
      isCurrency: true,
      valueColor: _totalOutstanding != 0
          ? (_totalOutstanding < 0 ? Colors.red : primary)
          : null,
      isHero: true,
    );

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: supplierCard),
          const SizedBox(width: 16),
          Expanded(child: activeCard),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: outstandingCard),
        ],
      );
    }

    // Mobile: Symmetric Grid logic
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: supplierCard),
            const SizedBox(width: 12),
            Expanded(child: activeCard),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: outstandingCard),
      ],
    );
  }

  Widget _buildStatBox(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isCurrency = false,
    Color? valueColor,
    bool isHero = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: isHero ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHero
              ? checkColor(valueColor ?? color).withOpacity(0.2)
              : Colors.grey[100]!,
        ),
        boxShadow: [
          BoxShadow(
            color: (valueColor ?? color).withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: isHero
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.start,
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
              fontSize: isCurrency ? 22 : 20,
              fontWeight: FontWeight.w800,
              color: valueColor ?? const Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color checkColor(Color c) => c;

  // ============== 3. FILTER SEGMENTS ==============
  Widget _buildFilterSegments(Color primary) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildFilterChip("View All", _activeFilter == 'All', primary),
          const SizedBox(width: 10),
          _buildFilterChip(
            "Outstanding Due",
            _activeFilter == 'Outstanding',
            Colors.red,
          ),
          const SizedBox(width: 10),
          _buildFilterChip("Settled", _activeFilter == 'Settled', Colors.green),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isActive, Color color) {
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: (val) => _onFilterChanged(
        isActive
            ? 'All'
            : (label == "Outstanding Due"
                  ? "Outstanding"
                  : (label == "Settled" ? "Settled" : "All")),
      ),
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
  // ============== 4. TABLE HEADER (Desktop) ==============
  Widget _buildTableHeader(Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(
            top: BorderSide(color: Colors.grey[200]!),
            left: BorderSide(color: Colors.grey[200]!),
            right: BorderSide(color: Colors.grey[200]!),
            bottom: BorderSide(color: Colors.grey[100]!),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Text(
                'SUPPLIER',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Colors.grey[500],
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'CONTACT',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Colors.grey[500],
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                'LOCATION',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Colors.grey[500],
                  letterSpacing: 1.0,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                'OUTSTANDING',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Colors.grey[500],
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 48), // Match row arrow padding
          ],
        ),
      ),
    );
  }

  // ============== 5. SUPPLIER TABLE ROW (Desktop) ==============
  Widget _buildSupplierTableRow(dynamic party, int index, Color primary) {
    final outstanding =
        double.tryParse(party['total_outstanding']?.toString() ?? '0') ?? 0.0;
    final name = party['name'] ?? 'Unknown';
    final city = party['city'] ?? '-';
    final phone = party['phone_number'] ?? '-';
    final isLast = index == _parties.length - 1;

    return GestureDetector(
      onTap: () => _navigateToReport(party),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
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
            // Name
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        name.toString().substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      ((party['gstin'] ?? party['supplier_gst_in']) != null &&
                              (party['gstin'] ?? party['supplier_gst_in'])
                                  .toString()
                                  .isNotEmpty)
                          ? (party['gstin'] ?? party['supplier_gst_in'])
                                .toString()
                          : 'N/A',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color:
                            ((party['gstin'] ?? party['supplier_gst_in']) !=
                                    null &&
                                (party['gstin'] ?? party['supplier_gst_in'])
                                    .toString()
                                    .isNotEmpty)
                            ? Colors.grey[600]
                            : Colors.grey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Phone
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    phone.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (party['email'] != null &&
                      party['email'].toString().isNotEmpty)
                    Text(
                      party['email'],
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Location
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    city.toString(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (party['state'] != null &&
                      party['state'].toString().isNotEmpty)
                    Text(
                      party['state'],
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                ],
              ),
            ),
            // Outstanding
            Expanded(
              flex: 3,
              child: Text(
                "${_formatCurrency(outstanding.abs())}${outstanding == 0 ? '' : (outstanding > 0 ? ' Cr' : ' Dr')}",
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: outstanding == 0
                      ? const Color(0xFF64748B)
                      : (outstanding > 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A)),
                  letterSpacing: -0.5,
                ),
              ),
            ),
            // Arrow
            SizedBox(
              width: 48,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============== 6. SUPPLIER CARD (Mobile - Refined) ==============
  Widget _buildSupplierCard(dynamic party, Color primary) {
    final outstanding =
        double.tryParse(party['total_outstanding']?.toString() ?? '0') ?? 0.0;
    final name = party['name'] ?? 'Unknown';
    final city = party['city'];
    final phone = party['phone_number'];

    return GestureDetector(
      onTap: () => _navigateToReport(party),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04), // Softer, cleaner shadow
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Identity (Simpler, Cleaner)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        name.toString().substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (city != null)
                          Text(
                            "$city${party['state'] != null ? ', ${party['state']}' : ''}",
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
              Divider(height: 1, color: Colors.grey[100]),
              const SizedBox(height: 16),

              // Row 2: Contact Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "PHONE",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          phone?.toString() ?? "-",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (party['email'] != null &&
                      party['email'].toString().isNotEmpty)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "EMAIL",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[400],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            party['email'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Row 3: Financials & Tax (GSTIN left, Outstanding Right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "GSTIN",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            ((party['gstin'] ?? party['supplier_gst_in']) !=
                                        null &&
                                    (party['gstin'] ?? party['supplier_gst_in'])
                                        .toString()
                                        .isNotEmpty)
                                ? (party['gstin'] ?? party['supplier_gst_in'])
                                      .toString()
                                : 'N/A',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color:
                                  ((party['gstin'] ??
                                              party['supplier_gst_in']) !=
                                          null &&
                                      (party['gstin'] ??
                                              party['supplier_gst_in'])
                                          .toString()
                                          .isNotEmpty)
                                  ? Colors.grey[700]
                                  : Colors.grey[400],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "OUTSTANDING",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${_formatCurrency(outstanding.abs())}${outstanding == 0 ? '' : (outstanding > 0 ? ' Cr' : ' Dr')}",
                          style: TextStyle(
                            fontSize: 16,
                            color: outstanding != 0 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  void _navigateToReport(dynamic party) {
    if (_storeId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SupplierReportScreen(
            storeId: _storeId!,
            supplier: Map<String, dynamic>.from(party),
          ),
        ),
      );
    }
  }
}
