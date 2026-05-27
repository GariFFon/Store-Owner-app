import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/components/translation_widget.dart';
import 'dart:math' as math;
import 'dart:async';

class RackDetailsScreen extends StatefulWidget {
  final String storeId;
  final String rackId;
  final String godownId;
  final String rackName;

  const RackDetailsScreen({
    super.key,
    required this.storeId,
    required this.rackId,
    required this.godownId,
    required this.rackName,
  });

  @override
  State<RackDetailsScreen> createState() => _RackDetailsScreenState();
}

class _RackDetailsScreenState extends State<RackDetailsScreen> {
  bool _isLoading = true;
  List<dynamic> _products = [];
  String? _errorMessage;
  int _currentPage = 1;
  bool _isSearchExpanded = false;
  int _totalCount = 0;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  // Search state
  List<dynamic> _searchProducts = [];
  int _searchPage = 1;
  int _searchTotalCount = 0;
  bool _isSearching = false;
  bool _isSearchLoadingMore = false;
  Timer? _debounceTimer;

  // Colors
  final Color _bg = const Color(0xFFF1F5F9);
  final Color _primary = const Color(0xFF2563EB);
  final Color _textMain = const Color(0xFF1E293B);
  final Color _textSub = const Color(0xFF64748B);

  // Filters State
  String _sortBy = '-purchase_timestamp';
  bool _filter7d = false;
  bool _filterAvailable = false;
  bool _filterLowStock = false;

  bool get _isInSearchMode => _isSearchExpanded && _searchController.text.trim().isNotEmpty;

  List<dynamic> get _displayProducts => _isInSearchMode ? _searchProducts : _products;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    _fetchProducts();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    // Cancel any pending debounce
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      // Cleared search — go back to normal inventory view
      setState(() {
        _searchProducts = [];
        _searchPage = 1;
        _searchTotalCount = 0;
        _isSearching = false;
        _isSearchLoadingMore = false;
      });
      return;
    }

    // Debounce: wait 400ms before firing API
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query, {bool isLoadMore = false}) async {
    if (!isLoadMore) {
      setState(() {
        _isSearching = true;
        _searchPage = 1;
        _searchProducts = [];
      });
    }

    try {
      final data = await StoreOwnerApiService.searchProductInventory(
        widget.storeId,
        query,
        page: _searchPage,
      );

      if (data.containsKey('response') && data['response'] is List) {
        final results = List<dynamic>.from(data['response']);
        final pagination = data['pagination'];

        if (mounted) {
          setState(() {
            if (isLoadMore) {
              _searchProducts.addAll(results);
            } else {
              _searchProducts = results;
            }
            _searchTotalCount = (pagination is Map)
                ? (pagination['total_count'] ?? 0)
                : _searchProducts.length;
            _isSearching = false;
            _isSearchLoadingMore = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            if (!isLoadMore) _searchProducts = [];
            _isSearching = false;
            _isSearchLoadingMore = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _isSearchLoadingMore = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isLoadingMore &&
        !_isSearching &&
        !_isSearchLoadingMore) {
      if (_isInSearchMode) {
        // Paginate search results
        if (_searchProducts.length < _searchTotalCount) {
          _loadMoreSearchResults();
        }
      } else {
        // Paginate normal inventory
        if (_products.length < _totalCount) {
          _loadMoreProducts();
        }
      }
    }
  }

  Future<void> _loadMoreSearchResults() async {
    setState(() {
      _isSearchLoadingMore = true;
      _searchPage++;
    });
    await _performSearch(_searchController.text.trim(), isLoadMore: true);
  }

  Future<void> _loadMoreProducts() async {
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    await _fetchProducts(isLoadMore: true);
  }

  Future<void> _fetchProducts({bool isLoadMore = false}) async {
    if (!isLoadMore) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
      });
    }

    try {
      final data = await StoreOwnerApiService.getProductInventory(
        widget.storeId,
        widget.rackId,
        widget.godownId,
        page: _currentPage,
      );

      if (data.containsKey('response') && data['response'] is List) {
        List<dynamic> products = List<dynamic>.from(data['response']);

        // Client-side filtering
        if (_filter7d) {
          final sevenDaysAgo =
              DateTime.now()
                  .subtract(const Duration(days: 7))
                  .millisecondsSinceEpoch ~/
              1000;
          products = products.where((item) {
            final ts = item['purchase_timestamp'];
            if (ts == null) return false;
            final tsInt = ts is int ? ts : (int.tryParse(ts.toString()) ?? 0);
            return tsInt >= sevenDaysAgo;
          }).toList();
        }

        if (_filterAvailable) {
          products = products.where((item) {
            final stock =
                double.tryParse(item['total_stocks_left']?.toString() ?? '0') ??
                0;
            return stock > 0;
          }).toList();
        }

        if (_filterLowStock) {
          products = products.where((item) {
            final stock =
                double.tryParse(item['total_stocks_left']?.toString() ?? '0') ??
                0;
            return stock > 0 && stock <= 10;
          }).toList();
        }

        // Client-side sorting
        products = _applySorting(products);

        final pagination = data['pagination'];
        setState(() {
          if (isLoadMore) {
            _products.addAll(products);
          } else {
            _products = products;
          }
          _totalCount = (pagination is Map)
              ? (pagination['total_count'] ?? 0)
              : (isLoadMore ? _products.length : products.length);
          _isLoading = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          if (!isLoadMore) {
            _errorMessage = "Failed to load products";
          }
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        if (!isLoadMore) {
          _errorMessage = e.toString();
        }
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  List<dynamic> _applySorting(List<dynamic> products) {
    final bool descending = _sortBy.startsWith('-');
    final String field = descending ? _sortBy.substring(1) : _sortBy;

    products.sort((a, b) {
      dynamic valA;
      dynamic valB;

      if (field == 'purchase_timestamp') {
        valA = a[field] is int
            ? a[field]
            : (int.tryParse(a[field]?.toString() ?? '0') ?? 0);
        valB = b[field] is int
            ? b[field]
            : (int.tryParse(b[field]?.toString() ?? '0') ?? 0);
      } else {
        valA = double.tryParse(a[field]?.toString() ?? '0') ?? 0.0;
        valB = double.tryParse(b[field]?.toString() ?? '0') ?? 0.0;
      }

      final cmp = Comparable.compare(valA as Comparable, valB as Comparable);
      return descending ? -cmp : cmp;
    });

    return products;
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '₹0.00';
    double value = double.tryParse(amount.toString()) ?? 0.0;
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is int) {
      return DateFormat(
        'dd MMM yyyy',
      ).format(DateTime.fromMillisecondsSinceEpoch(timestamp * 1000));
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(
          children: [
            _buildExpandedBanner(),

            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Expanded(
                          child: (_isLoading || _isSearching)
                              ? const Center(child: CircularProgressIndicator())
                              : _errorMessage != null && !_isInSearchMode
                              ? _buildErrorState()
                              : _displayProducts.isEmpty
                              ? ((_isLoadingMore || _isSearchLoadingMore)
                                  ? const Center(child: CircularProgressIndicator()) 
                                  : _buildEmptyState())
                              : RefreshIndicator(
                                  onRefresh: () async {
                                    if (_isInSearchMode) {
                                      await _performSearch(_searchController.text.trim());
                                    } else {
                                      await _fetchProducts();
                                    }
                                  },
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      int crossAxisCount = 1;
                                      if (constraints.maxWidth > 1200) {
                                        crossAxisCount = 3;
                                      } else if (constraints.maxWidth > 700) {
                                        crossAxisCount = 2;
                                      }

                                      final int itemCount = _displayProducts.length +
                                          ((_isLoadingMore || _isSearchLoadingMore) ? 1 : 0);

                                      if (crossAxisCount == 1) {
                                        return ListView.separated(
                                          controller: _scrollController,
                                          padding: const EdgeInsets.all(24),
                                          itemCount: itemCount,
                                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                                          itemBuilder: (context, index) {
                                            if (index == _displayProducts.length) {
                                              return const Padding(
                                                padding: EdgeInsets.symmetric(vertical: 16),
                                                child: Center(child: CircularProgressIndicator()),
                                              );
                                            }
                                            return _buildProductCard(_displayProducts[index]);
                                          },
                                        );
                                      }

                                      return GridView.builder(
                                        controller: _scrollController,
                                        padding: const EdgeInsets.all(24),
                                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: crossAxisCount,
                                          mainAxisSpacing: 16,
                                          crossAxisSpacing: 16,
                                          mainAxisExtent: 260, // adequate height for rack product card without overflow
                                        ),
                                        itemCount: itemCount,
                                        itemBuilder: (context, index) {
                                          if (index == _displayProducts.length) {
                                            return const Padding(
                                              padding: EdgeInsets.symmetric(vertical: 16),
                                              child: Center(child: CircularProgressIndicator()),
                                            );
                                          }
                                          return _buildProductCard(_displayProducts[index]);
                                        },
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedBanner() {
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
                  Icons.inventory_2_outlined,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button
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
                      const SizedBox(width: 12),
                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TranslatedText(
                              widget.rackName,
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
                              child: Text(
                                "$_totalCount ITEMS",
                                style: const TextStyle(
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
                      // Refresh Button
                      SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TranslatedText(
                              'REFRESH',
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
                              onTap: () => _fetchProducts(),
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
                                  Icons.refresh_rounded,
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
                  
                  // Search Bar (Conditional)
                  if (_isSearchExpanded) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search items...',
                        prefixIcon: Icon(Icons.search, color: _primary),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _primary.withOpacity(0.2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _primary.withOpacity(0.2),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  // Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSortButton(),
                        const SizedBox(width: 8),
                        _buildFilterButton(),
                        const SizedBox(width: 8),
                        Container(
                          height: 20,
                          width: 1,
                          color: Colors.black.withOpacity(0.1),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChoice(
                          "7d",
                          isActive: _filter7d,
                          onTap: () {
                            setState(() {
                              _filter7d = !_filter7d;
                              _currentPage = 1;
                            });
                            _fetchProducts();
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChoice(
                          "Available",
                          isActive: _filterAvailable,
                          onTap: () {
                            setState(() {
                              _filterAvailable = !_filterAvailable;
                              _currentPage = 1;
                            });
                            _fetchProducts();
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChoice(
                          "Low Stock",
                          isActive: _filterLowStock,
                          onTap: () {
                            setState(() {
                              _filterLowStock = !_filterLowStock;
                              _currentPage = 1;
                            });
                            _fetchProducts();
                          },
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

  Widget _buildProductCard(dynamic item) {
    final productData = item['product_combination_data'] ?? {};
    final String imgUrl = productData['img_url']?.toString() ?? '';
    final bool hasImage = imgUrl.isNotEmpty;

    final bool isOnline = item['is_accessible_online'] == true || item['is_accessible_online'] == 'true' || item['is_accessible_online'] == 1;
    final bool isPos = item['is_accessible_pos'] == true || item['is_accessible_pos'] == 'true' || item['is_accessible_pos'] == 1;
    final bool isGreyedOut = (!isOnline && !isPos);

    final Color textMain = const Color(0xFF1E293B);
    final Color primary = const Color(0xFF2563EB);
    final Color textSub = const Color(0xFF64748B);

    return InkWell(
      onTap: () => _showEditProductSheet(item),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: isGreyedOut ? Colors.grey.shade200 : const Color(0xFFE2E8F0),
              width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
          child: Column(
            children: [
              // Top Row: Image & Key Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image (Dimmed if offline)
                  Opacity(
                    opacity: isGreyedOut ? 0.4 : 1.0,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: hasImage
                            ? Image.network(
                                imgUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.image_not_supported_rounded,
                                  color: textSub.withOpacity(0.3),
                                ),
                              )
                            : Icon(
                                Icons.image_rounded,
                                color: textSub.withOpacity(0.2),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Title & MRP & Badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                productData['product_name'] ?? 'Unknown Item',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isGreyedOut ? textMain.withOpacity(0.5) : textMain,
                                  height: 1.2,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isGreyedOut)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: const Text(
                                  "OFFLINE",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFDC2626),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "MRP: ${_formatCurrency(item['mrp'])}",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isGreyedOut ? primary.withOpacity(0.5) : primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Visibility Action Bar (Classic Identifiable Switches)
              Row(
                children: [
                  Expanded(
                    child: _buildClassicSwitch("Web", Icons.language_rounded, isOnline, const Color(0xFFF59E0B), (val) {
                      _updateProductAccess(item, val, isPos);
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildClassicSwitch("POS", Icons.point_of_sale_rounded, isPos, const Color(0xFF2563EB), (val) {
                      _updateProductAccess(item, isOnline, val);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Bottom Stats Grid
              Opacity(
                opacity: isGreyedOut ? 0.6 : 1.0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatItem(
                        "Purchased",
                        (double.tryParse(item['total_stocks_purchased']?.toString() ?? '0') ?? 0).toStringAsFixed(1),
                      ),
                      Container(width: 1, height: 24, color: Colors.grey[200]),
                      _buildStatItem(
                        "Sold",
                        (double.tryParse(item['total_stocks_sold']?.toString() ?? '0') ?? 0).toStringAsFixed(1),
                      ),
                      Container(width: 1, height: 24, color: Colors.grey[200]),
                      _buildStatItem(
                        "Returned",
                        (double.tryParse(item['total_stocks_returned']?.toString() ?? '0') ?? 0).toStringAsFixed(1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _textMain,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _textSub,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumChip(IconData icon, String label, {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: _textMain),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _textMain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton() {
    return _buildPremiumChip(
      Icons.sort_rounded,
      "Sort",
      onTap: _showSortOptions,
    );
  }

  Widget _buildFilterButton() {
    return _buildPremiumChip(
      Icons.filter_list_rounded,
      "Filter",
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Advanced filters coming soon!")),
        );
      },
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  "Sort By",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              _buildSortOption("Newest First", "-purchase_timestamp"),
              _buildSortOption("Oldest First", "purchase_timestamp"),
              _buildSortOption(
                "Price: Low to High",
                "selling_amount_excluding_tax",
              ),
              _buildSortOption(
                "Price: High to Low",
                "-selling_amount_excluding_tax",
              ),
              _buildSortOption("Stock: Low to High", "total_stocks_left"),
              _buildSortOption("Stock: High to Low", "-total_stocks_left"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOption(String label, String value) {
    final isSelected = _sortBy == value;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? _primary : _textMain,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: _primary)
          : null,
      onTap: () {
        setState(() {
          _sortBy = value;
          _currentPage = 1;
        });
        Navigator.pop(context);
        _fetchProducts();
      },
    );
  }

  Widget _buildFilterChoice(
    String label, {
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? _primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isActive
              ? _primary.withOpacity(0.2)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? _primary : _textSub,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchController.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off_rounded : Icons.inventory_2_outlined,
            size: 60,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            isSearching ? "No matching products found" : "Rack is Empty",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textSub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 60, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? "Error",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textSub,
            ),
          ),
        ],
      ),
    );
  }

  // --- EDIT SHEET (Revamped & Responsive) ---

  Future<void> _updateProductAccess(
    Map<String, dynamic> item,
    bool isOnline,
    bool isPos,
  ) async {
    bool oldOnline = item['is_accessible_online'] == true || item['is_accessible_online'] == 'true' || item['is_accessible_online'] == 1;
    bool oldPos = item['is_accessible_pos'] == true || item['is_accessible_pos'] == 'true' || item['is_accessible_pos'] == 1;

    setState(() {
      item['is_accessible_online'] = isOnline;
      item['is_accessible_pos'] = isPos;
    });

    try {
      final response = await ApiService.put(
        '/product-inventory/',
        body: {
          "product_inventory_id": item['id'].toString(),
          "store_id": widget.storeId,
          "store_access": true,
          "data": {
            "is_accessible_online": isOnline,
            "is_accessible_pos": isPos,
          },
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200) {
          // Success - already optimistically updated
          return;
        }
      }
      throw Exception('Backend returned error or failed');
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          item['is_accessible_online'] = oldOnline;
          item['is_accessible_pos'] = oldPos;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating access: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEditProductSheet(Map<String, dynamic> item) {
    final productData = item['product_combination_data'] ?? {};

    bool isWebEnabled = item['is_accessible_online'] == true || item['is_accessible_online'] == 'true' || item['is_accessible_online'] == 1;
    bool isPosEnabled = item['is_accessible_pos'] == true || item['is_accessible_pos'] == 'true' || item['is_accessible_pos'] == 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final stockLeft = double.tryParse(item['total_stocks_left']?.toString() ?? '0') ?? 0;
            final purchaseTimestamp = item['purchase_timestamp'];
            final expiryTimestamp = item['expiry_timestamp'];
            final createdTimestamp = item['created_timestamp'] ?? purchaseTimestamp;

            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, controller) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    bool isTablet = constraints.maxWidth > 600;

                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white, // Pure white looks vastly superior
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                        children: [
                          // Top Drag Handle
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(top: 12, bottom: 8),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          
                          // Header (Title + Close)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Row(
                              children: [
                                const Text(
                                  "Product Details",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),

                          // Scrollable Form Content
                          Expanded(
                            child: ListView(
                              controller: controller,
                              padding: const EdgeInsets.all(20),
                              children: [
                                // Main Product Overview
                                _buildMainProductCard(productData, item, stockLeft),
                                const SizedBox(height: 24),

                                // Access Channels (Toggles)
                                _buildAccessSection(
                                  isWebEnabled,
                                  isPosEnabled,
                                  (val) => setSheetState(() => isWebEnabled = val),
                                  (val) => setSheetState(() => isPosEnabled = val),
                                ),
                                const SizedBox(height: 24),

                                if (isTablet) ...[
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            _buildPricingSection(item),
                                            const SizedBox(height: 24),
                                            _buildDateSection(item, purchaseTimestamp, expiryTimestamp, createdTimestamp),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 24),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            _buildStockSection(item, stockLeft),
                                            const SizedBox(height: 24),
                                            _buildAdditionalSection(item),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  _buildPricingSection(item),
                                  const SizedBox(height: 24),
                                  _buildStockSection(item, stockLeft),
                                  const SizedBox(height: 24),
                                  _buildDateSection(item, purchaseTimestamp, expiryTimestamp, createdTimestamp),
                                  const SizedBox(height: 24),
                                  _buildAdditionalSection(item),
                                ],
                              ],
                            ),
                          ),

                          // Footer Buttons
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, -4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: const Text(
                                      "Cancel",
                                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await _updateProductAccess(item, isWebEnabled, isPosEnabled);
                                      if (context.mounted) Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      backgroundColor: const Color(0xFF2563EB),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      "Save Changes",
                                      style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // --- WIDGETS ---

  Widget _buildMainProductCard(Map<String, dynamic> productData, Map<String, dynamic> item, double stockLeft) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              productData['img_url'] ?? '',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.image_not_supported_rounded,
                color: Color(0xFFCBD5E1),
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
                "${productData['product_name']} ${productData['variation_value'] != null ? '- ${productData['variation_value']}' : ''}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildChip(
                    stockLeft > 0 ? "IN STOCK" : "OUT OF STOCK",
                    stockLeft > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    stockLeft > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  ),
                  if (productData['product_type'] != null)
                    _buildChip(
                      productData['product_type'].toString().toUpperCase(),
                      const Color(0xFFDBEAFE),
                      const Color(0xFF2563EB),
                    ),
                  if (item['category_name'] != null)
                    _buildChip(
                      item['category_name'].toString().toUpperCase(),
                      const Color(0xFFF1F5F9),
                      const Color(0xFF475569),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccessSection(bool isWeb, bool isPos, ValueChanged<bool> onWebChange, ValueChanged<bool> onPosChange) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Sales Channels",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildAccessTile(
                "Web Store",
                "Allow customers to order this online",
                Icons.language_rounded,
                const Color(0xFFF59E0B),
                isWeb,
                onWebChange,
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _buildAccessTile(
                "Store POS",
                "Allow sales from the physical register",
                Icons.point_of_sale_rounded,
                const Color(0xFF2563EB),
                isPos,
                onPosChange,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStockSection(Map<String, dynamic> item, double stockLeft) {
    return _buildReceiptSection("Inventory Status", [
      _buildReceiptRow("Total Purchased", _formatNumber(item['total_stocks_purchased'])),
      _buildReceiptRow("Total Sold", _formatNumber(item['total_stocks_sold'])),
      _buildReceiptRow("Returned", _formatNumber(item['total_stocks_returned'])),
      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Color(0xFFE2E8F0))),
      _buildReceiptRow("Currently Available", _formatNumber(stockLeft), valueColor: const Color(0xFF16A34A), isBold: true),
    ]);
  }

  Widget _buildPricingSection(Map<String, dynamic> item) {
    return _buildReceiptSection("Pricing Details", [
      _buildReceiptRow("Cost (Excl. Tax)", _formatCurrency(item['cost_amount_excluding_tax'])),
      _buildReceiptRow("Cost (Incl. Tax)", _formatCurrency(item['cost_amount_including_tax'])),
      _buildReceiptRow("Selling Price", _formatCurrency(item['selling_amount_excluding_tax'])),
      const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Color(0xFFE2E8F0))),
      _buildReceiptRow("Maximum Retail Price", _formatCurrency(item['mrp']), valueColor: const Color(0xFF2563EB), isBold: true),
    ]);
  }

  Widget _buildDateSection(Map<String, dynamic> item, dynamic purchased, dynamic expired, dynamic created) {
    return _buildReceiptSection("Timeline", [
      _buildReceiptRow("Manufactured On", _formatDate(item['manufactured_on_timestamp'])),
      _buildReceiptRow("Purchased On", _formatDate(purchased)),
      if (expired != null) _buildReceiptRow("Expires On", _formatDate(expired), valueColor: const Color(0xFFDC2626)),
      _buildReceiptRow("Created In System", _formatDate(created)),
    ]);
  }

  Widget _buildAdditionalSection(Map<String, dynamic> item) {
    final productData = item['product_combination_data'] ?? {};
    final parentCat = productData['parent_category'];
    final childCat = productData['child_category'];

    String category = 'N/A';
    if (parentCat != null && childCat != null) {
      category = '${_capitalizeFirstLetter(parentCat)} / ${_capitalizeFirstLetter(childCat)}';
    } else if (parentCat != null || childCat != null) {
      category = _capitalizeFirstLetter(parentCat ?? childCat);
    }

    String stateCode = _capitalizeFirstLetter(item['state_code_of_purchase']?.toString());

    return _buildReceiptSection("Extra Information", [
      _buildReceiptRow("State Code", stateCode.isNotEmpty ? stateCode : "N/A"),
      _buildReceiptRow("Category Path", category),
      if (item['hsn_code'] != null) _buildReceiptRow("HSN Code", item['hsn_code'].toString()),
    ]);
  }

  // --- HELPER WIDGETS ---

  Widget _buildReceiptSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptRow(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.bold,
                color: valueColor ?? const Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessTile(String title, String subtitle, IconData icon, Color color, bool value, ValueChanged<bool> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F172A), fontSize: 14),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 24,
              child: Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: color,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: textColor,
        ),
      ),
    );
  }

  String _capitalizeFirstLetter(String? text) {
    if (text == null || text.isEmpty) return '';
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Widget _buildClassicSwitch(String label, IconData icon, bool value, Color activeColor, ValueChanged<bool> onChanged) {
    final Color textSub = const Color(0xFF64748B);
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: value ? activeColor.withOpacity(0.08) : const Color(0xFFF8FAFC),
          border: Border.all(color: value ? activeColor.withOpacity(0.3) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(icon, size: 16, color: value ? activeColor : textSub.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: value ? activeColor : textSub,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 24,
              child: Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: value,
                  onChanged: onChanged,
                  activeColor: activeColor,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return "0.00";
    double val = double.tryParse(value.toString()) ?? 0;
    return val.toStringAsFixed(2);
  }
}
