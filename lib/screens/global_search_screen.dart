import 'dart:async';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/screens/store_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/services/api_service.dart';

import 'package:exanor/components/custom_cached_network_image.dart';

class GlobalSearchScreen extends StatefulWidget {
  final String initialQuery;
  const GlobalSearchScreen({super.key, this.initialQuery = ''});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  List<dynamic> _stores = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasNextPage = false;
  String? _errorMessage;

  String _userAddressId = "";
  // double _userLat = 0.0;
  // double _userLng = 0.0;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
    _scrollController.addListener(_onScroll);
    _loadAddressAndInit();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAddressAndInit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userAddressId =
          prefs.getString('saved_address_id') ??
          "e3d3142b-6065-4052-95f6-854a6bb039e9";

      // If initial query exists, trigger search immediately
      if (widget.initialQuery.isNotEmpty) {
        _performSearch(widget.initialQuery);
      }
    } catch (e) {
      print("Error loading address: $e");
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasNextPage) {
      _performSearch(_searchController.text, isLoadMore: true);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        setState(() {
          _stores = [];
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query, {bool isLoadMore = false}) async {
    if (query.trim().isEmpty) return;

    if (isLoadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _currentPage = 1;
      });
    }

    try {
      final requestBody = {
        "query": query,
        "user_address_id": _userAddressId,
        "page": isLoadMore ? _currentPage + 1 : 1,
      };

      final response = await ApiService.post(
        '/global-product-search/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final data = response['data'];
        final List<dynamic> rawStores = data['response'] ?? [];
        // Filter out stores with empty product list
        final List<dynamic> newStores = rawStores.where((store) {
          final products = store['search_result'];
          return products is List && products.isNotEmpty;
        }).toList();
        final pagination = data['pagination'];

        if (mounted) {
          setState(() {
            if (isLoadMore) {
              _stores.addAll(newStores);
              _currentPage++;
            } else {
              _stores = newStores;
              _currentPage = 1;
            }

            if (pagination != null) {
              _hasNextPage = pagination['has_next'] ?? false;
            } else {
              _hasNextPage = false;
            }

            _isLoading = false;
            _isLoadingMore = false;
          });
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to search');
      }
    } catch (e) {
      print("Search error: $e");
      if (mounted) {
        setState(() {
          if (!isLoadMore) _errorMessage = "Failed to load results";
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.surface,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_rounded,
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search for food, groceries...',
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: theme.colorScheme.primary,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(child: _buildBody(theme)),
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
            TranslatedText(_errorMessage!),
          ],
        ),
      );
    }

    if (_stores.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const TranslatedText("No results found"),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      itemCount: _stores.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Divider(color: theme.dividerColor.withOpacity(0.08), height: 1),
      ),
      itemBuilder: (context, index) {
        if (index == _stores.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        return _buildStoreItem(theme, _stores[index]);
      },
    );
  }

  Widget _buildStoreItem(ThemeData theme, dynamic store) {
    final List<dynamic> products = store['search_result'] ?? [];

    // If no products matched in this store, we might still show the store if the API returned it (maybe store name match?)
    // But per user request "horizontal list to display the product", so showcasing products is key.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Store Header
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StoreScreen(storeId: store['id']),
              ),
            );
          },
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(store['store_logo_img_url'] ?? ''),
                    fit: BoxFit.cover,
                    onError: (_, __) {},
                  ),
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: (store['store_logo_img_url'] == null)
                    ? Icon(
                        Icons.store,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TranslatedText(
                      store['store_name'] ?? 'Unknown Store',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        TranslatedText(
                          '${store['average_rating'] ?? 0.0}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.timer,
                          size: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        const SizedBox(width: 4),
                        TranslatedText(
                          store['fulfillment_speed'] ?? 'N/A',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Products Horizontal List
        if (products.isNotEmpty)
          SizedBox(
            height: 220, // Adjust height as needed
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                return _buildProductCard(theme, products[index], store['id']);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProductCard(ThemeData theme, dynamic product, String storeId) {
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // Open StoreScreen and attempt to scroll to this product
          // Since StoreScreen doesn't support direct scroll yet,
          // we will pass the product name as a search query to simulate isolating/scrolling to it.
          Navigator.push(
            context,
            MaterialPageRoute(
              // We need to modify StoreScreen to accept initialSearchQuery or perform this search
              // For now, let's assume we will add 'initialSearchQuery' to StoreScreen
              // or we use 'storeId' only and hope user finds it.
              // Recommending adding initialSearchQuery to StoreScreen next.
              builder: (context) => StoreScreen(
                storeId: storeId,
                initialSearchQuery: product['product_name'],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: CustomCachedNetworkImage(
                  imgUrl: product['img_url'] ?? '',
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(
                    product['product_name'] ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  TranslatedText(
                    product['description'] != 'undefined'
                        ? (product['description'] ?? '')
                        : (product['child_category'] ?? ''),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TranslatedText(
                        '₹${product['lowest_available_price']}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      // Add button placeholder icon
                      Icon(
                        Icons.add_circle,
                        color: theme.colorScheme.primary,
                        size: 24,
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
}
