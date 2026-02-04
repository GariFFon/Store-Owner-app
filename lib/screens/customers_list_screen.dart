import 'dart:async';
import 'package:exanor/screens/customer_details_screen.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class CustomersListScreen extends StatefulWidget {
  final String? storeId;

  const CustomersListScreen({super.key, this.storeId});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
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
  int _returnedCount = 0;
  double _totalOutstanding = 0.0;

  // Sort & Filter
  String _sortBy = 'name';
  String _sortOrder = 'asc';

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
          _errorMessage = "Store ID is required to view customers";
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
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

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
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
        filter: 'customers',
        sortBy: _sortBy,
        sortOrder: _sortOrder,
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
          // Fix: safely parse int from String or int
          _totalCount = int.tryParse(body['count']?.toString() ?? '0') ?? 0;
          _returnedCount =
              int.tryParse(body['returned']?.toString() ?? '0') ?? 0;

          _totalOutstanding = _parties.fold(0.0, (sum, party) {
            return sum +
                (double.tryParse(
                      party['total_outstanding']?.toString() ?? '0',
                    ) ??
                    0.0);
          });

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

  String _formatCurrency(dynamic amount) {
    final value = double.tryParse(amount?.toString() ?? '0') ?? 0;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktopOrTablet = width >= 768;

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
            _buildInteractiveBanner(primaryColor, lightBg, watermarkColor),

            // Search Bar (Conditional)
            if (_isSearchExpanded)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: TextField(
                  controller: _searchController,
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
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => await _fetchParties(),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: _buildStatsSection(
                          isDesktopOrTablet,
                          primaryColor,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    if (isDesktopOrTablet && _parties.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _buildTableHeader(primaryColor),
                      ),
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
                                Icons.people_outline,
                                size: 48,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No customers found",
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
                            (context, index) {
                              if (index == _parties.length) {
                                return _isLoadingMore
                                    ? const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    : const SizedBox.shrink();
                              }
                              return isDesktopOrTablet
                                  ? _buildTableRow(
                                      _parties[index],
                                      index,
                                      primaryColor,
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: _buildMobileCard(
                                        _parties[index],
                                        primaryColor,
                                      ),
                                    );
                            },
                            childCount:
                                _parties.length + (_isLoadingMore ? 1 : 0),
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
          Positioned(
            right: -20,
            top: -10,
            child: Transform.rotate(
              angle: -math.pi / 8,
              child: Icon(
                Icons.supervised_user_circle_rounded,
                size: 200,
                color: watermark.withOpacity(0.6),
              ),
            ),
          ),
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
                            "Customers",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            "Manage Relationships",
                            style: TextStyle(
                              fontSize: 12,
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Sort Button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SORT',
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
                          onTap: () => _showSortOptions(context),
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: Colors.indigo.withOpacity(0.1),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.indigo.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.sort_rounded,
                              size: 24,
                              color: Colors.indigo[400],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Search Button
                    SizedBox(
                      width: 50, // Reduced width since text is small
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
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'SORT CUSTOMERS BY',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                  letterSpacing: 1,
                ),
              ),
            ),
            _buildSortOption('Name (A-Z)', 'name', 'asc'),
            _buildSortOption('Name (Z-A)', 'name', 'desc'),
            _buildSortOption(
              'Outstanding (High to Low)',
              'total_outstanding',
              'desc',
            ),
            _buildSortOption(
              'Outstanding (Low to High)',
              'total_outstanding',
              'asc',
            ),
            _buildSortOption(
              'Recently Created',
              'created_at',
              'desc',
            ), // Assuming created_at exists
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value, String order) {
    final isSelected = _sortBy == value && _sortOrder == order;
    return InkWell(
      onTap: () {
        setState(() {
          _sortBy = value;
          _sortOrder = order;
        });
        Navigator.pop(context);
        _fetchParties();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        color: isSelected ? Colors.blue.withOpacity(0.05) : null,
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? Colors.blue : Colors.grey[400],
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.blue[800] : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(bool isWide, Color primary) {
    final countCard = _buildStatBox(
      "Total Customers",
      _totalCount.toString(),
      Icons.groups,
      Colors.indigo,
    );
    final outstandingCard = _buildStatBox(
      "Total Outstanding",
      _formatCurrency(_totalOutstanding),
      Icons.account_balance_wallet,
      Colors.green,
      isHero: true,
    );
    final showingCard = _buildStatBox(
      "Showing",
      "$_returnedCount / $_totalCount",
      Icons.visibility,
      Colors.orange,
    );
    if (isWide) {
      return Row(
        children: [
          Expanded(child: countCard),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: outstandingCard),
          const SizedBox(width: 16),
          Expanded(child: showingCard),
        ],
      );
    }
    return Column(
      children: [
        SizedBox(width: double.infinity, child: outstandingCard),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: countCard),
            const SizedBox(width: 12),
            Expanded(child: showingCard),
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
            Expanded(flex: 3, child: Text('CUSTOMER', style: _headerStyle)),
            Expanded(flex: 2, child: Text('CONTACT', style: _headerStyle)),
            Expanded(flex: 2, child: Text('LOCATION', style: _headerStyle)),
            Expanded(
              flex: 2,
              child: Text(
                'OUTSTANDING',
                style: _headerStyle,
                textAlign: TextAlign.right,
              ),
            ),
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

  Widget _buildTableRow(dynamic party, int index, Color primary) {
    final isLast = index == _partyCount - 1;
    final outstanding =
        double.tryParse(party['total_outstanding']?.toString() ?? '0') ?? 0.0;

    return GestureDetector(
      onTap: () => _navigateToDetails(party),
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
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, size: 16, color: primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          party['name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (party['is_user'] == true)
                          Text(
                            "USER",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[400],
                              letterSpacing: 0.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    party['phone_number']?.toString() ?? '-',
                    style: const TextStyle(fontSize: 13),
                  ),
                  if (party['email'] != null)
                    Text(
                      party['email'],
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                party['city'] ?? '-',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                _formatCurrency(outstanding),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.green,
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

  Widget _buildMobileCard(dynamic party, Color primary) {
    // ignore: unused_local_variable
    final outstanding =
        double.tryParse(party['total_outstanding']?.toString() ?? '0') ?? 0.0;

    return GestureDetector(
      onTap: () => _navigateToDetails(party),
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
            crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: Center(child: Icon(Icons.person, color: primary)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          party['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        if (party['is_user'] == true)
                          Text(
                            "USER",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[400],
                              letterSpacing: 0.5,
                            ),
                          ),
                        if (party['phone_number'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            party['phone_number'].toString(),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                        if (party['email'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            party['email'].toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                        if (party['city'] != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            party['city'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "OUTSTANDING",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[400],
                        ),
                      ),
                      Text(
                        _formatCurrency(outstanding),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Text(
                          "Details",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: Colors.grey[500],
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

  int get _partyCount => _parties.length;

  void _navigateToDetails(dynamic party) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CustomerDetailsScreen(storeId: _storeId!, customer: party),
      ),
    );
  }
}
