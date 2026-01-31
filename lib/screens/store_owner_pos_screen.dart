import 'dart:async';
import 'dart:math' as math;
import 'package:exanor/components/translation_widget.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/components/custom_cached_network_image.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:country_code_picker/country_code_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:exanor/screens/review_order_screen.dart';
import 'package:exanor/screens/orders_list_screen.dart';
import 'package:exanor/screens/purchase_screen.dart';
import 'package:exanor/screens/receipts_screen.dart';
import 'package:exanor/screens/overview_screen.dart';
import 'package:exanor/screens/sales_screen.dart';
import 'package:exanor/screens/payment_screen.dart';
import 'package:exanor/screens/store_selection_screen.dart';
import 'package:exanor/screens/suppliers_list_screen.dart';
import 'package:exanor/screens/gst_rates_screen.dart';

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
  bool _isSearchExpanded = false;

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

  // Location
  double _lat = 0.0;
  double _lng = 0.0;

  // Payment
  String? _selectedPaymentMethodId;

  // Customer
  String? customer_user_id;
  Map<String, dynamic>? _currentCustomer;

  // Address
  String? selected_address_id;

  // Payment Modes
  List<Map<String, dynamic>> _bankDetails = [];
  String _selectedPaymentMode = 'UNPAID';
  Map<String, double> _multiModeValues = {}; // Store split amounts

  // Order Methods
  List<Map<String, dynamic>> _orderMethods = [];
  Map<String, dynamic>? _selectedOrderMethod;
  bool _isOrderMethodsLoading = false;

  String? _ownerName;

  @override
  void initState() {
    super.initState();
    _fetchOwnerName();
    _initializeSpeech();
    _fetchCategories();
    _setupScrollListener();
    _initializeSpeech();
    _fetchCategories();
    _fetchCategories();
    _fetchPaymentMethods();
    _fetchStoreBankDetails();
    _setupScrollListener();
    _initLocationAndCart(); // Load location then cart data

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

  Future<void> _fetchOwnerName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firstName = prefs.getString('first_name') ?? '';
      final lastName = prefs.getString('last_name') ?? '';

      if (mounted) {
        setState(() {
          _ownerName = '$firstName $lastName'.trim();
          if (_ownerName!.isEmpty) {
            _ownerName = 'Store Owner';
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching owner name: $e');
    }
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

  Future<void> _fetchOrderMethods() async {
    try {
      setState(() => _isOrderMethodsLoading = true);
      final response = await ApiService.post(
        '/order-method/',
        body: {
          "store_access": true,
          "customer_user_id": customer_user_id ?? "",
          "query": {},
          "store_id": widget.storeId,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          final methods = List<Map<String, dynamic>>.from(data['response']);
          if (mounted) {
            setState(() {
              _orderMethods = methods;
              // Maintain selection if still valid, else default
              if (_selectedOrderMethod == null ||
                  !methods.any((m) => m['id'] == _selectedOrderMethod!['id'])) {
                _selectedOrderMethod = methods.firstWhere(
                  (m) => m['is_enabled'] == true,
                  orElse: () => methods.isNotEmpty ? methods.first : {},
                );
              }
              _isOrderMethodsLoading = false;
            });
          }
        }
      } else {
        if (mounted) setState(() => _isOrderMethodsLoading = false);
      }
    } catch (e) {
      print("Error fetching order methods: $e");
      if (mounted) setState(() => _isOrderMethodsLoading = false);
    }
  }

  Future<void> _fetchUserAddresses() async {
    try {
      final response = await ApiService.post(
        '/user-address/',
        body: {
          "store_id": widget.storeId,
          "customer_user_id": customer_user_id ?? "",
          "query": {},
          "store_access": true,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          final addresses = List<Map<String, dynamic>>.from(data['response']);
          if (addresses.isNotEmpty) {
            setState(() {
              selected_address_id = addresses[0]['id'];
            });
          }
        }
      }
    } catch (e) {
      print("Error fetching user addresses: $e");
    }
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

  Future<void> _fetchProductsByCategory(
    String categoryId, {
    bool isRefresh = false,
  }) async {
    try {
      if (!isRefresh) {
        setState(() {
          _isProductsLoading = true;
          _productsError = null;
          _currentPage = 1; // Reset to first page
          _hasMoreProducts = true; // Assume there might be more
        });
      } else {
        setState(() {
          _productsError = null;
          _currentPage = 1;
          _hasMoreProducts = true;
        });
      }

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
          'customer_user_id': customer_user_id ?? '',
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
            _products = [];
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
    if (_isLoadingMore || !_hasMoreProducts) {
      return;
    }

    final isSearching = _searchController.text.isNotEmpty;
    if (!isSearching && _selectedCategoryId == null) {
      return;
    }

    try {
      setState(() {
        _isLoadingMore = true;
      });

      _currentPage++; // Increment page

      dynamic response;

      if (isSearching) {
        response = await ApiService.post(
          '/search-in-store/',
          body: {
            "customer_user_id": customer_user_id ?? "",
            "is_store": false,
            "lat": _lat,
            "lng": _lng,
            "page": _currentPage,
            "query": _searchController.text,
            "store_access": true,
            "store_id": widget.storeId,
          },
          useBearerToken: true,
        );
      } else {
        // Use the same query logic as _fetchProductsByCategory
        final queryParam = _selectedCategoryId == 'all'
            ? {}
            : {'parent_category_id': _selectedCategoryId};

        response = await ApiService.post(
          '/product/',
          body: {
            'store_id': widget.storeId,
            'query': queryParam,
            'page': _currentPage,
            'store_access': true,
            'customer_user_id': customer_user_id ?? '',
          },
          useBearerToken: true,
        );
      }

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          final newProducts = List<Map<String, dynamic>>.from(data['response']);
          setState(() {
            _products.addAll(newProducts); // Append new products
            _isLoadingMore = false;

            if (isSearching) {
              _hasMoreProducts = data['has_next'] ?? false;
            } else {
              // If we got fewer products than expected, there might not be more
              _hasMoreProducts = newProducts.length >= 10;
            }
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

  Future<void> _initLocationAndCart() async {
    try {
      await _getCurrentLocation();
    } catch (e) {
      print('Error getting location: $e');
    }
    if (mounted) await _fetchOrderMethods();
    if (mounted) await _fetchUserAddresses();
    if (mounted) _validateCart();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    if (mounted) {
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
      });
    }
  }

  Future<void> _validateCart() async {
    try {
      final response = await ApiService.post(
        '/auto-validate-cart/',
        body: {
          'store_id': widget.storeId,
          'order_method_id':
              _selectedOrderMethod?['id'] ?? null, // Default order method
          'user_address_id': selected_address_id ?? null, // Default address
          'lat': _lat,
          'lng': _lng,
          'store_access': true,
          'customer_user_id': customer_user_id ?? '',
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final Map<String, dynamic> responseData = Map<String, dynamic>.from(
          response['data'],
        );

        // If 'response' is a map (nested data), merge it into the top level
        if (responseData['response'] is Map) {
          responseData.addAll(
            Map<String, dynamic>.from(responseData['response']),
          );
        }

        _updateCartState(responseData);
      }
    } catch (e) {
      print('Error validating cart: $e');
    }
  }

  void _updateCartState(Map<String, dynamic> data) {
    if (mounted) {
      setState(() {
        _totalProductsInCart = data['total_products_in_cart'] ?? 0;

        // Robustly fetch items from either key directly
        final items =
            data['items_available'] ?? data['validated_cart_data'] ?? [];
        _cartItemsAvailable = List<Map<String, dynamic>>.from(items);

        // 'items_unavailable' is usually only in auto-validate-cart response
        _cartItemsUnavailable = List<Map<String, dynamic>>.from(
          data['items_unavailable'] ?? [],
        );

        _grandTotal = (data['grand_total'] ?? 0.0).toDouble();
        _cartData = data;
      });
    }
  }

  Future<void> _incrementCartItem(
    String productCombinationId,
    String productId,
  ) async {
    try {
      // Optimistic update (optional, but good for UI)
      // For now, we wait for API

      final response = await ApiService.post(
        '/increment-product-in-cart/',
        body: {
          "store_id": widget.storeId,
          "product_id": productId,
          "customer_user_id": customer_user_id ?? '',
          "product_combination_id": productCombinationId,
          "store_access": true,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        // We call validateCart to ensure we get the FULL updated cart,
        // as increment/decrement might return partial structure.
        await _validateCart();
        // Refresh products to show updated counters from API
        _fetchProductsByCategory(_selectedCategoryId ?? 'all', isRefresh: true);
      }
    } catch (e) {
      print('Error incrementing item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TranslatedText('Error updating cart: $e')),
      );
    }
  }

  Future<void> _decrementCartItem(
    String productCombinationId,
    String productId,
  ) async {
    try {
      final response = await ApiService.post(
        '/decrement-product-in-cart/',
        body: {
          "store_id": widget.storeId,
          "product_id": productId,
          "customer_user_id": customer_user_id ?? '',
          "product_combination_id": productCombinationId,
          "store_access": true,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        // We call validateCart to ensure we get the FULL updated cart.
        await _validateCart();
        // Refresh products to show updated counters from API
        _fetchProductsByCategory(_selectedCategoryId ?? 'all', isRefresh: true);
      }
    } catch (e) {
      print('Error decrementing item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TranslatedText('Error updating cart: $e')),
      );
    }
  }

  /// Get total quantity of a product in cart (sum of all variations)
  int _getProductQuantityInCart(Map<String, dynamic> product) {
    // First, check if the product object itself has a quantity (from /product API)
    if (product.containsKey('quantity') && product['quantity'] != null) {
      final q = (product['quantity'] as num).toInt();
      if (q > 0) return q;
    }

    // Fallback: Calculate from local cart items list
    int qty = 0;
    final productId = product['id']?.toString() ?? '';
    if (productId.isEmpty) return 0;

    for (var item in _cartItemsAvailable) {
      final itemProductId = item['product_id']?.toString();
      final itemId = item['id']?.toString();

      if (itemProductId == productId || itemId == productId) {
        final q = item['enquired_quantity'] ?? item['quantity'];
        qty += (q as num? ?? 0).toInt();
      }
    }
    return qty;
  }

  Future<void> _fetchStoreBankDetails() async {
    try {
      // setState(() => _isBankDetailsLoading = true);
      final response = await ApiService.post(
        '/store-bank-details/',
        body: {
          "store_id": widget.storeId,
          "store_access": true,
          "create": false,
          "query": {"is_active": true},
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          setState(() {
            _bankDetails = List<Map<String, dynamic>>.from(data['response']);
          });
        }
      }
    } catch (e) {
      print("Error fetching bank details: $e");
    } finally {
      // setState(() => _isBankDetailsLoading = false);
    }
  }

  void _showMultiModeDialog(StateSetter setSheetState) {
    // Initialize controllers with 0 or split equally? Let's start with 0.
    // We need to track values for each bank detail.
    final Map<String, TextEditingController> controllers = {};
    String? defaultModeId;

    // Find default mode and initialize controllers
    for (var bank in _bankDetails) {
      controllers[bank['id']] = TextEditingController(text: '');
      if (bank['is_default'] == true) {
        defaultModeId = bank['id'];
      }
    }

    // Fallback if no default found
    if (defaultModeId == null && _bankDetails.isNotEmpty) {
      defaultModeId = _bankDetails.last['id'];
    }

    // Set initial value for default mode to grand total
    if (defaultModeId != null) {
      controllers[defaultModeId]!.text = _grandTotal.toStringAsFixed(2);
    }

    double currentTotal = _grandTotal;
    String errorText = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void updateCalculations(String changedId) {
              // If we are editing a non-default field, update the default field
              if (defaultModeId != null && changedId != defaultModeId) {
                double otherSum = 0.0;
                controllers.forEach((id, controller) {
                  if (id != defaultModeId) {
                    otherSum += double.tryParse(controller.text) ?? 0.0;
                  }
                });

                double remaining = _grandTotal - otherSum;
                controllers[defaultModeId]!.text = remaining.toStringAsFixed(2);
              }

              // Recalculate total for validation
              double sum = 0.0;
              controllers.forEach((_, controller) {
                sum += double.tryParse(controller.text) ?? 0.0;
              });

              setState(() {
                currentTotal = sum;
                if ((currentTotal - _grandTotal).abs() > 0.01) {
                  errorText =
                      'Total must match ₹${_grandTotal.toStringAsFixed(2)}';
                } else {
                  errorText = '';
                }
              });
            }

            return AlertDialog(
              title: const TranslatedText('Multi-Mode Payment'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grand Total: ₹${_grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _bankDetails.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final bank = _bankDetails[index];
                          final label = bank['bank_name'] != null
                              ? "${bank['bank_name']} (${bank['account_number_or_upi_id']})"
                              : bank['account_holder_name'] ??
                                    bank['account_number_or_upi_id'];
                          return TextField(
                            controller: controllers[bank['id']],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: label,
                              border: const OutlineInputBorder(),
                              prefixText: '₹ ',
                            ),
                            onChanged: (_) =>
                                updateCalculations(bank['id'].toString()),
                          );
                        },
                      ),
                    ),
                    if (errorText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '$errorText (Current: ₹${currentTotal.toStringAsFixed(2)})',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setSheetState(() {
                      _selectedPaymentMode = 'UNPAID';
                    });
                  },
                  child: const TranslatedText('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      errorText.isEmpty &&
                          (currentTotal - _grandTotal).abs() < 0.01
                      ? () {
                          Navigator.pop(context);
                          // Save the values
                          _multiModeValues.clear();
                          controllers.forEach((id, controller) {
                            final val = double.tryParse(controller.text) ?? 0.0;
                            if (val > 0) {
                              _multiModeValues[id] = val;
                            }
                          });
                          setSheetState(() {
                            // Multi-mode confirmed
                          });
                        }
                      : null,
                  child: const TranslatedText('Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _reviewOrder() async {
    if (_cartItemsAvailable.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: TranslatedText('Cart is empty')));
      return;
    }

    if (customer_user_id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText('Please select a customer')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await ApiService.post(
        '/order-init/',
        body: {
          "customer_user_id": customer_user_id,
          "lat": _lat,
          "lng": _lng,
          "order_method_id": _selectedOrderMethod?['id'],
          "payment_method_id": _selectedPaymentMethodId,
          "store_access": true,
          "store_id": widget.storeId,
          "user_address_id": selected_address_id,
        },
        useBearerToken: true,
      );

      // Hide loading
      if (mounted) Navigator.pop(context);

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200) {
          // Close cart sheet
          if (mounted) Navigator.pop(context);

          // Show Review/Summary Popup
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (context) => ReviewOrderScreen(
                  data: Map<String, dynamic>.from(data['response']),
                  onPlaceOrder: () {
                    // Trigger actual order placement
                    _confirmPlaceOrder();
                  },
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? 'Review failed')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: TranslatedText('Review failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Hide loading
      print("Error reviewing order: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _sendDeviceData() async {
    try {
      await ApiService.post(
        '/add-user-devices/',
        body: {
          "software_version": 1,
          "device_id": "device_unknown",
          "device_brand": "BrandName",
          "device_model": "ModelName",
          "os_version": "1.0.0",
          "last_online": DateTime.now().millisecondsSinceEpoch,
          "browser":
              "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Mobile Safari/537.36",
          "device_build_id": "build123",
          "mac_address": "00:00:00:00:00:00",
          "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
          "platform":
              "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Mobile Safari/537.36",
          "language": "en-US",
          "app_name": "AppName",
          "app_version": "1.0.0",
          "screen_width": "1150",
          "screen_height": "1016",
          "device_pixel_ratio": "2",
          "screen_orientation": "landscape-primary",
          "color_depth": "24",
          "cookies_enabled": "true",
          "network_effective_type": "unknown",
          "network_rtt": "unknown",
          "network_downlink": "unknown",
          "customer_user_id": customer_user_id ?? "",
          "store_access": true,
          "store_id": widget.storeId,
        },
        useBearerToken: true,
      );
      print("Device Data Created Successfully");
    } catch (e) {
      print("Error sending device data: $e");
    }
  }

  Future<void> _confirmPlaceOrder() async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Send device data before placing order
      await _sendDeviceData();

      dynamic response;
      if (_selectedPaymentMode == 'UNPAID') {
        response = await ApiService.post(
          '/place-order/',
          body: {
            "customer_user_id": customer_user_id,
            "lat": _lat,
            "lng": _lng,
            "order_method_id": _selectedOrderMethod?['id'],
            "payment_method_id": _selectedPaymentMethodId,
            "store_access": true,
            "store_id": widget.storeId,
            "user_address_id": selected_address_id,
            "coupon_code": "",
          },
          useBearerToken: true,
        );
      } else {
        // Construct payment_methods array
        List<Map<String, dynamic>> paymentMethodsList = [];

        if (_selectedPaymentMode == 'MULTI-MODE') {
          _multiModeValues.forEach((key, value) {
            if (value > 0) {
              paymentMethodsList.add({
                "payment_method_store_bank_id": key,
                "amount": value,
              });
            }
          });
        } else {
          // Single bank selected (not UNPAID, not MULTI-MODE)
          paymentMethodsList.add({
            "payment_method_store_bank_id": _selectedPaymentMode,
            "amount": _grandTotal,
          });
        }

        response = await ApiService.post(
          '/place-order-with-completion/',
          body: {
            "customer_user_id": customer_user_id,
            "lat": _lat,
            "lng": _lng,
            "order_method_id": _selectedOrderMethod?['id'],
            "payment_method_id": _selectedPaymentMethodId,
            "store_access": true,
            "store_id": widget.storeId,
            "user_address_id": selected_address_id,
            "payment_methods": paymentMethodsList,
            "coupon_code": "",
          },
          useBearerToken: true,
        );
      }

      // Hide loading
      if (mounted) Navigator.pop(context);

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200) {
          // Close the Summary Popup
          if (mounted) Navigator.pop(context);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: TranslatedText('Order placed successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            // Refresh
            _initLocationAndCart();
            _fetchProductsByCategory(
              _selectedCategoryId ?? 'all',
              isRefresh: true,
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['message'] ?? 'Order placement failed'),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: TranslatedText('Order placement failed')),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      print("Error placing order: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        bool showDetails = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                final theme = Theme.of(context);
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
                          TranslatedText(
                            'Cart ($_totalProductsInCart ${_totalProductsInCart == 1 ? 'item' : 'items'})',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
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
                                  const Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  TranslatedText(
                                    'Your cart is empty',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                  TranslatedText(
                                                    item['product_name'] ?? '',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  // Cart Counter
                                                  Container(
                                                    decoration: BoxDecoration(
                                                      border: Border.all(
                                                        color:
                                                            Colors.grey[300]!,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        InkWell(
                                                          onTap: () async {
                                                            await _decrementCartItem(
                                                              item['product_combination_id'] ??
                                                                  '',
                                                              item['product_id'] ??
                                                                  '',
                                                            );
                                                            // Update sheet state
                                                            setSheetState(
                                                              () {},
                                                            );
                                                          },
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                            child: Icon(
                                                              Icons.remove,
                                                              size: 16,
                                                              color: theme
                                                                  .primaryColor,
                                                            ),
                                                          ),
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                              ),
                                                          child: TranslatedText(
                                                            '${item['enquired_quantity']}',
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ),
                                                        InkWell(
                                                          onTap: () async {
                                                            await _incrementCartItem(
                                                              item['product_combination_id'] ??
                                                                  '',
                                                              item['product_id'] ??
                                                                  '',
                                                            );
                                                            // Update sheet state
                                                            setSheetState(
                                                              () {},
                                                            );
                                                          },
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4,
                                                                ),
                                                            child: Icon(
                                                              Icons.add,
                                                              size: 16,
                                                              color: theme
                                                                  .primaryColor,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            TranslatedText(
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
                                            padding: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.red[50],
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: TranslatedText(
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
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setSheetState(() {
                                          showDetails = !showDetails;
                                        });
                                      },
                                      child: TranslatedText(
                                        'Grand Total',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        showDetails
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                      ),
                                      onPressed: () {
                                        setSheetState(() {
                                          showDetails = !showDetails;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                TranslatedText(
                                  '₹${_grandTotal.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                ),
                              ],
                            ),
                            if (showDetails && _cartData != null) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    if (_cartData!['cart_total'] != null)
                                      ...(_cartData!['cart_total'] as List).map(
                                        (e) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              TranslatedText(
                                                e['title'] ?? '',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                              TranslatedText(
                                                '₹${e['value']?.toString() ?? '0.0'}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (_cartData!['platform_fees'] != null)
                                      ...(_cartData!['platform_fees'] as List).map(
                                        (e) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              TranslatedText(
                                                e['title'] ?? '',
                                                style: TextStyle(
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                              TranslatedText(
                                                '₹${e['value']?.toString() ?? '0.0'}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                // Payment Method Dropdown
                                Expanded(
                                  flex: 2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedPaymentMode,
                                        isExpanded: true,
                                        hint: const TranslatedText(
                                          'Select Mode',
                                        ),
                                        items: [
                                          const DropdownMenuItem(
                                            value: 'UNPAID',
                                            child: TranslatedText('UNPAID'),
                                          ),
                                          const DropdownMenuItem(
                                            value: 'MULTI-MODE',
                                            child: TranslatedText('MULTI-MODE'),
                                          ),
                                          ..._bankDetails.map((bank) {
                                            final label =
                                                bank['bank_name'] != null
                                                ? "${bank['bank_name']} - ${bank['account_holder_name']}"
                                                : bank['account_holder_name'] ??
                                                      'Unknown';
                                            return DropdownMenuItem(
                                              value: bank['id'].toString(),
                                              child: Text(
                                                label,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) {
                                            if (value == 'MULTI-MODE') {
                                              setSheetState(() {
                                                _selectedPaymentMode = value;
                                              });
                                              _showMultiModeDialog(
                                                setSheetState,
                                              );
                                            } else {
                                              setSheetState(() {
                                                _selectedPaymentMode = value;
                                              });
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Checkout Button
                                Expanded(
                                  flex: 3,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      _reviewOrder();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const TranslatedText(
                                      'Review Order',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
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
        _currentPage = 1;
      });

      final response = await ApiService.post(
        '/search-in-store/',
        body: {
          "customer_user_id": customer_user_id ?? "",
          "is_store": false,
          "lat": _lat,
          "lng": _lng,
          "page": _currentPage,
          "query": query,
          "store_access": true,
          "store_id": widget.storeId,
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
            _hasMoreProducts = data['has_next'] ?? false;
          });
        } else {
          setState(() {
            _products = [];
            _productsError = 'No products found for "$query"';
            _isProductsLoading = false;
            _hasMoreProducts = false;
          });
        }
      } else {
        setState(() {
          _productsError = 'Search failed';
          _isProductsLoading = false;
          _hasMoreProducts = false;
        });
      }
    } catch (e) {
      setState(() {
        _productsError = 'Search error: $e';
        _isProductsLoading = false;
        _hasMoreProducts = false;
      });
    }
  }

  Future<void> _fetchPaymentMethods() async {
    try {
      final response = await ApiService.post(
        '/payment-method/',
        body: {
          "store_id": widget.storeId,
          "customer_user_id": customer_user_id ?? '',
          "query": {},
          "store_access": true,
          "order_by": "payment_method_template_id",
          "view": true,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] is List) {
          final methods = List<Map<String, dynamic>>.from(data['response']);
          final payOnDelivery = methods.firstWhere(
            (m) => m['payment_method_name'] == 'Pay on Delivery',
            orElse: () => {},
          );

          if (payOnDelivery.isNotEmpty) {
            setState(() {
              _selectedPaymentMethodId = payOnDelivery['id'];
            });
            print('Selected Payment Method ID: $_selectedPaymentMethodId');
          }
        }
      }
    } catch (e) {
      print('Error fetching payment methods: $e');
    }
  }

  Widget _buildDrawer(ThemeData theme) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Close Button or Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildDrawerItem(
                    theme,
                    icon: Icons.store_mall_directory_outlined,
                    title: 'Change Store',
                    textColor: Colors.red.shade700,
                    iconColor: Colors.red.shade700,
                    isBold: true,
                    onTap: () async {
                      // Clear selected store preference to force store selection logic to run correctly
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('selected_store_id');
                      await prefs.remove('selected_store_name');

                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StoreSelectionScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                  ),
                  _buildDrawerItem(
                    theme,
                    icon: Icons.speed,
                    title: 'Overview',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OverviewScreen(
                            storeId: widget.storeId,
                            ownerName: _ownerName ?? 'Store Owner',
                          ),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    theme,
                    icon: Icons.point_of_sale,
                    title: 'Sales Panel',
                    isBold: true,
                    prefixText: 'POS',
                    onTap: () => Navigator.pop(context), // Already here
                  ),
                  _buildDrawerItem(
                    theme,
                    icon: Icons.inventory_2_outlined,
                    title: 'Products',
                    onTap: () {},
                  ),
                  _buildDrawerItem(
                    theme,
                    icon: Icons.warehouse_outlined,
                    title: 'Inventory',
                    onTap: () {},
                  ),
                  _buildDrawerItem(
                    theme,
                    icon: Icons.local_shipping_outlined,
                    title: 'Orders',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              OrdersListScreen(storeId: widget.storeId),
                        ),
                      );
                    },
                  ),
                  _buildDrawerItem(
                    theme,
                    icon: Icons.confirmation_number_outlined,
                    title: 'Coupons',
                    iconColor: Colors.pinkAccent,
                    backgroundColor: Colors.blue.withOpacity(0.05),
                    textColor: Colors.blue,
                    onTap: () {},
                  ),

                  // Accounting Expansion Tile
                  Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Colors.grey[700],
                      ),
                      title: Text(
                        'Accounting',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      childrenPadding: const EdgeInsets.only(left: 16),
                      initiallyExpanded: true,
                      children: [
                        _buildDrawerItem(
                          theme,
                          icon: Icons.shopping_bag_outlined,
                          title: 'Purchases',
                          small: true,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PurchaseScreen(storeId: widget.storeId),
                              ),
                            );
                          },
                        ),
                        _buildDrawerItem(
                          theme,
                          icon: Icons.receipt_long_outlined,
                          title: 'Sales',
                          small: true,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SalesScreen(storeId: widget.storeId),
                              ),
                            );
                          },
                        ),
                        _buildDrawerItem(
                          theme,
                          icon: Icons.storefront_outlined,
                          title: 'Suppliers',
                          small: true,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SuppliersListScreen(
                                  storeId: widget.storeId,
                                ),
                              ),
                            );
                          },
                        ),
                        _buildDrawerItem(
                          theme,
                          icon: Icons.people_outline,
                          title: 'Customers',
                          small: true,
                          onTap: () {},
                        ),
                        _buildDrawerItem(
                          theme,
                          icon: Icons.payment,
                          title: 'Payments',
                          small: true,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PaymentScreen(storeId: widget.storeId),
                              ),
                            );
                          },
                        ),
                        _buildDrawerItem(
                          theme,
                          icon: Icons.receipt,
                          title: 'Receipts',
                          small: true,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ReceiptsScreen(storeId: widget.storeId),
                              ),
                            );
                          },
                        ),
                        _buildDrawerItem(
                          theme,
                          icon: Icons.menu_book_outlined,
                          title: 'Ledger',
                          small: true,
                          onTap: () {},
                        ),
                        _buildDrawerItem(
                          theme,
                          icon: Icons.description_outlined,
                          title: 'Invoices',
                          small: true,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),

                  _buildDrawerItem(
                    theme,
                    icon: Icons.insert_chart_outlined,
                    title: 'Reports',
                    onTap: () {},
                  ),
                  _buildDrawerItem(
                    theme,
                    icon: Icons.calendar_month_outlined,
                    title: 'Financial Years',
                    onTap: () {},
                  ),
                  _buildDrawerItem(
                    theme,
                    icon: Icons.percent,
                    title: 'GST Rates',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              GstRatesScreen(storeId: widget.storeId),
                        ),
                      );
                    },
                  ),

                  // Reports Expansion Tile (Second one in image list)
                  Theme(
                    data: theme.copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: Icon(
                        Icons.analytics_outlined,
                        color: Colors.grey[700],
                      ),
                      title: Text(
                        'Reports',
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      childrenPadding: const EdgeInsets.only(left: 16),
                      children: [
                        _buildDrawerItem(
                          theme,
                          icon: Icons.bar_chart,
                          title: 'Sales Report',
                          small: true,
                          onTap: () {},
                        ),
                        // Add more sub-reports as needed
                      ],
                    ),
                  ),

                  _buildDrawerItem(
                    theme,
                    icon: Icons.manage_accounts_outlined,
                    title: 'Staff Management',
                    onTap: () {},
                  ),

                  const Divider(height: 32),

                  _buildDrawerItem(
                    theme,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {},
                  ),

                  const SizedBox(height: 20),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isBold = false,
    String? prefixText,
    Color? iconColor,
    Color? textColor,
    Color? backgroundColor,
    bool small = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: small,
        visualDensity: small ? VisualDensity.compact : null,
        onTap: onTap,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (prefixText != null) ...[
              Text(
                prefixText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              icon,
              color: iconColor ?? Colors.grey[700],
              size: small ? 20 : 24,
            ),
          ],
        ),
        title: Text(
          title,
          style: TextStyle(
            color: textColor ?? Colors.grey[800],
            fontSize: small ? 14 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
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

  // Customer Phone Bottom Sheet
  void _showCustomerPhoneDialog() {
    final TextEditingController phoneController = TextEditingController();
    CountryCode selectedCountry = CountryCode.fromCountryCode('IN');
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Calculate keyboard height to prevent overflow
            final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

            return Container(
              height:
                  600 +
                  bottomPadding, // Allow height expansion but keep it controlled
              constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height * 0.9, // Max 90% screen
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 40,
                    offset: Offset(0, -10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(32),
                ),
                child: Stack(
                  children: [
                    // Decorative Gradient Blob 1
                    Positioned(
                      top: -100,
                      right: -50,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    // Decorative Gradient Blob 2
                    Positioned(
                      top: 50,
                      left: -80,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),

                    // Main Scrollable Content
                    SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        24,
                        24,
                        bottomPadding + 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Handle Bar
                          Center(
                            child: Container(
                              width: 48,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(2.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Header Icon
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                size: 40,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title & Subtitle
                          const Center(
                            child: TranslatedText(
                              'New Sale Session',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // "Why" Section (Integrated)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F9FF), // Light blue tint
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFBAE6FD).withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.tips_and_updates_rounded,
                                    size: 20,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const TranslatedText(
                                        'Why link a customer?',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF0C4A6E),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      TranslatedText(
                                        'Linking enables loyalty rewards, purchase tracking, and personalized offers.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blueGrey[700],
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Phone Input Field
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[300]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: CountryCodePicker(
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
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: phoneController,
                                    keyboardType: TextInputType.phone,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Phone Number',
                                      hintStyle: TextStyle(
                                        color: Colors.grey[400],
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // OR Divider
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: Colors.grey[200],
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  "OR",
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.grey[200],
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // Scan QR Button (Big & Clean)
                          InkWell(
                            onTap: () async {
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
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: Colors.blue[800],
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  TranslatedText(
                                    'Scan Customer QR Code',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blueGrey[800],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Bottom Actions
                          Row(
                            children: [
                              // Guest Button
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    if (isLoading) return;
                                    Navigator.pop(context); // Continue as guest
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    foregroundColor: Colors.grey[600],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const TranslatedText(
                                    'Skip & Continue',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Start Session Button
                              Expanded(
                                flex: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF2563EB),
                                        Color(0xFF1D4ED8),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF2563EB,
                                        ).withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: isLoading
                                        ? null
                                        : () async {
                                            final phone = phoneController.text
                                                .trim();
                                            if (phone.isEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: TranslatedText(
                                                    'Please enter a phone number',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                              return;
                                            }

                                            setState(() {
                                              isLoading = true;
                                            });

                                            final countryCode =
                                                selectedCountry.dialCode
                                                    ?.replaceAll('+', '') ??
                                                '91';
                                            final fullPhoneNumber =
                                                '$countryCode$phone';

                                            try {
                                              await _fetchCustomerData(
                                                fullPhoneNumber,
                                              );
                                              if (mounted) {
                                                Navigator.pop(context);
                                              }
                                            } catch (e) {
                                              setState(() {
                                                isLoading = false;
                                              });
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: TranslatedText(
                                                      'Error: ${e.toString()}',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const TranslatedText(
                                            'Start Session',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
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
              _currentCustomer = userData;
            });

            // Refresh products and cart with new customer ID
            if (customer_user_id != null) {
              await _fetchOrderMethods();
              await _fetchUserAddresses();
              _fetchProductsByCategory(_selectedCategoryId ?? 'all');
              _validateCart();
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: TranslatedText(
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

    // Use a lighter/white background for modern look
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(theme),
      backgroundColor: Colors.grey[50], // Lighter background
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBanner(theme),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categories Sidebar (Premium Left Layout)
                  _buildCategoriesSidebar(theme),

                  // Products Grid
                  Expanded(child: _buildProductsGrid(theme)),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _totalProductsInCart > 0
          ? FloatingActionButton.extended(
              onPressed: _showCartBottomSheet,
              backgroundColor: theme.primaryColor,
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: Text(
                '$_totalProductsInCart Items • ₹${_grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  void _showCustomerProfileDialog() {
    if (_currentCustomer == null) {
      _showCustomerPhoneDialog();
      return;
    }

    final theme = Theme.of(context);
    final user = _currentCustomer!;

    // Extract data with fallbacks
    final firstName = user['first_name'] ?? 'Guest';
    final lastName = user['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final phone = user['phone_number']?.toString() ?? 'N/A';
    final email = user['email'] ?? 'unregistereduser@exanor.com';

    // Scores (Using -1/Defaults if not present)
    final creditScore = user['credit_score'] ?? -1;
    final loyaltyScore = user['loyalty_score'] ?? -1;
    final behaviourScore = user['behaviour_score'] ?? -1;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 340, // Fixed width for consistent look
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.05),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_outline,
                    size: 40,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Name
              TranslatedText(
                fullName,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TranslatedText(
                    '+$phone', // Assuming phone is number w/o + or has country code
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TranslatedText(
                email,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[500],
                ),
              ),

              const SizedBox(height: 24),

              // Change Customer Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showCustomerPhoneDialog();
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const TranslatedText('Change Customer'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // Scores
              _buildScoreRow(creditScore, loyaltyScore, behaviourScore),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreRow(dynamic credit, dynamic loyalty, dynamic behaviour) {
    return Column(
      children: [
        _buildScoreItem(credit, 'Credit Score', 'Fair', Colors.blue),
        const SizedBox(height: 16),
        _buildScoreItem(loyalty, 'Loyalty Score', 'New', Colors.green),
        const SizedBox(height: 16),
        _buildScoreItem(
          behaviour,
          'Behaviour Score',
          'Needs attention',
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildScoreItem(
    dynamic score,
    String label,
    String subLabel,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: TranslatedText(
              '$score',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TranslatedText(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            TranslatedText(
              subLabel, // This might need logic based on score
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopBanner(ThemeData theme) {
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
                  Icons.storefront_rounded,
                  size: 180,
                  color: watermarkColor.withOpacity(0.6),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Menu Button (with label)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TranslatedText(
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
                              Icons.menu_rounded,
                              color: Colors.blueGrey,
                              size: 32,
                            ),
                            onPressed: () {
                              _scaffoldKey.currentState?.openDrawer();
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Store Name & Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TranslatedText(
                              widget.storeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B), // Slate 800
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
                              child: TranslatedText(
                                'POINT OF SALE',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.blue[800],
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Customer Profile Button (with label and bigger size)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TranslatedText(
                            'USER STATS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.blueGrey[400],
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: _showCustomerProfileDialog,
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.all(10),
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
                              child: const Icon(
                                Icons.person_rounded,
                                color: Colors.blueGrey,
                                size: 28, // Bigger size
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return SizeTransition(
                            sizeFactor: animation,
                            axis: Axis.horizontal,
                            axisAlignment: -1.0,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                    child: _isSearchExpanded
                        ? _buildExpandedSearch()
                        : _buildDefaultOptionsBar(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedSearch() {
    return Container(
      height: 68, // Match height of DefaultOptionsBar (Label + Box)
      alignment: Alignment.bottomCenter,
      key: const ValueKey('expanded_search'), // Key for AnimatedSwitcher
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1565C0), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search products by name, code...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF1565C0),
              size: 24,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _isListening
                      ? _stopVoiceSearch
                      : _startVoiceSearch,
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none_rounded,
                    size: 22,
                  ),
                  color: _isListening ? Colors.red : Colors.grey[600],
                  tooltip: 'Voice Search',
                ),
                Container(
                  height: 24,
                  width: 1,
                  color: Colors.grey[300],
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 22,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _isSearchExpanded = false;
                      if (_selectedCategoryId != null) {
                        _fetchProductsByCategory(_selectedCategoryId!);
                      }
                    });
                  },
                ),
              ],
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 16,
            ),
          ),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildDefaultOptionsBar() {
    return Row(
      key: const ValueKey('default_options'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Order Method (Dominant)
        Expanded(
          flex: 11, // Increased flex space
          child: _buildActionBox(
            label: 'Order Type',
            iconColor: const Color(0xFFE65100),
            child: !_isOrderMethodsLoading
                ? InkWell(
                    onTap: _showOrderMethodSelection,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Icon(
                            Icons.room_service_outlined,
                            size: 18,
                            color: const Color(0xFFE65100),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TranslatedText(
                                  _selectedOrderMethod?['order_method_name'] ??
                                      'Select Type',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),
                    ),
                  )
                : const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
          ),
        ),

        const SizedBox(width: 12),

        // Search Action (Compact)
        Expanded(
          flex: 5, // Slightly bigger than 2/9 proportions
          child: InkWell(
            onTap: () {
              setState(() {
                _isSearchExpanded = true;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: _buildActionBox(
              label: 'Search',
              iconColor: const Color(0xFF1565C0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TranslatedText(
                        "Search",
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Scanner Action
        Expanded(
          flex: 4, // Adjusted to maintain ratio
          child: InkWell(
            onTap: _openQRScanner,
            borderRadius: BorderRadius.circular(12),
            child: _buildActionBox(
              label: 'Scan',
              iconColor: Colors.black87,
              child: const Center(
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 20,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBox({
    required String label,
    required Widget child,
    Color? iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 3),
          child: Row(
            children: [
              if (iconColor != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: iconColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              TranslatedText(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.blueGrey[600],
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 40, // Reduced height for less chunky look
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey[300]!,
              width: 1.5,
            ), // Stronger Border
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05), // Softer, deeper shadow
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        ),
      ],
    );
  }

  Future<void> _syncCategories() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final response = await ApiService.post(
        '/sync-product-categories-with-stores/',
        body: {'store_id': widget.storeId},
        useBearerToken: true,
      );

      if (mounted) Navigator.pop(context); // Close loading dialog

      if (response['statusCode'] == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatedText(
                'Product categories synced successfully.',
              ),
              backgroundColor: Colors.green,
            ),
          );
          _fetchCategories(); // Refresh categories
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: TranslatedText(
                response['message'] ?? 'Failed to sync categories',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close dialog if open
      print('Error syncing categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText(
              'An error occurred while syncing categories',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildCategoriesSidebar(ThemeData theme) {
    // Premium Sidebar Design
    const width = 100.0; // Compact width

    if (_isCategoriesLoading) {
      return Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: Colors.grey[200]!)),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_categoriesError != null) {
      return Container(
        width: width,
        color: Colors.white,
        child: Center(
          child: Icon(Icons.error_outline, color: Colors.grey[400]),
        ),
      );
    }

    return Container(
      width: width,
      decoration: BoxDecoration(
        // Innovative: Subtle gradient for depth and premium feel
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFEFF6FF), // Start with light blue
            Color(0xFFDBEAFE), // Gentlest fade to deeper blue
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(
              0.08,
            ), // Soft shadow for lifting effect
            blurRadius: 15,
            offset: const Offset(5, 0),
            spreadRadius: 1,
          ),
        ],
        border: Border(right: BorderSide(color: Colors.black.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => Divider(
                color: Colors.black.withOpacity(0.05), // Light black divider
                height: 16,
                thickness: 1,
                indent: 8,
                endIndent: 8,
              ),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category['id'] == _selectedCategoryId;

                final categoryKey = GlobalObjectKey(category['id']);

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = category['id'];
                      _searchController.clear();
                    });
                    _fetchProductsByCategory(category['id']);

                    // Ensure the selected item is fully visible after expansion
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (categoryKey.currentContext != null) {
                        Scrollable.ensureVisible(
                          categoryKey.currentContext!,
                          alignment: 0.5, // Center it in the list
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    });
                  },
                  child: AnimatedContainer(
                    key: categoryKey,
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 10, // Slightly more padding
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.primaryColor.withOpacity(0.08)
                          : Colors.transparent,
                      border: isSelected
                          ? Border(
                              left: BorderSide(
                                color: theme.primaryColor,
                                width: 3,
                              ),
                            )
                          : const Border(
                              left: BorderSide(
                                color: Colors.transparent,
                                width: 3,
                              ),
                            ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment:
                          CrossAxisAlignment.start, // Left align content
                      children: [
                        // Show image only if selected
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CustomCachedNetworkImage(
                                  // Use sample image if icon is null for visualization
                                  imgUrl:
                                      category['category_icon'] ??
                                      'https://images.unsplash.com/photo-1542838132-92c53300491e?q=80&w=200&auto=format&fit=crop',
                                  width: 80, // Large rectangular image
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),

                        TranslatedText(
                          _capitalizeCategoryName(
                            category['category_name'] ?? '',
                          ),
                          textAlign: TextAlign.left, // Left align text
                          maxLines: 2, // Sophisticated limit
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: isSelected
                                ? theme.primaryColor
                                : Colors.blueGrey[800],
                            height: 1.2, // Improved typography
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: () async {
        final cartFuture = _validateCart();
        final productsFuture = _fetchProductsByCategory(
          _selectedCategoryId ?? 'all',
          isRefresh: true,
        );
        await Future.wait([cartFuture, productsFuture]);
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_isProductsLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_productsError != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    TranslatedText(
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
                      child: const TranslatedText('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_products.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    TranslatedText(
                      'No products found',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65, // Taller card for bigger image
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = _products[index];
                  return _buildProductCard(theme, product);
                }, childCount: _products.length),
              ),
            ),
          // Loading indicator at the bottom when loading more
          if (!_isProductsLoading && _isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          // Show "No more products" message if at end
          if (!_isProductsLoading && !_hasMoreProducts && _products.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: TranslatedText(
                    'No more products',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ThemeData theme, Map<String, dynamic> product) {
    final productName = product['product_name'] ?? 'Product';
    final productPrice =
        product['lowest_available_price'] ?? product['price_starts_from'] ?? 0;
    final productImage = product['img_url'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ), // Added border
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15), // Stronger, matte shadow
            blurRadius: 8,
            spreadRadius: 1, // Spread all around
            offset: Offset.zero, // Evenly distributed
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showProductDetails(product),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Image Area with Price Overlay
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: productImage != null
                          ? CustomCachedNetworkImage(
                              imgUrl: productImage,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          : Container(
                              color: Colors.grey[100],
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 28,
                                color: Colors.grey[400],
                              ),
                            ),
                    ),
                    // Price Tag Overlay
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32), // Green color
                          borderRadius: BorderRadius.circular(
                            8,
                          ), // Rounded shape
                        ),
                        child: TranslatedText(
                          '₹$productPrice',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Dashed Separator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boxWidth = constraints.constrainWidth();
                    const dashWidth = 3.0;
                    final dashCount = (boxWidth / (2 * dashWidth)).floor();
                    return Flex(
                      direction: Axis.horizontal,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(dashCount, (_) {
                        return SizedBox(
                          width: dashWidth,
                          height: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.grey[300]),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),

              // Product Details (Name + Button only)
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    SizedBox(
                      height: 32, // Fixed height for 2 lines
                      child: TranslatedText(
                        productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12, // Slightly larger font
                          color: Colors.black87,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Add Button
                    SizedBox(
                      width: double.infinity,
                      child: _buildProductAction(theme, product),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductAction(ThemeData theme, Map<String, dynamic> product) {
    final qty = _getProductQuantityInCart(product);

    // If not in cart, show Add button
    if (qty == 0) {
      return SizedBox(
        height: 32, // Taller button
        child: ElevatedButton(
          onPressed: () => _handleAddToCart(product),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 16),
              SizedBox(width: 4),
              TranslatedText(
                'Add',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    // If in cart, show counter
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.primaryColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                // Decrement with empty combination ID as requested
                _decrementCartItem('', product['id']);
              },
              child: Center(
                child: Icon(Icons.remove, size: 16, color: theme.primaryColor),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TranslatedText(
              '$qty',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              // (+) Button calls /product-variation-value/ i.e. _handleAddToCart
              onTap: () => _handleAddToCart(product),
              child: Center(
                child: Icon(Icons.add, size: 16, color: theme.primaryColor),
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

      // Call API to get product variations
      final response = await ApiService.post(
        '/product-variation-value/',
        body: {
          'order_by': 'variation_name',
          'query': {'store_id': widget.storeId, 'product_id': product['id']},
          'store_id': widget.storeId,
          'customer_user_id': customer_user_id ?? '',
          'store_access': true,
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
                content: TranslatedText(
                  data['response'] ?? 'Product added to cart',
                ),
                duration: const Duration(seconds: 1), // Short duration
                backgroundColor: Colors.green,
              ),
            );
            // REFRESH CART
            await _validateCart();
            // Refresh products
            _fetchProductsByCategory(
              _selectedCategoryId ?? 'all',
              isRefresh: true,
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
              content: TranslatedText('Failed to add product'),
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
          SnackBar(
            content: TranslatedText('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showProductDetails(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: TranslatedText(product['product_name'] ?? 'Product Details'),
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
            TranslatedText(
              'Price: ₹${product['lowest_available_price'] ?? product['price_starts_from'] ?? 0}',
            ),
            if (product['description'] != null &&
                product['description'] != 'undefined') ...[
              const SizedBox(height: 8),
              TranslatedText(product['description']),
            ],
            if (product['parent_category'] != null) ...[
              const SizedBox(height: 8),
              TranslatedText('Category: ${product['parent_category']}'),
            ],
            if (product['child_category'] != null) ...[
              const SizedBox(height: 4),
              TranslatedText('Sub-category: ${product['child_category']}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const TranslatedText('Close'),
          ),
        ],
      ),
    );
  }

  void _showOrderMethodSelection() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const TranslatedText('Select Order Method'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _orderMethods.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final method = _orderMethods[index];
                final isSelected = method['id'] == _selectedOrderMethod?['id'];

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedOrderMethod = method;
                    });
                    Navigator.pop(context);
                    // Re-validate cart with new method
                    _validateCart();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.05)
                          : null,
                    ),
                    child: Row(
                      children: [
                        if (method['img_url'] != null)
                          CustomCachedNetworkImage(
                            imgUrl: method['img_url'],
                            width: 32,
                            height: 32,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TranslatedText(
                                method['order_method_name'] ?? '',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : Colors.black87,
                                ),
                              ),
                              if (method['order_method_description'] != null)
                                TranslatedText(
                                  method['order_method_description'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const TranslatedText('Cancel'),
            ),
          ],
        );
      },
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
        customerUserId: customer_user_id,
        onCartUpdated: () {
          _validateCart();
          _fetchProductsByCategory(
            _selectedCategoryId ?? 'all',
            isRefresh: true,
          );
        }, // Call cart validation and product refresh after adding
      ),
    );
  }
}

// Stateful Bottom Sheet Widget for Variants
class _VariantsBottomSheetContent extends StatefulWidget {
  final Map<String, dynamic> product;
  final List variations;
  final String storeId;
  final String? customerUserId;
  final VoidCallback onCartUpdated;

  const _VariantsBottomSheetContent({
    required this.product,
    required this.variations,
    required this.storeId,
    required this.customerUserId,
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
      final response = await ApiService.post(
        '/validate-product-availability/',
        body: {
          'product_id': widget.product['id'],
          'store_id': widget.storeId,
          'store_access': true,
          'customer_user_id': widget.customerUserId ?? '',
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
                        TranslatedText(
                          widget.product['product_name'] ?? 'Select Options',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TranslatedText(
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
                            TranslatedText(
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
                                child: TranslatedText(
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
                            title: TranslatedText(
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
                          child: TranslatedText(
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
                          ? _addToCart
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
                          : TranslatedText(
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

  Future<void> _addToCart() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.post(
        '/add-product-in-cart/',
        body: {
          'quantity': _quantity,
          'product_id': widget.product['id'],
          'store_id': widget.storeId,
          'store_access': true,
          'customer_user_id': widget.customerUserId ?? '',
          'variations': _selectedVariationIds,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200) {
          if (mounted) {
            Navigator.pop(context);
            widget.onCartUpdated(); // Refresh cart
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: TranslatedText(
                  data['response'] ?? 'Product added to cart',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: TranslatedText(
                  data['response'] ?? 'Failed to add product',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatedText('Failed to add product to cart'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Error adding to cart: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
        title: const TranslatedText('Scan QR Code'),
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
        title: const TranslatedText('Scan QR Code'),
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
