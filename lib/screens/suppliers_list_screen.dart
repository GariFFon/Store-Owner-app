import 'dart:async';
import 'package:exanor/screens/supplier_report_screen.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  bool _isLoadingMore = false;
  bool _hasNextPage = false;
  int _currentPage = 1;
  String? _errorMessage;
  int _totalCount = 0;
  int _returnedCount = 0;
  double _totalOutstanding =
      0.0; // Calculated from loaded items or fetched if available

  // Sort & Filter
  String _sortBy = 'name';
  String _sortOrder = 'asc'; // 'asc' or 'desc'

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);

    // Resolve store ID after frame build to access context arguments
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
          _errorMessage = "Store ID is required to view suppliers";
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
        if (!isLoadMore) _parties = []; // Clear list on new search/filter
      });
    }

    try {
      final result = await StoreOwnerApiService.getParties(
        _storeId!,
        page: isLoadMore ? _currentPage + 1 : 1,
        filter: 'suppliers',
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
          _totalCount = body['count'] as int? ?? 0;
          _returnedCount = body['returned'] as int? ?? 0;

          // Calculate total outstanding from the current list (approximate if paginated)
          // Ideally backend sends this total. For now, we sum what we have if it's the full list,
          // or just sum displayed.
          // Note: In a real app, "Total Outstanding" usually comes from a separate aggregates API or
          // is a field in the response. The sample response doesn't show a global total.
          // I will sum up the displayed list for demo purposes.
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

  void _toggleSortOrder() {
    setState(() {
      _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
    });
    _fetchParties();
  }

  void _changeSortBy(String value) {
    if (_sortBy == value) {
      _toggleSortOrder();
    } else {
      setState(() {
        _sortBy = value;
        _sortOrder = 'desc'; // Default to desc for new sort ?? Or asc?
        if (value == 'name') _sortOrder = 'asc'; // Names usually asc
      });
      _fetchParties();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light grey background
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            _buildStatsSection(theme),
            Expanded(child: _buildList(theme, isDesktop)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suppliers',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your supplier relationships and track outstanding amounts',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name or GSTIN...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Sort Menu
              PopupMenuButton<String>(
                onSelected: _changeSortBy,
                itemBuilder: (context) => [
                  _buildSortMenuItem('name', 'Sort by Name'),
                  _buildSortMenuItem('outstanding', 'Sort by Outstanding'),
                  _buildSortMenuItem('created', 'Sort by Created'),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _sortOrder == 'asc' ? Icons.sort_by_alpha : Icons.sort,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getSortLabel(),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Clear Button
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged('');
                },
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Clear'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildSortMenuItem(String value, String label) {
    final bool isSelected = _sortBy == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            isSelected
                ? (_sortOrder == 'asc'
                      ? Icons.arrow_upward
                      : Icons.arrow_downward)
                : null,
            size: 16,
            color: isSelected ? Colors.blue : Colors.transparent,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blue : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'outstanding':
        return 'Outstanding';
      case 'created':
        return 'Created';
      case 'name':
      default:
        return 'Name';
    }
  }

  Widget _buildStatsSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _buildStatCard(
            title: 'Total Suppliers',
            value: _totalCount.toString(),
            theme: theme,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            title: 'Total Outstanding',
            value: _formatCurrency(_totalOutstanding),
            valueColor: _totalOutstanding > 0
                ? Colors.red
                : Colors
                      .green[700], // Assuming positive outstanding is bad (payable)
            // Wait, user sample has negative outstanding.
            // "total_outstanding": -159.96.
            // If I owe them, it's usually positive in AP. If negative, maybe they owe me?
            // Or maybe negative means I owe them?
            // "total_credit": 159.96.
            // Let's stick to the color in the image.
            // The image shows "-624589.79" in ORANGE/RED.
            // So negative is emphasized.
            theme: theme,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              title: 'Showing',
              value: '$_returnedCount / $_totalCount',
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    Color? valueColor,
    required ThemeData theme,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ThemeData theme, bool isDesktop) {
    if (_isLoading && _parties.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _parties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.orange),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchParties(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_parties.isEmpty) {
      return const Center(child: Text("No suppliers found."));
    }

    return Column(
      children: [
        if (isDesktop) _buildTableHeader(theme),
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: _parties.length + (_isLoadingMore ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == _parties.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final party = _parties[index];
              return _buildClickableItem(
                party: party,
                child: isDesktop
                    ? _buildDesktopListItem(party, theme)
                    : _buildMobileListItem(party, theme),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 3, child: _tableHeader('Supplier')),
          Expanded(flex: 2, child: _tableHeader('Contact')),
          Expanded(flex: 2, child: _tableHeader('Location')),
          Expanded(flex: 1, child: _tableHeader('GSTIN')),
          Expanded(
            flex: 1,
            child: _tableHeader('Outstanding', align: TextAlign.right),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text, {TextAlign align = TextAlign.left}) {
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        color: Colors.grey[600],
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    );
  }

  Widget _buildDesktopListItem(dynamic party, ThemeData theme) {
    final outstanding =
        double.tryParse(party['total_outstanding']?.toString() ?? '0') ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Supplier
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.store, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        party['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        party['party_type'] ?? 'STORE',
                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Contact
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (party['phone_number'] != null)
                  Row(
                    children: [
                      Icon(Icons.phone, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        '${party['phone_number']}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                if (party['email'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.email, size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${party['email']}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Location
          Expanded(
            flex: 2,
            child: (party['city'] != null || party['state'] != null)
                ? Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        [party['city'], party['state']]
                            .where((e) => e != null && e.toString().isNotEmpty)
                            .join(', '),
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  )
                : const SizedBox(),
          ),

          // GSTIN
          Expanded(
            flex: 1,
            child: Text(
              party['gstin'] ?? 'N/A',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),

          // Outstanding
          Expanded(
            flex: 1,
            child: Text(
              _formatCurrency(outstanding),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: outstanding != 0
                    ? (outstanding < 0
                          ? const Color(0xFFD32F2F)
                          : Colors.orange[800]) // Match image for negative
                    : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileListItem(dynamic party, ThemeData theme) {
    final outstanding =
        double.tryParse(party['total_outstanding']?.toString() ?? '0') ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.store, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          party['party_type'] ?? 'STORE',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatCurrency(outstanding),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: outstanding != 0
                                ? (outstanding < 0
                                      ? const Color(0xFFD32F2F)
                                      : Colors.orange[800])
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),

          // Details Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    if (party['phone_number'] != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 14,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${party['phone_number']}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (party['city'] != null)
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${party['city']}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (party['email'] != null)
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.email, size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${party['email']}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClickableItem({required Widget child, required dynamic party}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_storeId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SupplierReportScreen(storeId: _storeId!, supplier: party),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}
