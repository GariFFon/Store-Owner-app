import 'dart:async';
import 'package:exanor/components/translation_widget.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/models/store_model.dart';
import 'package:exanor/models/product_model.dart';
import 'package:exanor/services/api_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exanor/components/custom_cached_network_image.dart';
import 'package:exanor/screens/cart_screen.dart';
import 'package:exanor/components/product_variant_sheet.dart';
import 'package:exanor/components/universal_translation_wrapper.dart';

class StoreScreen extends StatefulWidget {
  final String storeId;
  final String? initialSearchQuery;

  const StoreScreen({
    super.key,
    required this.storeId,
    this.initialSearchQuery,
  });

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  Store? _store;
  bool _isLoadingStore = true;
  String? _errorMessage;

  // Products
  List<Product> _products = [];
  bool _isLoadingProducts = false;
  bool _isLoadingMoreProducts = false;
  int _currentPage = 1;
  bool _hasMoreProducts = true;

  // Search
  String _searchQuery = '';
  List<Product> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingSearchResults = false;
  bool _isLoadingMoreSearchResults = false;
  int _searchPage = 1;
  bool _hasMoreSearchResults = false;
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  // Default constant ID for user address
  final String _constAddressId = "e3d3142b-6065-4052-95f6-854a6bb039e9";
  String _userAddressId = "e3d3142b-6065-4052-95f6-854a6bb039e9";
  double _userLat = 0.0;
  double _userLng = 0.0;

  late ScrollController _scrollController;

  // Cart logic
  double? _cartGrandTotal;
  int _cartItemCount = 0;
  bool _isCartVisible = false;

  @override
  void initState() {
    super.initState();
    _loadAddressAndFetchStore();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final threshold =
          maxScroll * 0.75; // Trigger at 75% (25% away from bottom)

      if (currentScroll >= threshold) {
        if (_isSearching) {
          if (!_isLoadingMoreSearchResults && _hasMoreSearchResults) {
            _searchProducts(widget.storeId, _searchQuery, loadMore: true);
          }
        } else {
          if (!_isLoadingMoreProducts && _hasMoreProducts) {
            _fetchProducts(loadMore: true);
          }
        }
      }
    }
  }

  Future<void> _searchProducts(
    String storeId,
    String query, {
    bool loadMore = false,
  }) async {
    if (query.trim().length < 3) return;

    if (loadMore && _isLoadingMoreSearchResults) return;
    if (!loadMore && _isLoadingSearchResults) return;

    if (!mounted) return;

    setState(() {
      if (loadMore) {
        _isLoadingMoreSearchResults = true;
      } else {
        _isLoadingSearchResults = true;
        _isSearching = true;
        _searchPage = 1;
      }
    });

    try {
      final requestBody = {
        "query": query,
        "store_id": storeId,
        "lat": _userLat, // Using fetched user latitude
        "lng": _userLng, // Using fetched user longitude
        "is_store": false,
        "page": loadMore ? _searchPage + 1 : _searchPage,
      };

      print(
        '🔍 Searching products: $query, Page ${loadMore ? _searchPage + 1 : _searchPage}',
      );

      final response = await ApiService.post(
        '/search-in-store/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final responseData = response['data'];
        final productsList = (responseData['response'] as List)
            .map((item) => Product.fromJson(item))
            .toList();

        final hasNext = responseData['has_next'] ?? false;

        if (mounted) {
          setState(() {
            if (loadMore) {
              _searchResults.addAll(productsList);
              _searchPage++;
            } else {
              _searchResults = productsList;
            }
            _hasMoreSearchResults = hasNext;
            _isLoadingSearchResults = false;
            _isLoadingMoreSearchResults = false;
          });
        }
      } else {
        print('❌ Failed to search products: ${response['data']}');
        if (mounted) {
          setState(() {
            _isLoadingSearchResults = false;
            _isLoadingMoreSearchResults = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error searching products: $e');
      if (mounted) {
        setState(() {
          _isLoadingSearchResults = false;
          _isLoadingMoreSearchResults = false;
        });
      }
    }
  }

  Future<void> _loadAddressAndFetchStore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAddressId = prefs.getString('saved_address_id');

      // Try to get coordinates as double first, then as string if needed
      double? lat;
      double? lng;

      // Try to get latitude
      lat = prefs.getDouble('latitude');
      if (lat == null) {
        final latStr =
            prefs.getString('lat_string') ?? prefs.getString('user_latitude');
        if (latStr != null) {
          lat = double.tryParse(latStr);
        }
      }

      // Try to get longitude
      lng = prefs.getDouble('longitude');
      if (lng == null) {
        final lngStr =
            prefs.getString('lng_string') ?? prefs.getString('user_longitude');
        if (lngStr != null) {
          lng = double.tryParse(lngStr);
        }
      }

      final finalLat = lat ?? 0.0;
      final finalLng = lng ?? 0.0;

      print('📍 StoreScreen - Loaded coordinates from SharedPreferences:');
      print(
        '   Lat: $finalLat (from ${lat != null ? 'double' : 'string/default'})',
      );
      print(
        '   Lng: $finalLng (from ${lng != null ? 'double' : 'string/default'})',
      );
      print('   Address ID: ${savedAddressId ?? _constAddressId}');

      setState(() {
        if (savedAddressId != null && savedAddressId.isNotEmpty) {
          _userAddressId = savedAddressId;
        } else {
          _userAddressId = _constAddressId;
        }
        _userLat = finalLat;
        _userLng = finalLng;
      });

      // Handle initial search if provided
      if (widget.initialSearchQuery != null &&
          widget.initialSearchQuery!.isNotEmpty) {
        _searchController.text = widget.initialSearchQuery!;
        _searchQuery = widget.initialSearchQuery!;
        _searchProducts(widget.storeId, _searchQuery);
      }

      await _fetchStoreDetails();
      // Only fetch default products if NOT searching (or fetch anyway, but UI will show search results)
      // It's better to fetch default products too so if user closes search, they see something.
      await _fetchProducts();
      await _fetchCartDetails();
    } catch (e) {
      print('❌ StoreScreen: Error loading address data: $e');
      _userAddressId = _constAddressId;
      await _fetchStoreDetails();
      await _fetchProducts();
      await _fetchCartDetails();
    }
  }

  Future<void> _fetchStoreDetails() async {
    if (!mounted) return;

    setState(() {
      _isLoadingStore = true;
      _errorMessage = null;
    });

    try {
      final requestBody = {
        "user_address_id": _userAddressId,
        "store_id": widget.storeId,
        "page": 1,
      };

      print('🏪 Fetching store details for: ${widget.storeId}');

      final response = await ApiService.post(
        '/get-stores/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final responseData = response['data'];
        final storesList = (responseData['response'] as List)
            .map((item) => Store.fromJson(item))
            .toList();

        if (mounted) {
          setState(() {
            if (storesList.isNotEmpty) {
              _store = storesList.first;
              _isLoadingStore = false;
            } else {
              _errorMessage = 'Store not found';
              _isLoadingStore = false;
            }
          });
        }
      } else {
        print('❌ Failed to fetch store details: ${response['data']}');
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load store details';
            _isLoadingStore = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching store details: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred. Please try again.';
          _isLoadingStore = false;
        });
      }
    }
  }

  Future<void> _fetchProducts({bool loadMore = false}) async {
    if (loadMore && _isLoadingMoreProducts) return;
    if (!loadMore && _isLoadingProducts) return;

    if (!mounted) return;

    setState(() {
      if (loadMore) {
        _isLoadingMoreProducts = true;
      } else {
        _isLoadingProducts = true;
        _currentPage = 1;
      }
    });

    try {
      final requestBody = {
        "store_id": widget.storeId,
        "query": {},
        "page": loadMore ? _currentPage + 1 : _currentPage,
      };

      print(
        '🛍️ Fetching products: Page ${loadMore ? _currentPage + 1 : _currentPage}',
      );

      final response = await ApiService.post(
        '/product/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final responseData = response['data'];
        final productsList = (responseData['response'] as List)
            .map((item) => Product.fromJson(item))
            .toList();

        final pagination = responseData['pagination'];
        final hasNext = pagination['has_next'] ?? false;

        if (mounted) {
          setState(() {
            if (loadMore) {
              _products.addAll(productsList);
              _currentPage++;
              _fetchCartDetails(); // Refresh cart on paging? Maybe not strictly needed but good for sync.
            } else {
              _products = productsList;
            }
            _hasMoreProducts = hasNext;
            _isLoadingProducts = false;
            _isLoadingMoreProducts = false;
          });
        }
      } else {
        print('❌ Failed to fetch products: ${response['data']}');
        if (mounted) {
          setState(() {
            _isLoadingProducts = false;
            _isLoadingMoreProducts = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching products: $e');
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
          _isLoadingMoreProducts = false;
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    await _fetchStoreDetails();
    await _fetchProducts();
    await _fetchCartDetails();
  }

  Future<void> _fetchCartDetails() async {
    // Only fetch if we have valid address and store info
    if (widget.storeId.isEmpty) return;

    try {
      final requestBody = {
        "coupon_code": "",
        "store_id": widget.storeId,
        "order_method_id": "",
        "user_address_id": _userAddressId,
        "lat": _userLat,
        "lng": _userLng,
      };

      final response = await ApiService.post(
        '/auto-validate-cart/',
        body: requestBody,
        useBearerToken: true,
      );

      // Handle response regardless of status 200 or 400, if data is present
      // The user wants to ignore status checks if data is there
      if (response['data'] != null && response['data']['response'] != null) {
        final responseData = response['data']['response'];

        setState(() {
          // Extract cart totals
          // Prioritize 'grand_total'
          if (responseData['grand_total'] != null) {
            _cartGrandTotal = (responseData['grand_total'] as num).toDouble();
          } else {
            // Fallback to iterating cart_total array if needed or default 0
            _cartGrandTotal = 0.0;
          }

          // Extract count
          if (responseData['total_products_in_cart'] != null) {
            _cartItemCount = (responseData['total_products_in_cart'] as num)
                .toInt();
          } else if (responseData['items_available'] != null) {
            _cartItemCount = (responseData['items_available'] as List).length;
          } else {
            _cartItemCount = 0;
          }

          _isCartVisible = _cartItemCount > 0;
        });
      }
    } catch (e) {
      print('❌ Error fetching cart details: $e');
      if (e is ApiException && e.response != null) {
        // Attempt to parse data from the exception response (e.g. for 400 Bad Request which still has cart data)
        final response = e.response!;
        if (response['data'] != null && response['data']['response'] != null) {
          final responseData = response['data']['response'];
          if (mounted) {
            setState(() {
              // Extract cart totals
              if (responseData['grand_total'] != null) {
                _cartGrandTotal = (responseData['grand_total'] as num)
                    .toDouble();
              } else {
                _cartGrandTotal = 0.0;
              }

              // Extract count
              if (responseData['total_products_in_cart'] != null) {
                _cartItemCount = (responseData['total_products_in_cart'] as num)
                    .toInt();
              } else if (responseData['items_available'] != null) {
                _cartItemCount =
                    (responseData['items_available'] as List).length;
              } else {
                _cartItemCount = 0;
              }

              _isCartVisible = _cartItemCount > 0;
            });
          }
        }
      }
    }
  }

  Future<void> _handleAddToCart(int index) async {
    final product = _isSearching ? _searchResults[index] : _products[index];

    try {
      final requestBody = {
        "order_by": "variation_name",
        "query": {"store_id": widget.storeId, "product_id": product.id},
      };

      print('🛒 Adding to cart: ${product.productName} (${product.id})');

      // Show loading indicator here if needed in future

      final response = await ApiService.post(
        '/product-variation-value/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final responseData = response['data'];

        final isSuccess =
            responseData['additional_data']?['is_product_added_to_cart_successfully'] ==
            true;

        if (isSuccess) {
          // Case A: Added successfully (No variants)
          // Update quantity to 1
          _updateProductQuantity(index, 1);
          _fetchCartDetails(); // Refresh cart summary
        } else {
          // Case B: Has variants
          final variants = responseData['response'];
          if (variants is List) {
            _showVariantsBottomSheet(variants, product, (addedQty) {
              // Update local quantity on success
              _updateProductQuantity(index, addedQty);
              _fetchCartDetails(); // Refresh cart summary
              Navigator.pop(context); // Close sheet
            });
          }
        }
      } else {
        print('❌ Failed to add to cart: ${response['data']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TranslatedText('Failed to add to cart')),
        );
      }
    } catch (e) {
      print('❌ Error adding to cart: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TranslatedText('Error adding to cart')));
    }
  }

  void _showVariantsBottomSheet(
    List<dynamic> variants,
    Product product,
    Function(int) onSuccess,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ProductVariantSheet(
          variants: variants,
          product: product,
          storeId: widget.storeId,
          onAddToCartSuccess: onSuccess,
        );
      },
    );
  }

  Future<void> _decrementCartItem(int index) async {
    final product = _isSearching ? _searchResults[index] : _products[index];
    if (product.quantity <= 0) return;

    // Optimistically update quantity
    // _updateProductQuantity(index, -1); // Let's wait for API response for robustness or do optimistic?
    // User asked to "call auto validate cart api", but the decrement endpoint returns cart total too?
    // Actually the logic is: - button calls /decrement-product-in-cart/
    // Response payload has cart_total etc? The sample response shows "cart_total" present.
    // So we can update everything from the response.

    try {
      final requestBody = {
        "product_combination_id":
            "", // Assuming empty if not variant specific logic known yet, or need to handle variants?
        // For simplicity using product_id as per basic flow, but if variants exist this might need more logic.
        // Given current flow for simple products:
        "product_id": product.id,
        "store_id": widget.storeId,
      };

      print('➖ Decrementing cart item: ${product.productName}');

      final response = await ApiService.post(
        '/decrement-product-in-cart/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200) {
        final responseData = response['data'];
        if (responseData != null && responseData['status'] == 200) {
          // Success
          _updateProductQuantity(index, -1); // Update local state count

          // Update cart totals from this response
          _updateCartFromResponse(responseData); // Pass the whole data object
        }
      }
    } catch (e) {
      print('❌ Error decrementing cart item: $e');
    }
  }

  void _updateCartFromResponse(dynamic data) {
    if (data is! Map) return;

    if (mounted) {
      setState(() {
        if (data['grand_total'] != null) {
          _cartGrandTotal = (data['grand_total'] as num).toDouble();
        }
        if (data['total_products_in_cart'] != null) {
          _cartItemCount = (data['total_products_in_cart'] as num).toInt();
        }
        _isCartVisible = _cartItemCount > 0;
      });
    }
  }

  void _updateProductQuantity(int index, int delta) {
    setState(() {
      if (_isSearching) {
        if (index < _searchResults.length) {
          final currentQty = _searchResults[index].quantity;
          final newQty = (currentQty + delta).clamp(0, 99);
          _searchResults[index] = _searchResults[index].copyWith(
            quantity: newQty,
          );

          // Sync with main product list if the product exists there too
          final productId = _searchResults[index].id;
          final mainIndex = _products.indexWhere((p) => p.id == productId);
          if (mainIndex != -1) {
            _products[mainIndex] = _products[mainIndex].copyWith(
              quantity: newQty,
            );
          }
        }
      } else {
        if (index < _products.length) {
          final currentQty = _products[index].quantity;
          final newQty = (currentQty + delta).clamp(0, 99);
          _products[index] = _products[index].copyWith(quantity: newQty);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshAll,
            child: CustomScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Custom App Bar with Store Header (25% of screen height)
                SliverAppBar(
                  expandedHeight: MediaQuery.of(context).size.height * 0.25,
                  pinned: true,
                  stretch: true,
                  backgroundColor: theme.colorScheme.surface,
                  title: _store != null
                      ? TranslatedText(
                          _store!.storeName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                  leading: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_rounded,
                      color: theme.colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: _isLoadingStore
                        ? _buildSkeletalStoreLoader(theme)
                        : _errorMessage != null
                        ? _buildErrorView(theme)
                        : _buildStoreHeader(theme),
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
                  ),
                ),

                // Sticky Search Bar (iOS 18 Spotlight style)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SearchBarDelegate(
                    theme: theme,
                    controller: _searchController,
                    onChanged: (query) {
                      if (_debounce?.isActive ?? false) _debounce!.cancel();
                      _debounce = Timer(const Duration(milliseconds: 500), () {
                        final searchQuery = query.trim();
                        if (searchQuery.length >= 3) {
                          _searchProducts(widget.storeId, searchQuery);
                        } else if (searchQuery.isEmpty) {
                          setState(() {
                            _isSearching = false;
                            _searchResults.clear();
                          });
                        }
                      });
                      setState(() {
                        _searchQuery = query;
                        if (query.isEmpty) {
                          _isSearching = false;
                        }
                      });
                    },
                  ),
                ),

                // Products List or Search Results
                if (_isSearching)
                  if (_isLoadingSearchResults && _searchResults.isEmpty)
                    SliverFillRemaining(
                      child: _buildSkeletalProductsLoader(theme),
                    )
                  else if (_searchResults.isEmpty && !_isLoadingSearchResults)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 50),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 60,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              TranslatedText(
                                "No products found for '$_searchQuery'",
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16).copyWith(
                        bottom: _isCartVisible
                            ? 100
                            : 16, // Add padding for cart bar
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          if (index == _searchResults.length) {
                            return _isLoadingMoreSearchResults
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          }
                          return _buildProductCard(
                            _searchResults[index],
                            index,
                            theme,
                          );
                        }, childCount: _searchResults.length + 1),
                      ),
                    )
                else if (_isLoadingProducts && _products.isEmpty)
                  SliverFillRemaining(
                    child: _buildSkeletalProductsLoader(theme),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16).copyWith(
                      bottom: _isCartVisible
                          ? 100
                          : 16, // Add padding for cart bar
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index == _products.length) {
                          return _isLoadingMoreProducts
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : const SizedBox.shrink();
                        }
                        return _buildProductCard(
                          _products[index],
                          index,
                          theme,
                        );
                      }, childCount: _products.length + 1),
                    ),
                  ),
              ],
            ),
          ),

          // Floating Cart Bar
          if (_isCartVisible)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildCartSummaryBar(theme),
            ),
        ],
      ),
    );
  }

  Widget _buildCartSummaryBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TranslatedText(
                '$_cartItemCount item${_cartItemCount != 1 ? 's' : ''} added',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_cartGrandTotal != null)
                TranslatedText(
                  '₹${_cartGrandTotal!.toStringAsFixed(2)}', // Total directly from API
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CartScreen(
                    storeId: widget.storeId,
                    userAddressId: _userAddressId,
                    lat: _userLat,
                    lng: _userLng,
                  ),
                ),
              ).then((_) {
                // Refresh state when returning from cart
                _fetchCartDetails();
                // Optionally refresh products if quantities changed
                // _fetchProducts();
              });
            },
            child: Row(
              children: [
                TranslatedText(
                  'View cart',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_right, color: Colors.white, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletalStoreLoader(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      highlightColor: theme.colorScheme.surface,
      child: Column(
        children: [
          // Banner skeleton
          Expanded(flex: 6, child: Container(color: Colors.white)),
          // Info section skeleton
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo skeleton
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Text skeletons
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 20,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 14,
                          width: 150,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
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
    );
  }

  Widget _buildSkeletalProductsLoader(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      highlightColor: theme.colorScheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 20,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 16,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            TranslatedText(
              _errorMessage ?? 'An error occurred',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: _refreshAll, child: TranslatedText('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreHeader(ThemeData theme) {
    if (_store == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Banner Image (60% of header)
        Expanded(
          flex: 6,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomCachedNetworkImage(
                imgUrl: _store!.storeBannerImgUrl,
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 48),
                  ),
                ),
              ),
              // Gradient overlay for better text visibility
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      theme.colorScheme.surface.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
              // Featured badge
              if (_store!.isFeatured)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 60,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TranslatedText(
                      'Featured',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Store Info (40% of header)
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Store Logo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CustomCachedNetworkImage(
                    imgUrl: _store!.storeLogoImgUrl,
                    fit: BoxFit.cover,
                    borderRadius: 10.0,
                    errorWidget: Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.store, size: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Store Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Store Name & Category
                      Row(
                        children: [
                          Expanded(
                            child: TranslatedText(
                              _store!.storeName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Category
                      TranslatedText(
                        _store!.category,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Rating, Delivery Time & Location in a compact row
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Rating
                            if (_store!.averageRating > 0) ...[
                              _buildInfoChip(
                                theme,
                                icon: Icons.star_rounded,
                                iconColor: Colors.amber,
                                text:
                                    '${_store!.averageRating.toStringAsFixed(1)} (${_store!.ratingCount})',
                              ),
                              const SizedBox(width: 6),
                            ],
                            // Delivery Time
                            _buildInfoChip(
                              theme,
                              icon: Icons.timer_outlined,
                              iconColor: theme.colorScheme.primary,
                              text: _store!.fulfillmentSpeed,
                            ),
                            const SizedBox(width: 6),
                            // Location
                            _buildInfoChip(
                              theme,
                              icon: Icons.location_on_outlined,
                              iconColor: theme.colorScheme.primary,
                              text: _store!.city,
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
        ),
      ],
    );
  }

  Widget _buildInfoChip(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 3),
          TranslatedText(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product, int index, ThemeData theme) {
    final hasPrice = product.priceStartsFrom != null;
    final displayDescription =
        product.description != 'undefined' && product.description.isNotEmpty;

    Widget cardContent = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        boxShadow: hasPrice
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Food preference badge
                  if (product.foodPreference != 'categories')
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: product.foodPreference.toLowerCase() == 'veg'
                              ? Colors.green
                              : Colors.red,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: product.foodPreference.toLowerCase() == 'veg'
                                ? Colors.green
                                : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),

                  // Product Name
                  TranslatedText(
                    product.productName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Price
                  if (hasPrice)
                    TranslatedText(
                      '₹${product.priceStartsFrom!.toStringAsFixed(0)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    )
                  else
                    TranslatedText(
                      'Currently Unavailable',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Description
                  if (displayDescription)
                    TranslatedText(
                      product.description.length > 80
                          ? '${product.description.substring(0, 80)}... more'
                          : product.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 12),

                  // Categories & Rating Row
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      // Featured Badge
                      if (product.isFeatured)
                        _buildBadge(
                          theme,
                          '⭐ Featured',
                          theme.colorScheme.primary,
                        ),

                      // Sponsored Badge (subtle)
                      if (product.isSponsored)
                        _buildBadge(
                          theme,
                          'Sponsored',
                          theme.colorScheme.onSurface.withOpacity(0.4),
                          isSubtle: true,
                        ),

                      // Parent Category
                      _buildCategoryChip(theme, product.parentCategory),

                      // Child Category
                      _buildCategoryChip(theme, product.childCategory),

                      // Rating
                      if (product.averageRating > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 4),
                              TranslatedText(
                                '${product.averageRating.toStringAsFixed(1)} (${product.ratingCount})',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
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

            const SizedBox(width: 16),

            // Right side - Product Image with Stacked Button
            SizedBox(
              width: 140,
              child: Stack(
                clipBehavior: Clip.none, // Allow button to overflow
                children: [
                  // Product Image
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CustomCachedNetworkImage(
                      imgUrl: product.imgUrl,
                      width: 140,
                      height: 140,
                      borderRadius: 16.0,
                      fit: BoxFit.cover,
                      errorWidget: Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported, size: 48),
                      ),
                    ),
                  ),

                  // Add/Quantity Control - Only show if price available
                  if (hasPrice)
                    Positioned(
                      bottom: -18,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: product.quantity == 0
                            ? _buildAddButton(theme, index)
                            : _buildQuantityControl(theme, product, index),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!hasPrice) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix(
          // Greyscale filter
          [
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0, 0, 0, 0.6, 0, // Reduce alpha slightly
          ],
        ),
        child: IgnorePointer(child: cardContent),
      );
    }

    return cardContent;
  }

  Widget _buildBadge(
    ThemeData theme,
    String text,
    Color color, {
    bool isSubtle = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSubtle ? color.withOpacity(0.05) : color.withOpacity(0.1),
        border: isSubtle ? Border.all(color: color, width: 1) : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: TranslatedText(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isSubtle ? color : color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildCategoryChip(ThemeData theme, String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TranslatedText(
        category,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildAddButton(ThemeData theme, int index) {
    return Padding(
      padding: const EdgeInsets.all(8.0), // Invisible touch area padding
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => _handleAddToCart(index),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.primary, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TranslatedText(
              'ADD',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityControl(ThemeData theme, Product product, int index) {
    return Padding(
      padding: const EdgeInsets.all(8.0), // Invisible touch area padding
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary, // Primary color background
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Minus Button - Fully Touchable
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _decrementCartItem(index),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: TranslatedText(
                    '−',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // Quantity with Animation
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Container(
                key: ValueKey<int>(product.quantity),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TranslatedText(
                  '${product.quantity}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),

            // Plus Button - Fully Touchable
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _handleAddToCart(index), // Plus calls Add API
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: TranslatedText(
                    '+',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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

// iOS 18 Spotlight-style Search Bar Delegate
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final ThemeData theme;
  final Function(String) onChanged;
  final TextEditingController controller;

  _SearchBarDelegate({
    required this.theme,
    required this.onChanged,
    required this.controller,
  });

  @override
  double get minExtent => 70.0; // Fixed height - truly sticky

  @override
  double get maxExtent => 70.0; // Same as minExtent for no shrinking

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Search products...',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              size: 22,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                if (value.text.isNotEmpty) {
                  return IconButton(
                    icon: Icon(
                      Icons.cancel,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      size: 20,
                    ),
                    onPressed: () {
                      controller.clear();
                      onChanged(''); // Trigger onChanged to update state
                    },
                  );
                }
                return Icon(
                  Icons.mic_none_rounded,
                  color: theme.colorScheme.primary,
                  size: 22,
                );
              },
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(
              0.5,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(22),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
          ),
          style: theme.textTheme.bodyMedium,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SearchBarDelegate oldDelegate) {
    return oldDelegate.theme != theme;
  }
}
