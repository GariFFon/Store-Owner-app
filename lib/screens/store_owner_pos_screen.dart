import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/components/custom_cached_network_image.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class StoreOwnerPOSScreen extends StatefulWidget {
  final String storeId;
  final String storeName;

  const StoreOwnerPOSScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<StoreOwnerPOSScreen> createState() => _StoreOwnerPOSScreenState();
}

class _StoreOwnerPOSScreenState extends State<StoreOwnerPOSScreen> {
  // Categories
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategoryId;
  bool _isCategoriesLoading = true;
  String? _categoriesError;

  // Products
  List<Map<String, dynamic>> _products = [];
  bool _isProductsLoading = false;
  String? _productsError;

  // Pagination
  int _currentPage = 1;
  bool _hasMoreProducts = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  // Search
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  // Voice Search
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceSearchText = '';

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _fetchCategories();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _speech.stop();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        // User is near the bottom, load more products
        if (!_isLoadingMore && _hasMoreProducts && !_isProductsLoading) {
          _loadMoreProducts();
        }
      }
    });
  }

  void _initializeSpeech() async {
    _speech = stt.SpeechToText();
    await _speech.initialize(
      onError: (error) => print('Speech recognition error: $error'),
      onStatus: (status) => print('Speech recognition status: $status'),
    );
  }

  Future<void> _fetchCategories() async {
    try {
      setState(() {
        _isCategoriesLoading = true;
        _categoriesError = null;
      });

      final response = await ApiService.post(
        '/get-linked-product-categories/',
        body: {'store_id': widget.storeId},
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          setState(() {
            _categories = List<Map<String, dynamic>>.from(data['response']);

            // Add "All" category at the beginning
            _categories.insert(0, {
              'id': 'all',
              'category_name': 'All',
              'category_icon': null,
            });

            _isCategoriesLoading = false;

            // Auto-select first category (which is now "All")
            if (_categories.isNotEmpty) {
              _selectedCategoryId = _categories[0]['id'];
              _fetchProductsByCategory(_selectedCategoryId!);
            }
          });
        } else {
          setState(() {
            _categoriesError = 'No categories found';
            _isCategoriesLoading = false;
          });
        }
      } else {
        setState(() {
          _categoriesError = 'Failed to fetch categories';
          _isCategoriesLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _categoriesError = 'Error: $e';
        _isCategoriesLoading = false;
      });
    }
  }

  Future<void> _fetchProductsByCategory(String categoryId) async {
    try {
      setState(() {
        _isProductsLoading = true;
        _productsError = null;
        _currentPage = 1; // Reset to first page
        _hasMoreProducts = true; // Assume there might be more
      });

      // Get customer_user_id from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final customerUserId = prefs.getString('user_id') ?? '';

      // Use the /product/ endpoint with proper payload
      // If categoryId is 'all', use empty query to fetch all products
      final queryParam = categoryId == 'all'
          ? {}
          : {'parent_category_id': categoryId};

      final response = await ApiService.post(
        '/product/',
        body: {
          'store_id': widget.storeId,
          'query': queryParam,
          'page': _currentPage,
          'store_access': true,
          'customer_user_id': customerUserId,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          final newProducts = List<Map<String, dynamic>>.from(data['response']);
          setState(() {
            _products = newProducts;
            _isProductsLoading = false;
            // If we got fewer products than expected, there might not be more
            _hasMoreProducts =
                newProducts.length >= 10; // Assuming 10 items per page
          });
        } else {
          setState(() {
            _productsError = 'No products found';
            _isProductsLoading = false;
            _hasMoreProducts = false;
          });
        }
      } else {
        setState(() {
          _productsError = 'Failed to fetch products';
          _isProductsLoading = false;
          _hasMoreProducts = false;
        });
      }
    } catch (e) {
      setState(() {
        _productsError = 'Error: $e';
        _isProductsLoading = false;
        _hasMoreProducts = false;
      });
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMoreProducts || _selectedCategoryId == null) {
      return;
    }

    try {
      setState(() {
        _isLoadingMore = true;
      });

      _currentPage++; // Increment page

      // Get customer_user_id from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final customerUserId = prefs.getString('user_id') ?? '';

      // Use the same query logic as _fetchProductsByCategory
      final queryParam = _selectedCategoryId == 'all'
          ? {}
          : {'parent_category_id': _selectedCategoryId};

      final response = await ApiService.post(
        '/product/',
        body: {
          'store_id': widget.storeId,
          'query': queryParam,
          'page': _currentPage,
          'store_access': true,
          'customer_user_id': customerUserId,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          final newProducts = List<Map<String, dynamic>>.from(data['response']);
          setState(() {
            _products.addAll(newProducts); // Append new products
            _isLoadingMore = false;
            // If we got fewer products than expected, there might not be more
            _hasMoreProducts =
                newProducts.length >= 10; // Assuming 10 items per page
          });
        } else {
          setState(() {
            _isLoadingMore = false;
            _hasMoreProducts = false; // No more products
          });
        }
      } else {
        setState(() {
          _isLoadingMore = false;
          _hasMoreProducts = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        // Don't set hasMoreProducts to false on error, allow retry
      });
      print('Error loading more products: $e');
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      // If search is empty, fetch products by selected category
      if (_selectedCategoryId != null) {
        await _fetchProductsByCategory(_selectedCategoryId!);
      }
      return;
    }

    try {
      setState(() {
        _isProductsLoading = true;
        _productsError = null;
      });

      // TODO: Replace with actual API endpoint for searching products
      final response = await ApiService.post(
        '/search-products/', // You'll need to provide the actual endpoint
        body: {'store_id': widget.storeId, 'query': query},
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          setState(() {
            _products = List<Map<String, dynamic>>.from(data['response']);
            _isProductsLoading = false;
          });
        } else {
          setState(() {
            _products = [];
            _productsError = 'No products found for "$query"';
            _isProductsLoading = false;
          });
        }
      } else {
        setState(() {
          _productsError = 'Search failed';
          _isProductsLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _productsError = 'Search error: $e';
        _isProductsLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchProducts(value);
    });
  }

  void _startVoiceSearch() async {
    if (_speech.isAvailable && !_isListening) {
      setState(() => _isListening = true);

      await _speech.listen(
        onResult: (result) {
          setState(() {
            _voiceSearchText = result.recognizedWords;
            _searchController.text = _voiceSearchText;
          });

          if (result.finalResult) {
            _searchProducts(_voiceSearchText);
            _stopVoiceSearch();
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      );
    }
  }

  void _stopVoiceSearch() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  void _openQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _QRScannerScreen(
          onCodeScanned: (code) {
            // Search for product by scanned code
            _searchController.text = code;
            _searchProducts(code);
          },
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_store_id');
    await prefs.remove('selected_store_name');

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/store-selection');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            _buildSearchBar(theme),
            Expanded(
              child: Row(
                children: [
                  // Categories Sidebar
                  _buildCategoriesSidebar(theme, isLandscape),

                  // Products Grid
                  Expanded(child: _buildProductsGrid(theme)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.store, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.storeName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Point of Sale',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Change Store',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // QR Scanner Button
          IconButton(
            onPressed: _openQRScanner,
            icon: const Icon(Icons.qr_code_scanner),
            style: IconButton.styleFrom(
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              foregroundColor: theme.primaryColor,
            ),
            tooltip: 'Scan QR Code',
          ),
          const SizedBox(width: 8),

          // Search TextField
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search products by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          if (_selectedCategoryId != null) {
                            _fetchProductsByCategory(_selectedCategoryId!);
                          }
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Voice Search Button
          IconButton(
            onPressed: _isListening ? _stopVoiceSearch : _startVoiceSearch,
            icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
            style: IconButton.styleFrom(
              backgroundColor: _isListening
                  ? Colors.red.withOpacity(0.1)
                  : theme.primaryColor.withOpacity(0.1),
              foregroundColor: _isListening ? Colors.red : theme.primaryColor,
            ),
            tooltip: _isListening ? 'Stop Listening' : 'Voice Search',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSidebar(ThemeData theme, bool isLandscape) {
    final sidebarWidth = isLandscape ? 100.0 : 80.0;

    if (_isCategoriesLoading) {
      return Container(
        width: sidebarWidth,
        color: theme.cardColor,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_categoriesError != null) {
      return Container(
        width: sidebarWidth,
        color: theme.cardColor,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              'Error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: ListView.builder(
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = category['id'] == _selectedCategoryId;

          return InkWell(
            onTap: () {
              setState(() {
                _selectedCategoryId = category['id'];
                _searchController.clear();
              });
              _fetchProductsByCategory(category['id']);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.primaryColor.withOpacity(0.1)
                    : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isSelected ? theme.primaryColor : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Category Icon
                  if (category['category_icon'] != null)
                    CustomCachedNetworkImage(
                      imgUrl: category['category_icon'],
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    )
                  else
                    Icon(
                      Icons.category,
                      size: 40,
                      color: isSelected
                          ? theme.primaryColor
                          : theme.iconTheme.color,
                    ),
                  const SizedBox(height: 8),
                  // Category Name
                  Text(
                    _capitalizeCategoryName(category['category_name'] ?? ''),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? theme.primaryColor
                          : theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductsGrid(ThemeData theme) {
    if (_isProductsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_productsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _productsError!,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_selectedCategoryId != null) {
                  _fetchProductsByCategory(_selectedCategoryId!);
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No products found', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final product = _products[index];
              return _buildProductCard(theme, product);
            }, childCount: _products.length),
          ),
        ),
        // Loading indicator at the bottom when loading more
        if (_isLoadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        // Show "No more products" message if at end
        if (!_hasMoreProducts && _products.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No more products',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductCard(ThemeData theme, Map<String, dynamic> product) {
    final productName = product['product_name'] ?? 'Product';
    final productPrice =
        product['lowest_available_price'] ?? product['price_starts_from'] ?? 0;
    final productImage = product['img_url'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Handle product selection
          _showProductDetails(product);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product Image
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: productImage != null
                    ? CustomCachedNetworkImage(
                        imgUrl: productImage,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: theme.primaryColor.withOpacity(0.1),
                        child: Icon(
                          Icons.inventory_2,
                          size: 48,
                          color: theme.primaryColor,
                        ),
                      ),
              ),
            ),

            // Product Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₹${productPrice.toString()}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
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

  void _showProductDetails(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product['product_name'] ?? 'Product Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product['img_url'] != null)
              CustomCachedNetworkImage(
                imgUrl: product['img_url'],
                height: 200,
                fit: BoxFit.cover,
              ),
            const SizedBox(height: 16),
            Text(
              'Price: ₹${product['lowest_available_price'] ?? product['price_starts_from'] ?? 0}',
            ),
            if (product['description'] != null &&
                product['description'] != 'undefined') ...[
              const SizedBox(height: 8),
              Text(product['description']),
            ],
            if (product['parent_category'] != null) ...[
              const SizedBox(height: 8),
              Text('Category: ${product['parent_category']}'),
            ],
            if (product['child_category'] != null) ...[
              const SizedBox(height: 4),
              Text('Sub-category: ${product['child_category']}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Helper method to capitalize the first letter of category name
  String _capitalizeCategoryName(String name) {
    if (name.isEmpty) return name;
    return name[0].toUpperCase() + name.substring(1);
  }
}

// QR Scanner Screen
class _QRScannerScreen extends StatefulWidget {
  final Function(String) onCodeScanned;

  const _QRScannerScreen({required this.onCodeScanned});

  @override
  State<_QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<_QRScannerScreen> {
  MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black,
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              widget.onCodeScanned(barcode.rawValue!);
              Navigator.pop(context);
              return;
            }
          }
        },
      ),
    );
  }
}
