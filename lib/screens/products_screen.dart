import 'dart:async';
import 'dart:ui';
import 'package:exanor/components/custom_cached_network_image.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/screens/product_detail_screen.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';

class ProductsScreen extends StatefulWidget {
  final String storeId;
  final String? storeName;
  final VoidCallback? onMenuPressed;

  const ProductsScreen({
    super.key,
    required this.storeId,
    this.storeName,
    this.onMenuPressed,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  // ── Listing state ─────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _pageLimit = 10;
  String? _errorMessage;

  // ── Search state ──────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  String _activeQuery = ''; // the query whose results are currently shown
  bool _isSearchMode = false;
  bool _isSearching = false; // true while search API is in-flight
  bool _isSearchLoadingMore = false;
  bool _hasMoreSearch = false;
  int _searchPage = 1;
  final List<Map<String, dynamic>> _searchResults = [];

  // ── Scroll ────────────────────────────────────────────────────────────────
  final ScrollController _scrollController = ScrollController();

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _setupScrollListener();
    _fetchProducts(reset: true);

    _searchController.addListener(() {
      // Show/hide clear button reactively
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // ── Scroll listener ───────────────────────────────────────────────────────
  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 300) {
        if (_isSearchMode) {
          if (!_isSearchLoadingMore && _hasMoreSearch && !_isSearching) {
            _loadMoreSearch();
          }
        } else {
          if (!_isLoadingMore && _hasMore && !_isLoading) {
            _fetchMore();
          }
        }
      }
    });
  }

  // ── Listing API ───────────────────────────────────────────────────────────
  Future<void> _fetchProducts({bool reset = false}) async {
    if (_isLoading || _isLoadingMore) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (reset) {
        _products.clear();
        _currentPage = 1;
        _hasMore = true;
      }
    });

    try {
      final response = await ApiService.post(
        '/show-my-store-products-combinations/',
        body: {
          'store_id': widget.storeId,
          'store_access': true,
          'page': _currentPage,
          'limit': _pageLimit,
        },
        useBearerToken: true,
      );

      if (!mounted) return;

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          final newItems = List<Map<String, dynamic>>.from(data['response']);
          final pagination = data['pagination'];
          final hasNext = pagination?['has_next'] ?? false;

          setState(() {
            _products.addAll(newItems);
            _hasMore = hasNext;
            _isLoading = false;
          });
          _autoFillViewportIfNeeded();
        } else {
          setState(() {
            _isLoading = false;
            if (_products.isEmpty) _errorMessage = 'No products found.';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load products. Please retry.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  Future<void> _fetchMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage++;

    try {
      final response = await ApiService.post(
        '/show-my-store-products-combinations/',
        body: {
          'store_id': widget.storeId,
          'store_access': true,
          'page': _currentPage,
          'limit': _pageLimit,
        },
        useBearerToken: true,
      );

      if (!mounted) return;
      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          final newItems = List<Map<String, dynamic>>.from(data['response']);
          final hasNext = data['pagination']?['has_next'] ?? false;
          setState(() {
            _products.addAll(newItems);
            _hasMore = hasNext;
            _isLoadingMore = false;
          });
        } else {
          setState(() {
            _hasMore = false;
            _isLoadingMore = false;
          });
        }
      } else {
        setState(() => _isLoadingMore = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _currentPage--;
      });
    }
  }

  void _autoFillViewportIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.maxScrollExtent <= 0 && _hasMore && !_isLoadingMore) {
        _fetchMore();
      }
    });
  }

  // ── Search API ────────────────────────────────────────────────────────────

  /// Called on every text change — debounces the API call by 400 ms.
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      // User cleared the field → exit search mode
      _exitSearchMode();
      return;
    }

    // Immediately show the "searching..." skeleton if switching into search mode
    if (!_isSearchMode) {
      setState(() {
        _isSearchMode = true;
        _isSearching = true;
        _searchResults.clear();
        _searchPage = 1;
        _hasMoreSearch = false;
        _activeQuery = trimmed;
      });
    }

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _searchController.text.trim().isNotEmpty) {
        _runSearch(query: _searchController.text.trim(), reset: true);
      }
    });
  }

  /// Runs the search API call. If [reset] is true, clears previous results.
  Future<void> _runSearch({required String query, bool reset = false}) async {
    if (query.isEmpty) return;

    if (reset) {
      setState(() {
        _isSearching = true;
        _isSearchLoadingMore = false;
        _searchResults.clear();
        _searchPage = 1;
        _hasMoreSearch = false;
        _activeQuery = query;
      });
    }

    try {
      final response = await ApiService.post(
        '/search-product-combinations/',
        body: {
          'store_id': widget.storeId,
          'store_access': true,
          'query': query,
          'page': _searchPage,
        },
        useBearerToken: true,
      );

      if (!mounted) return;

      // Discard stale results if user typed something new in the meantime
      if (query != _activeQuery) return;

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          final items = List<Map<String, dynamic>>.from(data['response']);
          final hasNext = data['pagination']?['has_next'] ?? false;
          setState(() {
            if (reset) {
              _searchResults
                ..clear()
                ..addAll(items);
            } else {
              _searchResults.addAll(items);
            }
            _hasMoreSearch = hasNext;
            _isSearching = false;
            _isSearchLoadingMore = false;
          });
        } else {
          setState(() {
            if (reset) _searchResults.clear();
            _hasMoreSearch = false;
            _isSearching = false;
            _isSearchLoadingMore = false;
          });
        }
      } else {
        setState(() {
          _isSearching = false;
          _isSearchLoadingMore = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _isSearchLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreSearch() async {
    if (_isSearchLoadingMore || !_hasMoreSearch) return;
    setState(() => _isSearchLoadingMore = true);
    _searchPage++;
    await _runSearch(query: _activeQuery);
  }

  void _exitSearchMode() {
    _searchDebounce?.cancel();
    setState(() {
      _isSearchMode = false;
      _isSearching = false;
      _isSearchLoadingMore = false;
      _searchResults.clear();
      _searchPage = 1;
      _activeQuery = '';
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _exitSearchMode();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(theme),
          _buildSearchBar(),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(ThemeData theme) {
    final String badge;
    if (_isSearchMode) {
      badge = _activeQuery.isEmpty ? 'Searching…' : '"$_activeQuery"';
    } else if (_hasMore) {
      badge = 'Page $_currentPage';
    } else {
      badge = '${_products.length} products';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            12, MediaQuery.of(context).padding.top + 8, 12, 12),
        child: Row(
          children: [
            // Back button
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
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
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.blueGrey,
                    size: 26,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),
              ],
            ),
            const SizedBox(width: 12),

            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      key: ValueKey(badge),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isSearchMode
                            ? Colors.indigo.withValues(alpha: 0.1)
                            : Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _isSearchMode
                              ? Colors.indigo.withValues(alpha: 0.3)
                              : Colors.blue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _isSearchMode
                              ? Colors.indigo[700]
                              : Colors.blue[800],
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Refresh (only in listing mode)
            if (!_isSearchMode)
              IconButton(
                icon: Icon(Icons.refresh_rounded,
                    color: Colors.blueGrey[600], size: 24),
                onPressed: () => _fetchProducts(reset: true),
                tooltip: 'Refresh',
              ),
          ],
        ),
      ),
    );
  }

  // ── Search bar + Add Product button ───────────────────────────────────────
  Widget _buildSearchBar() {
    final bool hasText = _searchController.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: _isSearchMode
                      ? Colors.indigo.withValues(alpha: 0.4)
                      : Colors.grey[200]!,
                  width: _isSearchMode ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Search icon / spinner
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _isSearching
                          ? const SizedBox(
                              key: ValueKey('spinner'),
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF1565C0)),
                              ),
                            )
                          : const Icon(
                              key: ValueKey('icon'),
                              Icons.search_rounded,
                              color: Color(0xFF1565C0),
                              size: 20,
                            ),
                    ),
                  ),

                  // Text field
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  // Clear button
                  if (hasText)
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 18, color: Colors.grey),
                      onPressed: _clearSearch,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    )
                  else
                    const SizedBox(width: 8),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Add Product button
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                barrierColor: Colors.black.withValues(alpha: 0.3),
                builder: (_) => _AddProductDialog(storeId: widget.storeId),
              );
            },
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'Add Product',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
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

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody(ThemeData theme) {
    if (_isSearchMode) {
      return _buildSearchBody(theme);
    }
    return _buildListingBody(theme);
  }

  // ── Listing mode body ─────────────────────────────────────────────────────
  Widget _buildListingBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _products.isEmpty) {
      return _buildErrorState(_errorMessage!, () => _fetchProducts(reset: true));
    }

    if (_products.isEmpty) {
      return _buildEmptyState('No products found', null);
    }

    final itemCount = _products.length +
        (_isLoadingMore ? 1 : 0) +
        (!_isLoadingMore && !_hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: () => _fetchProducts(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index == _products.length) {
            if (_isLoadingMore) return _buildLoadingMoreCell();
            return _buildEndOfListCell(_products.length);
          }
          return _buildProductCard(_products[index], theme);
        },
      ),
    );
  }

  // ── Search mode body ──────────────────────────────────────────────────────
  Widget _buildSearchBody(ThemeData theme) {
    // Still typing — show inline skeleton
    if (_isSearching && _searchResults.isEmpty) {
      return _buildSearchSkeleton();
    }

    if (!_isSearching && _searchResults.isEmpty) {
      return _buildEmptyState(
          'No results for "$_activeQuery"',
          'Try a different keyword');
    }

    final itemCount = _searchResults.length +
        (_isSearchLoadingMore ? 1 : 0) +
        (!_isSearchLoadingMore && !_hasMoreSearch ? 1 : 0);

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == _searchResults.length) {
          if (_isSearchLoadingMore) return _buildLoadingMoreCell();
          return _buildEndOfListCell(_searchResults.length,
              label: 'result');
        }
        return _buildProductCard(_searchResults[index], theme);
      },
    );
  }

  // ── Common cells ──────────────────────────────────────────────────────────
  Widget _buildLoadingMoreCell() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
          child: CircularProgressIndicator(strokeWidth: 2.5)),
    );
  }

  Widget _buildEndOfListCell(int count, {String label = 'product'}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          '$count ${count == 1 ? label : '${label}s'} loaded',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const TranslatedText('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String? subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 60, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
                color: Colors.grey[700],
                fontSize: 15,
                fontWeight: FontWeight.w600),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style:
                  TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  /// Shimmer-style skeleton shown while the first search page is loading.
  Widget _buildSearchSkeleton() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Row(
            children: [
              // Image placeholder
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _shimmerBox(width: double.infinity, height: 14),
                    const SizedBox(height: 8),
                    _shimmerBox(width: 140, height: 11),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _shimmerBox(width: 80, height: 11),
                        const SizedBox(width: 8),
                        _shimmerBox(width: 70, height: 11),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _shimmerBox(width: 85, height: 20),
                        const SizedBox(width: 6),
                        _shimmerBox(width: 80, height: 20),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  // ── Product card ──────────────────────────────────────────────────────────
  Widget _buildProductCard(Map<String, dynamic> product, ThemeData theme) {
    final name = product['product_name'] ?? 'Unknown Product';
    final parentCat = _capitalize(product['parent_category'] ?? '');
    final childCat = _capitalize(product['child_category'] ?? '');
    final categoryLabel = [parentCat, childCat]
        .where((s) => s.isNotEmpty && s.toLowerCase() != 'undefined')
        .join(' › ');

    final imgUrl = product['img_url'] as String?;
    final isPosEnabled = product['is_accessible_pos'] == true;
    final isOnline = product['is_accessible_online'] == true;
    final status = product['status'] as String?;
    final totalLeft =
        (product['total_left'] as num?)?.toDouble() ?? 0.0;
    final totalSold =
        (product['total_sold'] as num?)?.toDouble() ?? 0.0;
    final brandName = product['brand_name'] as String?;
    final showBrand = brandName != null &&
        brandName.isNotEmpty &&
        brandName.toLowerCase() != 'undefined';

    final bool hasImage = imgUrl != null && imgUrl.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(
                  storeId: widget.storeId,
                  productId: product['id'] as String,
                  initialData: product,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CustomCachedNetworkImage(
                      imgUrl: imgUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.inventory_2_outlined,
                        color: Colors.grey[400], size: 28),
                  ),
                const SizedBox(width: 14),

                // Info column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Category / Brand
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          if (categoryLabel.isNotEmpty)
                            Text(
                              categoryLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (showBrand)
                            Text(
                              '• $brandName',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blueGrey[400],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Stock + Sales
                      Row(
                        children: [
                          _statChip(
                            icon: Icons.inventory_rounded,
                            label:
                                '${totalLeft.toStringAsFixed(0)} in stock',
                            color: totalLeft > 0
                                ? const Color(0xFF0891B2)
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          _statChip(
                            icon: Icons.shopping_cart_outlined,
                            label:
                                'Sales: ${totalSold.toStringAsFixed(0)}',
                            color: Colors.orange[700]!,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Badges
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _badge(
                            label: isPosEnabled
                                ? 'POS Enabled'
                                : 'POS Disabled',
                            color: isPosEnabled
                                ? Colors.green
                                : Colors.red,
                          ),
                          _badge(
                            label: isOnline
                                ? 'Online Access'
                                : 'No Online',
                            color: isOnline
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          if (status != null)
                            _badge(
                              label: _capitalize(status),
                              color: _statusColor(status),
                              outlined: true,
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
      ),
    );
  }

  // ── Small widgets ─────────────────────────────────────────────────────────
  Widget _statChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  Widget _badge({
    required String label,
    required Color color,
    bool outlined = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: outlined
            ? Colors.transparent
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border:
            outlined ? Border.all(color: color.withValues(alpha: 0.5)) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Add Product Dialog  — blur backdrop, template search, Add to Store button
// ════════════════════════════════════════════════════════════════════════════
class _AddProductDialog extends StatefulWidget {
  final String storeId;
  const _AddProductDialog({required this.storeId});

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _lastQuery = '';

  // ── Pagination ───────────────────────────────────────
  int _currentPage = 1;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  // tracks which template IDs are "adding" (in-flight)
  final Set<String> _addingIds = {};
  // tracks successfully added IDs
  final Set<String> _addedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 200 &&
          _hasMore &&
          !_isLoadingMore &&
          !_isSearching) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _lastQuery = q;
      _results = [];
      _currentPage = 1;
      _hasMore = false;
      _isLoadingMore = false;
    });
    try {
      final resp =
          await StoreOwnerApiService.searchProductCombinationTemplates(
        storeId: widget.storeId,
        query: q,
        page: 1,
      );
      if (!mounted) return;
      final items = resp['response'];
      final pagination = resp['pagination'] as Map? ?? {};
      setState(() {
        _results = items != null
            ? List<Map<String, dynamic>>.from(items)
            : [];
        _hasMore = pagination['has_next'] == true;
        _currentPage = 1;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isSearching) return;
    setState(() => _isLoadingMore = true);
    final nextPage = _currentPage + 1;
    try {
      final resp =
          await StoreOwnerApiService.searchProductCombinationTemplates(
        storeId: widget.storeId,
        query: _lastQuery,
        page: nextPage,
      );
      if (!mounted) return;
      final items = resp['response'];
      final pagination = resp['pagination'] as Map? ?? {};
      setState(() {
        if (items != null) {
          _results.addAll(List<Map<String, dynamic>>.from(items));
        }
        _hasMore = pagination['has_next'] == true;
        _currentPage = nextPage;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _addToStore(Map<String, dynamic> template) async {
    final id = template['id'] as String;
    setState(() => _addingIds.add(id));
    try {
      final resp = await StoreOwnerApiService.createProductFromTemplate(
        storeId: widget.storeId,
        productCombinationTemplateId: id,
      );
      if (!mounted) return;
      final status = resp['status'];
      if (status == 200) {
        final name = resp['response']?['product_name'] ?? 'Product';
        setState(() => _addedIds.add(id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ "$name" added to your store'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        _showError('Failed to add product. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _addingIds.remove(id));
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Use AnimatedPadding + viewInsets — the only reliable Flutter pattern
    // that makes an overlay shrink when the keyboard appears.
    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets;
    final screenHeight = mq.size.height;
    // Space available above the keyboard, minus status bar, nav bar, and dialog margins
    final availableHeight = screenHeight
        - viewInsets.bottom
        - mq.padding.top
        - mq.padding.bottom
        - 96; // 40 top margin + 40 bottom margin + 16 extra breathing room
    final resultsMaxHeight =
        (availableHeight - 64 - 80 - 32).clamp(80.0, screenHeight);


    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: AnimatedPadding(
        // This is the key: bottom padding = keyboard height → dialog slides up
        padding: viewInsets + const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        duration: const Duration(milliseconds: 100),
        curve: Curves.decelerate,
        child: MediaQuery.removeViewInsets(
          // Remove viewInsets from the subtree so children don't double-count
          removeLeft: true,
          removeTop: true,
          removeRight: true,
          removeBottom: true,
          context: context,
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(maxHeight: availableHeight),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ──────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E40AF), Color(0xFF2563EB)],
                        ),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add_box_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Add Product to Store',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.white70, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // ── Search field ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _search,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Type product name & press Enter…',
                          hintStyle: TextStyle(
                              color: Colors.grey[400], fontSize: 13),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF2563EB),
                            size: 20,
                          ),
                          suffixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Color(0xFF2563EB)),
                                    ),
                                  ),
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF2563EB), width: 1.5),
                          ),
                        ),
                      ),
                    ),

                    // ── Results ─────────────────────────────────────────────
                    if (!_hasSearched)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Text(
                          'Search the global product catalogue and add items directly to your store.',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      )
                    else if (_isSearching)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF2563EB)),
                        ),
                      )
                    else if (_results.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        child: Column(
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 40, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text(
                              'No products found for "$_lastQuery"',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints:
                            BoxConstraints(maxHeight: resultsMaxHeight),
                        child: ListView.builder(
                          controller: _scrollController,
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                          itemCount: _results.length + 1,
                          itemBuilder: (_, i) {
                            if (i == _results.length) {
                              if (_isLoadingMore) {
                                return const Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 14),
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              if (!_hasMore && _results.isNotEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  child: Center(
                                    child: Text(
                                      '${_results.length} product${_results.length == 1 ? '' : 's'} found',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: EdgeInsets.only(
                                  bottom:
                                      i < _results.length - 1 ? 8 : 0),
                              child: _buildTemplateCard(_results[i]),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateCard(Map<String, dynamic> t) {
    final id = t['id'] as String;
    final name =
        t['product_combination_template_name'] as String? ?? 'Unknown';
    final imgUrl = t['img_url'] as String?;
    final parent = t['parent_category'] as String? ?? '';
    final child = t['child_category'] as String? ?? '';
    final gst = t['gst_data'] as Map? ?? {};
    final cgst = (gst['cgst_percent'] as num?)?.toDouble() ?? 0;
    final igst = (gst['igst_percent'] as num?)?.toDouble() ?? 0;
    final gstPct = igst > 0 ? igst : cgst * 2;
    final hasImg = imgUrl != null && imgUrl.isNotEmpty;

    final isAdding = _addingIds.contains(id);
    final isAdded = _addedIds.contains(id);

    String cap(String s) => s.isEmpty
        ? s
        : s
            .split(' ')
            .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
            .join(' ');

    final catLabel = [cap(parent), cap(child)]
        .where((s) => s.isNotEmpty && s.toLowerCase() != 'undefined')
        .join(' › ');

    return Container(
      decoration: BoxDecoration(
        color: isAdded
            ? const Color(0xFFF0FDF4)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAdded
              ? const Color(0xFF86EFAC)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: hasImg
                  ? CustomCachedNetworkImage(
                      imgUrl: imgUrl!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 52,
                      height: 52,
                      color: const Color(0xFFE2E8F0),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: Color(0xFF94A3B8),
                        size: 24,
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (catLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      catLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (gstPct > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        'GST: ${gstPct.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Add to Store button
            SizedBox(
              width: 90,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isAdded
                    ? Container(
                        key: const ValueKey('added'),
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Added',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : GestureDetector(
                        key: const ValueKey('add'),
                        onTap: isAdding ? null : () => _addToStore(t),
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: isAdding
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      Color(0xFF2563EB),
                                      Color(0xFF1D4ED8),
                                    ],
                                  ),
                            color: isAdding
                                ? const Color(0xFFE2E8F0)
                                : null,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: isAdding
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              Color(0xFF2563EB)),
                                    ),
                                  )
                                : const Text(
                                    'Add to Store',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
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
}
