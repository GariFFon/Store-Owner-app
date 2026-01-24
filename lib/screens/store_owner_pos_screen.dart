import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/components/custom_cached_network_image.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:country_code_picker/country_code_picker.dart';

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

  // Cart
  int _totalProductsInCart = 0;
  List<Map<String, dynamic>> _cartItemsAvailable = [];
  List<Map<String, dynamic>> _cartItemsUnavailable = [];
  Map<String, dynamic>? _cartData;
  double _grandTotal = 0.0;

  // Customer
  String? customer_user_id;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _fetchCategories();
    _setupScrollListener();
    _validateCart(); // Load cart data on init
    
    // Show customer phone dialog on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCustomerPhoneDialog();
    });
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
      // Trigger pagination when user reaches 70% of the scroll
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.7) {
        // User has scrolled 70% down, load more products
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

  Future<void> _validateCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customerUserId = prefs.getString('user_id') ?? '';

      final response = await ApiService.post(
        '/auto-validate-cart/',
        body: {
          'store_id': widget.storeId,
          'order_method_id':
              '1d9eb8ba-4d33-4d3d-b218-aba12a3fb7b1', // Default order method
          'user_address_id':
              '6068c242-8d0f-4513-aaf3-401fafdad596', // Default address
          'lat': 0.0,
          'lng': 0.0,
          'store_access': true,
          'customer_user_id': customerUserId,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data']['response'];
        setState(() {
          _totalProductsInCart = data['total_products_in_cart'] ?? 0;
          _cartItemsAvailable = List<Map<String, dynamic>>.from(
            data['items_available'] ?? [],
          );
          _cartItemsUnavailable = List<Map<String, dynamic>>.from(
            data['items_unavailable'] ?? [],
          );
          _grandTotal = (data['grand_total'] ?? 0.0).toDouble();
          _cartData = data;
        });
      }
    } catch (e) {
      print('Error validating cart: $e');
    }
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cart ($_totalProductsInCart ${_totalProductsInCart == 1 ? 'item' : 'items'})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Cart items list
              Expanded(
                child: _cartItemsAvailable.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Your cart is empty',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _cartItemsAvailable.length,
                        itemBuilder: (context, index) {
                          final item = _cartItemsAvailable[index];
                          final pricing = item['pricing_details'] ?? {};
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['product_name'] ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Qty: ${item['enquired_quantity']}',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '₹${pricing['item_total']?.toStringAsFixed(2) ?? '0.00'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item['is_available'] == false)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          'Currently unavailable',
                                          style: TextStyle(
                                            color: Colors.red[700],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // Total section
              if (_cartItemsAvailable.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Grand Total',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '₹${_grandTotal.toStringAsFixed(2)}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            // TODO: Proceed to checkout
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Proceeding to checkout...'),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Proceed to Checkout',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
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

  // Customer Phone Dialog
  void _showCustomerPhoneDialog() {
    final TextEditingController phoneController = TextEditingController();
    CountryCode selectedCountry = CountryCode.fromCountryCode('IN');
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Enter Customer Phone'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: CountryCodePicker(
                        onChanged: (CountryCode countryCode) {
                          setState(() {
                            selectedCountry = countryCode;
                          });
                        },
                        initialSelection: 'IN',
                        favorite: const ['+91', 'IN'],
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () async {
                          // Open QR scanner
                          final scannedCode = await Navigator.push<String>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => _QRScannerDialog(),
                            ),
                          );
                          if (scannedCode != null) {
                            phoneController.text = scannedCode;
                          }
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 16.0),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final phone = phoneController.text.trim();
                          if (phone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a phone number'),
                              ),
                            );
                            return;
                          }

                          setState(() {
                            isLoading = true;
                          });

                          // Get country code
                          final countryCode = selectedCountry.dialCode
                                  ?.replaceAll('+', '') ??
                              '91';
                          final fullPhoneNumber = '$countryCode$phone';

                          try {
                            await _fetchCustomerData(fullPhoneNumber);
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (e) {
                            setState(() {
                              isLoading = false;
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Fetch customer data from API
  Future<void> _fetchCustomerData(String phoneNumber) async {
    try {
      final response = await ApiService.post(
        '/view-user-data/',
        body: {
          'phone_number': int.parse(phoneNumber),
          'store_id': widget.storeId,
          'store_access': true,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          final List<dynamic> userList = data['response'];
          if (userList.isNotEmpty) {
            final userData = userList[0] as Map<String, dynamic>;
            setState(() {
              customer_user_id = userData['id'] as String?;
            });

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Customer loaded: ${userData['first_name']} ${userData['last_name']}',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching customer data: $e');
      rethrow;
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
      floatingActionButton: _totalProductsInCart > 0
          ? Badge(
              label: Text('$_totalProductsInCart'),
              backgroundColor: Colors.red,
              child: FloatingActionButton(
                onPressed: _showCartBottomSheet,
                backgroundColor: theme.primaryColor,
                child: const Icon(Icons.shopping_cart, color: Colors.white),
              ),
            )
          : null,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product Image - Tappable for details
          Expanded(
            flex: 3,
            child: InkWell(
              onTap: () => _showProductDetails(product),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
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
          ),

          // Product Details
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Text(
                      productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          '₹${productPrice.toString()}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Add button
                      SizedBox(
                        height: 26,
                        child: ElevatedButton(
                          onPressed: () => _handleAddToCart(product),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 2,
                            ),
                            backgroundColor: theme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add, size: 14),
                              SizedBox(width: 2),
                              Text('Add', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleAddToCart(Map<String, dynamic> product) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get customer_user_id from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final customerUserId = prefs.getString('user_id') ?? '';

      // Call API to get product variations
      final response = await ApiService.post(
        '/product-variation-value/',
        body: {
          'order_by': 'variation_name',
          'query': {'store_id': widget.storeId, 'product_id': product['id']},
          'store_id': widget.storeId,
          'customer_user_id': customerUserId,
        },
        useBearerToken: true,
      );

      // Close loading indicator
      if (mounted) Navigator.pop(context);

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        final additionalData = data['additional_data'];

        // Case A: Product added directly (no variants)
        if (additionalData != null &&
            additionalData['is_product_added_to_cart_successfully'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['response'] ?? 'Product added to cart'),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green,
              ),
            );
          }
          return;
        }

        // Case B: Product has variants - show bottom sheet
        if (data['status'] == 200 && data['response'] is List) {
          final variations = data['response'] as List;
          if (variations.isNotEmpty && mounted) {
            _showVariantsBottomSheet(product, variations);
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add product'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Close loading if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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

  void _showVariantsBottomSheet(Map<String, dynamic> product, List variations) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _VariantsBottomSheetContent(
        product: product,
        variations: variations,
        storeId: widget.storeId,
        onCartUpdated: _validateCart, // Call cart validation after adding
      ),
    );
  }
}

// Stateful Bottom Sheet Widget for Variants
class _VariantsBottomSheetContent extends StatefulWidget {
  final Map<String, dynamic> product;
  final List variations;
  final String storeId;
  final VoidCallback onCartUpdated;

  const _VariantsBottomSheetContent({
    required this.product,
    required this.variations,
    required this.storeId,
    required this.onCartUpdated,
  });

  @override
  State<_VariantsBottomSheetContent> createState() =>
      _VariantsBottomSheetContentState();
}

class _VariantsBottomSheetContentState
    extends State<_VariantsBottomSheetContent> {
  int _quantity = 1;
  List<String> _selectedVariationIds = [];
  bool _isAvailable = false;
  double _price = 0.0;
  bool _isLoading = false;
  String? _productCombinationId;

  @override
  void initState() {
    super.initState();
    // Auto-validate if there are variations
    if (widget.variations.isNotEmpty) {
      _validateAvailability();
    }
  }

  Future<void> _validateAvailability() async {
    if (_selectedVariationIds.isEmpty) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final customerUserId = prefs.getString('user_id') ?? '';

      final response = await ApiService.post(
        '/validate-product-availability/',
        body: {
          'product_id': widget.product['id'],
          'store_id': widget.storeId,
          'store_access': true,
          'customer_user_id': customerUserId,
          'quantity': _quantity,
          'variations': _selectedVariationIds,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data']['response'];
        setState(() {
          _isAvailable = data['is_available'] ?? false;
          _productCombinationId = data['product_combination_id'];
          _price =
              data['pricing_details']?['selling_amount_including_tax']
                  ?.toDouble() ??
              0.0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isAvailable = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isAvailable = false;
        _isLoading = false;
      });
      print('Error validating availability: $e');
    }
  }

  void _incrementQuantity() {
    setState(() {
      _quantity++;
    });
    _validateAvailability();
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
      _validateAvailability();
    }
  }

  void _selectVariation(String variationValueId) {
    setState(() {
      if (_selectedVariationIds.contains(variationValueId)) {
        _selectedVariationIds.remove(variationValueId);
      } else {
        _selectedVariationIds.add(variationValueId);
      }
    });
    _validateAvailability();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product['product_name'] ?? 'Select Options',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Choose your preferences',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Variations list
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: widget.variations.length,
                itemBuilder: (context, index) {
                  final variation = widget.variations[index];
                  final variationName =
                      variation['variation_name'] ?? 'Options';
                  final isRequired = variation['is_required'] ?? false;
                  final variationValues =
                      variation['variation_value'] as List? ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Variation header
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 12),
                        child: Row(
                          children: [
                            Text(
                              variationName[0].toUpperCase() +
                                  variationName.substring(1),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isRequired)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Required',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Variation values
                      ...variationValues.map((value) {
                        final valueId = value['id'];
                        final valueName = value['variation_value_name'] ?? '';
                        final isSelected = _selectedVariationIds.contains(
                          valueId,
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? theme.primaryColor
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: isSelected
                                ? theme.primaryColor.withOpacity(0.1)
                                : null,
                          ),
                          child: ListTile(
                            title: Text(
                              valueName,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle,
                                    color: theme.primaryColor,
                                  )
                                : null,
                            onTap: () => _selectVariation(valueId),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                },
              ),
            ),
            // Bottom section with quantity and add button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Quantity controls
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _decrementQuantity,
                          icon: const Icon(Icons.remove),
                          iconSize: 20,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '$_quantity',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _incrementQuantity,
                          icon: const Icon(Icons.add),
                          iconSize: 20,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Add button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isAvailable && !_isLoading
                          ? () {
                              Navigator.pop(context);
                              // Call the callback to update cart in parent widget
                              widget.onCartUpdated();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Added $_quantity item(s) to cart',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Add item${_price > 0 ? ' ₹${(_price * _quantity).toStringAsFixed(2)}' : ''}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// QR Scanner Dialog for Phone Number
class _QRScannerDialog extends StatefulWidget {
  @override
  State<_QRScannerDialog> createState() => _QRScannerDialogState();
}

class _QRScannerDialogState extends State<_QRScannerDialog> {
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
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            if (barcode.rawValue != null) {
              Navigator.pop(context, barcode.rawValue);
              return;
            }
          }
        },
      ),
    );
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
