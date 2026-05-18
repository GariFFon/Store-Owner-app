import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:exanor/components/translation_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/components/custom_cached_network_image.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:country_code_picker/country_code_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:exanor/services/invoice_print_service.dart';
import 'package:exanor/components/pos_print_options_dialog.dart';
import 'package:exanor/screens/order_details_screen.dart';
import 'package:exanor/utils/event_bus.dart';
import 'package:exanor/utils/keyboard_shortcuts.dart';
import 'package:exanor/utils/platform_helper.dart';
import 'package:exanor/utils/fuzzy_search.dart';

class StoreOwnerPOSScreen extends StatefulWidget {
  final String storeId;
  final String storeName;
  final VoidCallback? onMenuPressed;
  final DesktopActionController? desktopActionController;

  const StoreOwnerPOSScreen({
    super.key,
    required this.storeId,
    required this.storeName,
    this.onMenuPressed,
    this.desktopActionController,
  });

  @override
  State<StoreOwnerPOSScreen> createState() => _StoreOwnerPOSScreenState();
}

class _StoreOwnerPOSScreenState extends State<StoreOwnerPOSScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Public: Expand and focus the search bar (called via Ctrl+S / Ctrl+F)
  void focusSearch() {
    if (mounted) {
      if (PlatformHelper.isDesktop) {
        setState(() {
          _isDesktopSearchOverlayVisible = true;
        });
        Future.delayed(const Duration(milliseconds: 50), () {
          _desktopSearchFocusNode.requestFocus();
        });
      } else {
        setState(() {
          _isSearchExpanded = true;
        });
      }
    }
  }

  /// Public: Refresh products in the current category (called via Ctrl+R / F5)
  void refreshProducts() {
    _fetchCategories();
    _validateCart();
    _fetchOrderMethods();
  }

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

  // Local product cache for fuzzy search (all products loaded across categories)
  final List<Map<String, dynamic>> _allProductsCache = [];

  // Desktop Search Overlay
  bool _isDesktopSearchOverlayVisible = false;
  final FocusNode _desktopSearchFocusNode = FocusNode();

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

  // Cart shimmer animation
  late AnimationController _cartShimmerController;
  late Animation<double> _cartShimmerAnimation;

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

  // Table Selection
  Map<String, dynamic>? _selectedTable;

  String? _ownerName;
  String? _ownerUserId;
  String? _storeName;
  bool _isTextOnlyMode = false;
  String _posCategoryLayout = 'left'; // 'left' or 'top'
  double _posCategorySize = 85.0;
  double _posProductCardSize = 220.0;
  double _checkoutPanelWidth = 340.0;
  String _posCustomerWorkflow =
      'ask_first'; // 'ask_first', 'ask_at_checkout', 'skip'
  String? _guestSessionId;

  // Checkout Options Layout
  String _posOptionsLayout = 'dropdown'; // 'dropdown' or 'inline'

  @override
  void initState() {
    super.initState();
    widget.desktopActionController?.focusSearch = focusSearch;
    widget.desktopActionController?.refreshProducts = refreshProducts;
    _fetchOwnerName();
    _initializeSpeech();
    _setupScrollListener();
    _fetchCategories();
    _fetchPaymentMethods();
    _fetchStoreBankDetails();
    _loadViewPreference(); // Load view preference (handles workflow inside)
    _initLocationAndCart(); // Load location then cart data

    // Cart shimmer animation
    _cartShimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _cartShimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _cartShimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _cartShimmerController.dispose();
    _searchController.dispose();
    _desktopSearchFocusNode.dispose();
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
      final userId = prefs.getString('user_id') ?? '';

      if (mounted) {
        setState(() {
          _ownerName = '$firstName $lastName'.trim();
          if (_ownerName!.isEmpty) {
            _ownerName = 'Store Owner';
          }
          _ownerUserId = userId;
          _storeName = prefs.getString('selected_store_name') ?? 'My Store';
        });
      }
    } catch (e) {
      debugPrint('Error fetching owner name: $e');
    }
  }

  // ── Table Selection ──────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> _fetchTablesForSelection() async {
    try {
      final res = await ApiService.post(
        '/store-table-operations/',
        body: {
          'store_id': widget.storeId,
          'store_access': true,
          'query': {'is_active': true},
          'create': false,
        },
        useBearerToken: true,
      );
      final data = res['data'] as Map<String, dynamic>?;
      if (data?['status'] == 200) {
        final raw = data?['response'];
        if (raw is List) {
          return raw.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error fetching tables: $e');
    }
    return [];
  }

  Future<void> _showTableSelectionDialog(StateSetter setSheetState) async {
    // Show loading while fetching
    List<Map<String, dynamic>> tables = [];
    bool loadingTables = true;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          if (loadingTables) {
            _fetchTablesForSelection().then((result) {
              if (ctx.mounted) {
                setDlg(() {
                  tables = result;
                  loadingTables = false;
                });
              }
            });
          }
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 40,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Dining Table',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Content
                  loadingTables
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : tables.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No active tables found',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.1,
                              ),
                          itemCount: tables.length,
                          itemBuilder: (_, i) {
                            final t = tables[i];
                            final tableNum =
                                t['table_number']?.toString() ?? '—';
                            final additional =
                                t['additional_data'] as Map? ?? {};
                            final seats = additional['seats'] ?? 0;
                            final isSelected = _selectedTable?['id'] == t['id'];
                            return GestureDetector(
                              onTap: () {
                                setDlg(() {});
                                setSheetState(() {
                                  _selectedTable = isSelected ? null : t;
                                });
                                Navigator.pop(ctx);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(
                                          0xFF5B4FE8,
                                        ).withOpacity(0.08)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF5B4FE8)
                                        : const Color(0xFFE2E8F0),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      tableNum,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected
                                            ? const Color(0xFF5B4FE8)
                                            : const Color(0xFF1E293B),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$seats Seat${seats == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected
                                            ? const Color(0xFF5B4FE8)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build order_additional_data payload
  List<Map<String, String>> _buildOrderAdditionalData() {
    final List<Map<String, String>> data = [];
    if (_selectedTable != null) {
      data.add({
        'title': 'Table Number',
        'value': _selectedTable!['table_number']?.toString() ?? '',
      });
    }
    data.add({
      'title': 'Billed By',
      'value': '${_ownerName ?? 'Store Owner'} (ID: ${_ownerUserId ?? ''})',
    });
    return data;
  }

  Future<void> _loadViewPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        final val = prefs.getBool('pos_text_only_mode') ?? false;
        final layout = prefs.getString('pos_category_layout') ?? 'left';
        final catSize = prefs.getDouble('pos_category_size') ?? 85.0;
        final cardSize = prefs.getDouble('pos_product_card_size') ?? 220.0;
        final workflow =
            prefs.getString('pos_customer_workflow') ?? 'ask_first';
        final optionsLayout =
            prefs.getString('pos_options_layout') ?? 'dropdown';
        final guestSessionId = prefs.getString('pos_guest_session_id');

        if (layout == 'top') {
          _posCategorySize = 0.0;
        }

        print(
          "Loading persistent view mode: $val, layout: $layout, workflow: $workflow, options: $optionsLayout, guest: $guestSessionId",
        );
        setState(() {
          _isTextOnlyMode = val;
          _posCategoryLayout = layout;
          _posCategorySize = catSize;
          _posProductCardSize = cardSize;
          _posCustomerWorkflow = workflow;
          _posOptionsLayout = optionsLayout;
          _guestSessionId = guestSessionId;
        });

        // Handle customer workflow after preference is loaded
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_posCustomerWorkflow == 'ask_first') {
            _showCustomerPhoneDialog();
          } else if (_posCustomerWorkflow == 'skip') {
            // Auto-assign guest customer silently
            const String guestPhoneNumber = '910000000018';
            _fetchCustomerData(guestPhoneNumber, silent: true).catchError((e) {
              debugPrint('Guest customer fetch error (non-blocking): $e');
              return false;
            });
          }
          // ask_at_checkout: browse as true guest, no dialog until checkout
        });
      }
    } catch (e) {
      print('Error loading view preference: $e');
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

  /// After data loads, check if content fills the viewport.
  /// If not and there's more data, auto-load the next page.
  void _loadProductsUntilScrollable() {
    if (!mounted || !_hasMoreProducts || _isLoadingMore || _isProductsLoading)
      return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0 &&
          _hasMoreProducts &&
          !_isLoadingMore) {
        _loadMoreProducts();
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
          } else {
            // No address on file — create a store-generated placeholder then re-fetch
            final created = await _createStoreDefaultAddress();
            if (created) {
              await _fetchUserAddresses();
            }
          }
        }
      }
    } catch (e) {
      print("Error fetching user addresses: $e");
    }
  }

  /// Creates a lightweight placeholder address on behalf of the store so that
  /// [order-init/] always receives a valid [user_address_id].
  /// Uses the device's current GPS coordinates (already captured in [_lat]/[_lng]).
  Future<bool> _createStoreDefaultAddress() async {
    try {
      if (customer_user_id == null || customer_user_id!.isEmpty) return false;

      final response = await ApiService.post(
        '/add-user-address/',
        body: {
          "address_line_1": "",
          "address_line_2": "",
          "locality": "",
          "city": "",
          "state": "",
          "district": "",
          "pincode": 0,
          "country": "India",
          "address_name": "Created by Store: ${widget.storeId}",
          "area": "",
          "lat": _lat,
          "lng": _lng,
          "is_billing": true,
          "is_shipping": true,
          "phone_number": 0,
          "attendee_name": "",
          "store_access": true,
          "customer_user_id": customer_user_id,
          "store_id": widget.storeId,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200) {
          debugPrint(
            '✅ Default store address created for customer $customer_user_id',
          );
          return true;
        }
      }
      debugPrint(
        '⚠️ add-user-address/ returned unexpected: ${response['data']}',
      );
      return false;
    } catch (e) {
      debugPrint('❌ Error creating default address: $e');
      return false;
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
            _categories.insert(0, {'id': 'all', 'category_name': 'All'});

            _isCategoriesLoading = false;

            // Auto-select first category (which is now "All")
            if (_categories.isNotEmpty) {
              String? categoryToSelect = _selectedCategoryId;
              if (categoryToSelect == null ||
                  !_categories.any((c) => c['id'] == categoryToSelect)) {
                categoryToSelect = _categories[0]['id'];
              }
              _selectedCategoryId = categoryToSelect;
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
          'page_size':
              500, // Load all products at once for instant POS experience
          'store_access': true,
          'customer_user_id': customer_user_id ?? '',
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          final newProducts = List<Map<String, dynamic>>.from(data['response']);

          // Use pagination info from API response if available
          final pagination = data['pagination'];
          final hasNextFromApi = pagination?['has_next'] ?? false;

          print(
            '📦 Loaded ${newProducts.length} products, page: ${pagination?['current_page']}, has_next: $hasNextFromApi, total_pages: ${pagination?['total_pages']}',
          );

          setState(() {
            _products = newProducts;
            _isProductsLoading = false;
            // Use API's has_next field for accurate pagination
            _hasMoreProducts = hasNextFromApi;
          });
          _loadProductsUntilScrollable();

          // Cache products for fuzzy local search
          _cacheProducts(newProducts);
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
    print(
      '🔄 _loadMoreProducts called - isLoadingMore: $_isLoadingMore, hasMore: $_hasMoreProducts, page: $_currentPage',
    );

    if (_isLoadingMore || !_hasMoreProducts) {
      print(
        '⏭️ Skipping load: isLoadingMore=$_isLoadingMore, hasMoreProducts=$_hasMoreProducts',
      );
      return;
    }

    final isSearching = _searchController.text.isNotEmpty;
    if (!isSearching && _selectedCategoryId == null) {
      print('⏭️ Skipping load: no category selected and not searching');
      return;
    }

    try {
      setState(() {
        _isLoadingMore = true;
      });

      _currentPage++; // Increment page
      print('📄 Loading page $_currentPage...');

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
            'page_size':
                500, // Load all products at once for instant POS experience
            'store_access': true,
            'customer_user_id': customer_user_id ?? '',
          },
          useBearerToken: true,
        );
      }

      print('📥 API Response status: ${response['statusCode']}');

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          final newProducts = List<Map<String, dynamic>>.from(data['response']);

          // Cache for fuzzy search
          _cacheProducts(newProducts);

          // Use pagination info from API response
          final pagination = data['pagination'];
          final hasNextFromApi = pagination?['has_next'] ?? false;

          print(
            '✅ Loaded ${newProducts.length} new products. Total now: ${_products.length + newProducts.length}. Page: ${pagination?['current_page']}, has_next: $hasNextFromApi',
          );
          setState(() {
            _products.addAll(newProducts); // Append new products
            _isLoadingMore = false;

            if (isSearching) {
              _hasMoreProducts = data['has_next'] ?? false;
            } else {
              // Use API's has_next field for accurate pagination
              _hasMoreProducts = hasNextFromApi;
            }
            print('📊 hasMoreProducts now: $_hasMoreProducts');
          });
          _loadProductsUntilScrollable();
        } else {
          print('❌ No data in response or status != 200');
          setState(() {
            _isLoadingMore = false;
            _hasMoreProducts = false; // No more products
          });
        }
      } else {
        print('❌ API status code != 200');
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
      print('❌ Error loading more products: $e');
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
      final body = {
        'store_id': widget.storeId,
        'order_method_id':
            _selectedOrderMethod?['id'] ?? null, // Default order method
        'user_address_id': selected_address_id ?? null, // Default address
        'lat': _lat,
        'lng': _lng,
        'store_access': true,
        'customer_user_id': customer_user_id ?? '',
      };
      if (_guestSessionId != null && _guestSessionId!.isNotEmpty) {
        body['guest_session_id'] = _guestSessionId!;
      }
      final response = await ApiService.post(
        '/auto-validate-cart/',
        body: body,
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

        // Build product_id -> total quantity map from product_in_cart
        // product_in_cart has the correct product_id that matches product grid IDs
        final Map<String, int> productQuantities = {};
        final productInCart = data['product_in_cart'] ?? [];
        for (var item in productInCart) {
          final pid = item['product_id']?.toString() ?? '';
          if (pid.isEmpty) continue;
          final qty = (item['quantity'] as num?)?.toInt() ?? 1;
          productQuantities[pid] = (productQuantities[pid] ?? 0) + qty;
        }

        // Update product card quantities to match actual cart state
        for (int i = 0; i < _products.length; i++) {
          final productId = _products[i]['id']?.toString() ?? '';
          final actualQty = productQuantities[productId] ?? 0;
          if (_products[i]['quantity'] != actualQty) {
            _products[i] = Map<String, dynamic>.from(_products[i]);
            _products[i]['quantity'] = actualQty;
          }
        }
      });
    }
  }

  Future<void> _incrementCartItem(
    String productCombinationId,
    String productId,
  ) async {
    // Optimistic UI update - increment quantity locally first
    _updateLocalProductQuantity(productId, 1);

    try {
      final body = {
        "store_id": widget.storeId,
        "product_id": productId,
        "customer_user_id": customer_user_id ?? '',
        "product_combination_id": productCombinationId,
        "store_access": true,
      };
      if ((customer_user_id == null || customer_user_id!.isEmpty) &&
          _guestSessionId != null &&
          _guestSessionId!.isNotEmpty) {
        body["guest_session_id"] = _guestSessionId!;
      }
      final response = await ApiService.post(
        '/increment-product-in-cart/',
        body: body,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        // Update cart state without refetching products
        await _validateCart();
      } else {
        // Revert optimistic update on failure
        _updateLocalProductQuantity(productId, -1);
      }
    } catch (e) {
      // Revert optimistic update on error
      _updateLocalProductQuantity(productId, -1);
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
    // Optimistic UI update - decrement quantity locally first
    _updateLocalProductQuantity(productId, -1);

    try {
      final body = {
        "store_id": widget.storeId,
        "product_id": productId,
        "customer_user_id": customer_user_id ?? '',
        "product_combination_id": productCombinationId,
        "store_access": true,
      };
      if ((customer_user_id == null || customer_user_id!.isEmpty) &&
          _guestSessionId != null &&
          _guestSessionId!.isNotEmpty) {
        body["guest_session_id"] = _guestSessionId!;
      }
      final response = await ApiService.post(
        '/decrement-product-in-cart/',
        body: body,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        // Update cart state without refetching products
        await _validateCart();
      } else {
        // Revert optimistic update on failure
        _updateLocalProductQuantity(productId, 1);
        // Still refresh cart to keep totals in sync
        await _validateCart();
      }
    } catch (e) {
      // Revert optimistic update on error
      _updateLocalProductQuantity(productId, 1);
      // Still refresh cart to keep totals in sync
      await _validateCart();
      print('Error decrementing item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TranslatedText('Error updating cart: $e')),
      );
    }
  }

  /// Update local product quantity without refetching from API
  void _updateLocalProductQuantity(String productId, int delta) {
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < _products.length; i++) {
        if (_products[i]['id']?.toString() == productId) {
          final currentQty = (_products[i]['quantity'] as num?)?.toInt() ?? 0;
          final newQty = (currentQty + delta).clamp(0, 9999);
          _products[i] = Map<String, dynamic>.from(_products[i]);
          _products[i]['quantity'] = newQty;
          break;
        }
      }
    });
  }

  /// Get total quantity of a product in cart (sum of all variations)
  int _getProductQuantityInCart(Map<String, dynamic> product) {
    // First, check if the product object itself has a quantity (from /product API)
    if (product.containsKey('quantity') && product['quantity'] != null) {
      final q = (product['quantity'] as num).toInt();
      if (q >= 0) return q;
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

  void _showPaymentModeSelector(StateSetter setSheetState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Payment Mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 12),
                // Unpaid
                _buildPaymentOptionTile(
                  'UNPAID',
                  'Unpaid',
                  Icons.money_off_csred_outlined,
                  setSheetState,
                ),
                // Multi-mode
                _buildPaymentOptionTile(
                  'MULTI-MODE',
                  'Split Payment',
                  Icons.account_tree_outlined,
                  setSheetState,
                ),
                // Bank options
                ..._bankDetails.map(
                  (bank) => _buildPaymentOptionTile(
                    bank['id'].toString(),
                    bank['bank_name'] ?? bank['account_holder_name'] ?? 'Bank',
                    Icons.account_balance_outlined,
                    setSheetState,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentOptionTile(
    String value,
    String label,
    IconData icon,
    StateSetter setSheetState,
  ) {
    final isSelected = _selectedPaymentMode == value;
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        if (value == 'MULTI-MODE') {
          setSheetState(() => _selectedPaymentMode = value);
          _showMultiModeDialog(setSheetState);
        } else {
          setSheetState(() => _selectedPaymentMode = value);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0EDFF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF5B4FE8)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? const Color(0xFF5B4FE8)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? const Color(0xFF5B4FE8)
                      : const Color(0xFF1A1A2E),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF5B4FE8),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyProductDiscount(
    String productInCartId,
    double discountPercent, {
    VoidCallback? onDone,
  }) async {
    try {
      final response = await ApiService.post(
        '/apply-product-discount/',
        body: {
          'store_access': true,
          'store_id': widget.storeId,
          'product_in_cart_id': productInCartId,
          'discount_percent': discountPercent,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: TranslatedText(
                  discountPercent == 0
                      ? 'Discount cleared'
                      : 'Discount applied: ${discountPercent.toStringAsFixed(0)}%',
                ),
                backgroundColor: discountPercent == 0
                    ? Colors.grey[700]
                    : const Color(0xFF5B4FE8),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          await _validateCart();
          onDone?.call();
          return;
        }
      }

      // Error handling
      final errorData = response['data'];
      final errorMsg =
          errorData?['response'] ??
          errorData?['message'] ??
          'Failed to apply discount';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText(errorMsg),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Error applying discount: $e'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  void _showDiscountDialog(
    String productInCartId,
    double maxDiscountPercent,
    double currentDiscount,
    VoidCallback? onApplied,
  ) {
    if (maxDiscountPercent <= 0) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const TranslatedText('Discount Blocked'),
          content: const TranslatedText(
            'Discounts are not enabled for this product. Ask the admin to set max_discount_percent > 0 on the product combination.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const TranslatedText('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final controller = TextEditingController(
      text: currentDiscount > 0 ? currentDiscount.toStringAsFixed(0) : '',
    );
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5B4FE8).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.local_offer_outlined,
                              color: Color(0xFF5B4FE8),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Apply Discount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Input
                      TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Discount %',
                          hintText:
                              '0 – ${maxDiscountPercent.toStringAsFixed(0)}',
                          suffixText: '%',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF5B4FE8),
                              width: 1.5,
                            ),
                          ),
                          errorText: errorText,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val) ?? -1;
                          if (parsed < 0 || parsed > maxDiscountPercent) {
                            setDlgState(() {
                              errorText =
                                  'Max allowed: ${maxDiscountPercent.toStringAsFixed(0)}%';
                            });
                          } else {
                            setDlgState(() => errorText = null);
                          }
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Maximum discount allowed: ${maxDiscountPercent.toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 16),
                      // Actions
                      Row(
                        children: [
                          if (currentDiscount > 0)
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _applyProductDiscount(
                                  productInCartId,
                                  0,
                                  onDone: onApplied,
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red[600],
                              ),
                              child: const TranslatedText('Clear'),
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const TranslatedText('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: errorText != null
                                ? null
                                : () {
                                    final val =
                                        double.tryParse(controller.text) ?? 0;
                                    if (val < 0 || val > maxDiscountPercent) {
                                      setDlgState(() {
                                        errorText =
                                            'Max allowed: ${maxDiscountPercent.toStringAsFixed(0)}%';
                                      });
                                      return;
                                    }
                                    Navigator.pop(ctx);
                                    _applyProductDiscount(
                                      productInCartId,
                                      val,
                                      onDone: onApplied,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF5B4FE8),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const TranslatedText('Apply'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _reviewOrder() async {
    // Check location permission before reviewing order
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText(
              'Please enable location services to review order',
            ),
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatedText(
                'Location permission is required to review order',
              ),
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText(
              'Location permission permanently denied. Please open settings.',
            ),
          ),
        );
        await Geolocator.openAppSettings();
        return;
      }

      if (_lat == 0.0 && _lng == 0.0) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        if (mounted) Navigator.pop(context);

        setState(() {
          _lat = position.latitude;
          _lng = position.longitude;
        });
      }
    } catch (e) {
      print('Location error before review order: $e');
      if (mounted && _lat == 0.0 && _lng == 0.0) {
        // Pop loading if it was showing and threw error
        // Note: we might need to handle popping safely if it was stuck
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TranslatedText('Could not verify location: $e')),
        );
      }
    }

    if (_cartItemsAvailable.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: TranslatedText('Cart is empty')));
      return;
    }

    if (_posCustomerWorkflow == 'ask_at_checkout') {
      await _showCustomerPhoneDialog();
      // If user still didn't set a customer, bail out
      if (customer_user_id == null || customer_user_id!.isEmpty) {
        return;
      }
    } else if (customer_user_id == null || customer_user_id!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: TranslatedText('Please select a customer')),
      );
      return;
    }

    // Validate payment method is selected
    if (_selectedPaymentMethodId == null || _selectedPaymentMethodId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText('Please select a payment method'),
        ),
      );
      return;
    }

    // Place order directly — skip order-init / review step
    await _confirmPlaceOrder();
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

  Future<void> _confirmPlaceOrder({bool fromReview = false}) async {
    // Validate required fields before placing order
    final orderMethodId = _selectedOrderMethod?['id']?.toString();

    if (_posCustomerWorkflow == 'ask_at_checkout' &&
        (customer_user_id == null || customer_user_id!.isEmpty)) {
      await _showCustomerPhoneDialog();
      if (customer_user_id == null || customer_user_id!.isEmpty) {
        return;
      }
    }

    if (_selectedPaymentMethodId == null ||
        _selectedPaymentMethodId!.isEmpty ||
        customer_user_id == null ||
        customer_user_id!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText(
              'Missing required order details. Please go back and verify.',
            ),
          ),
        );
      }
      return;
    }

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
            "order_method_id": orderMethodId,
            "payment_method_id": _selectedPaymentMethodId,
            "store_access": true,
            "store_id": widget.storeId,
            "user_address_id": selected_address_id,
            "coupon_code": "",
            "order_additional_data": _buildOrderAdditionalData(),
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
            "order_method_id": orderMethodId,
            "payment_method_id": _selectedPaymentMethodId,
            "store_access": true,
            "store_id": widget.storeId,
            "user_address_id": selected_address_id,
            "payment_methods": paymentMethodsList,
            "coupon_code": "",
            "order_additional_data": _buildOrderAdditionalData(),
          },
          useBearerToken: true,
        );
      }

      // Hide loading
      if (mounted) Navigator.pop(context);

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200) {
          // Close the Summary Popup only if we came from review
          if (fromReview && mounted) Navigator.pop(context);

          // Instantly clear cart state so UI reflects empty cart immediately
          if (mounted) {
            setState(() {
              _cartItemsAvailable = [];
              _cartItemsUnavailable = [];
              _totalProductsInCart = 0;
              _grandTotal = 0.0;
              _cartData = null;
              _multiModeValues = {};
              _selectedPaymentMode = 'UNPAID';
              _selectedTable = null;
              // Reset all product quantities to 0
              for (int i = 0; i < _products.length; i++) {
                if ((_products[i]['quantity'] as num?)?.toInt() != 0) {
                  _products[i] = Map<String, dynamic>.from(_products[i]);
                  _products[i]['quantity'] = 0;
                }
              }
            });
          }

          // If cart was migrated from guest, clear old guest session and generate new one
          if (_guestSessionId != null && _guestSessionId!.isNotEmpty) {
            _guestSessionId = const Uuid().v4();
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString('pos_guest_session_id', _guestSessionId!);
            });
          }

          String? createdOrderId;
          if (data['response'] is Map) {
            createdOrderId =
                data['response']['id']?.toString() ??
                data['response']['order_id']?.toString() ??
                data['response']['execute_order_data']?['order_id']?.toString();
          }

          if (mounted && createdOrderId != null) {
            EventBus().fire(OrderPlacedEvent());
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => PosPrintOptionsDialog(
                orderId: createdOrderId!,
                title: 'Order Placed Successfully!',
                onViewOrder: () {
                  Navigator.pop(ctx);
                  _initLocationAndCart();
                  _fetchProductsByCategory(
                    _selectedCategoryId ?? 'all',
                    isRefresh: true,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderDetailsScreen(
                        orderId: createdOrderId!,
                        storeId: widget.storeId,
                      ),
                    ),
                  );
                },
                onNewOrder: () {
                  Navigator.pop(ctx);
                  // Reset customer state for a fresh session
                  setState(() {
                    customer_user_id = null;
                    _currentCustomer = null;
                    selected_address_id = null;
                  });
                  _initLocationAndCart();
                  _fetchProductsByCategory(
                    _selectedCategoryId ?? 'all',
                    isRefresh: true,
                  );
                  // Respect workflow for the next order
                  if (_posCustomerWorkflow == 'ask_first') {
                    _showCustomerPhoneDialog();
                  } else if (_posCustomerWorkflow == 'skip') {
                    const String guestPhoneNumber = '910000000018';
                    _fetchCustomerData(
                      guestPhoneNumber,
                      silent: true,
                    ).catchError((e) {
                      debugPrint(
                        'Guest customer fetch error (non-blocking): $e',
                      );
                      return false;
                    });
                  }
                  // ask_at_checkout: browse as guest, no dialog until next checkout
                },
              ),
            );
          } else if (mounted) {
            EventBus().fire(OrderPlacedEvent());
            // Fallback refresh if createdOrderId is null
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

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xFF3B82F6),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: Colors.white.withOpacity(0.3),
        highlightColor: Colors.white.withOpacity(0.15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }

  void _showCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (context) {
        bool showDetails = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 20,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey[100]!,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const TranslatedText(
                                  'Shopping Cart',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
                                  ),
                                  child: TranslatedText(
                                    '$_totalProductsInCart Items',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey[200]!),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.black87,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Cart Items
                      Expanded(
                        child: _cartItemsAvailable.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shopping_cart_outlined,
                                      size: 64,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 16),
                                    const TranslatedText(
                                      'Your cart is empty',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.all(20),
                                itemCount: _cartItemsAvailable.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final item = _cartItemsAvailable[index];
                                  final pricing = item['pricing_details'] ?? {};
                                  final quantity =
                                      item['enquired_quantity'] ??
                                      item['quantity'] ??
                                      0;
                                  final productImg =
                                      item['product_image'] ??
                                      item['image'] ??
                                      item['img_url'];

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Product Image
                                        Container(
                                          width: 72,
                                          height: 72,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: productImg != null
                                              ? ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  child:
                                                      CustomCachedNetworkImage(
                                                        imgUrl: productImg,
                                                        fit: BoxFit.cover,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons
                                                      .image_not_supported_outlined,
                                                  color: Colors.grey,
                                                ),
                                        ),
                                        const SizedBox(width: 16),

                                        // Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              TranslatedText(
                                                item['product_name'] ?? '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              // Discount badge
                                              if ((pricing['discount_percent'] ??
                                                      0) >
                                                  0) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFF5B4FE8,
                                                        ).withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        '${pricing['discount_percent'].toStringAsFixed(0)}% OFF',
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFF5B4FE8,
                                                          ),
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '₹${(pricing['original_sale_price_excl_tax']?.toDouble() ?? pricing['selling_amount_excluding_tax']?.toDouble() ?? 0).toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        color: Colors.grey[400],
                                                        fontSize: 11,
                                                        decoration:
                                                            TextDecoration
                                                                .lineThrough,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                              const SizedBox(height: 6),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  TranslatedText(
                                                    '₹${pricing['item_total']?.toStringAsFixed(2) ?? '0.00'}',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15,
                                                      color: theme.primaryColor,
                                                    ),
                                                  ),
                                                  // Discount + Quantity
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      // Discount button
                                                      InkWell(
                                                        onTap: () {
                                                          _showDiscountDialog(
                                                            item['product_in_cart_id']
                                                                    ?.toString() ??
                                                                '',
                                                            (pricing['max_discount_percent']
                                                                        ?.toDouble() ??
                                                                    0)
                                                                .toDouble(),
                                                            (pricing['discount_percent']
                                                                        ?.toDouble() ??
                                                                    0)
                                                                .toDouble(),
                                                            () => setSheetState(
                                                              () {},
                                                            ),
                                                          );
                                                        },
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16,
                                                            ),
                                                        child: Container(
                                                          width: 32,
                                                          height: 32,
                                                          decoration: BoxDecoration(
                                                            color:
                                                                (pricing['discount_percent'] ??
                                                                        0) >
                                                                    0
                                                                ? const Color(
                                                                    0xFF5B4FE8,
                                                                  ).withOpacity(
                                                                    0.1,
                                                                  )
                                                                : Colors
                                                                      .grey[100],
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  16,
                                                                ),
                                                          ),
                                                          child: Icon(
                                                            Icons
                                                                .local_offer_outlined,
                                                            size: 16,
                                                            color:
                                                                (pricing['discount_percent'] ??
                                                                        0) >
                                                                    0
                                                                ? const Color(
                                                                    0xFF5B4FE8,
                                                                  )
                                                                : Colors
                                                                      .grey[500],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      // Quantity Button
                                                      Container(
                                                        height: 32,
                                                        decoration: BoxDecoration(
                                                          color:
                                                              Colors.grey[50],
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20,
                                                              ),
                                                          border: Border.all(
                                                            color: Colors
                                                                .grey[200]!,
                                                          ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            _buildQtyBtn(
                                                              Icons.remove,
                                                              () async {
                                                                await _decrementCartItem(
                                                                  item['product_combination_id'] ??
                                                                      '',
                                                                  item['product_id'] ??
                                                                      '',
                                                                );
                                                                setSheetState(
                                                                  () {},
                                                                );
                                                              },
                                                            ),
                                                            Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        10,
                                                                  ),
                                                              child: Text(
                                                                '$quantity',
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            ),
                                                            _buildQtyBtn(
                                                              Icons.add,
                                                              () async {
                                                                await _incrementCartItem(
                                                                  item['product_combination_id'] ??
                                                                      '',
                                                                  item['product_id'] ??
                                                                      '',
                                                                );
                                                                setSheetState(
                                                                  () {},
                                                                );
                                                              },
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),

                      // Bottom Section: Payment Breakdown & Checkout
                      if (_cartItemsAvailable.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 16,
                                offset: const Offset(0, -4),
                              ),
                            ],
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Options Layout: Dropdown vs Inline
                              if (_posOptionsLayout == 'dropdown')
                                // Unified clean options card
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Order Type Row
                                      InkWell(
                                        onTap: () async {
                                          await _showOrderMethodSelection();
                                          setSheetState(() {});
                                        },
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(12),
                                            ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.room_service_outlined,
                                                  size: 16,
                                                  color: Colors.orange.shade700,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Order Type',
                                                      style: TextStyle(
                                                        color: Colors.black45,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    TranslatedText(
                                                      _selectedOrderMethod?['order_method_name'] ??
                                                          'Select Type',
                                                      style: TextStyle(
                                                        color: Colors
                                                            .orange
                                                            .shade800,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                Icons.keyboard_arrow_right,
                                                size: 18,
                                                color: Colors.grey[400],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const Divider(
                                        height: 1,
                                        indent: 56,
                                        endIndent: 14,
                                      ),
                                      // Table Row
                                      InkWell(
                                        onTap: () => _showTableSelectionDialog(
                                          setSheetState,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: _selectedTable != null
                                                      ? const Color(
                                                          0xFF5B4FE8,
                                                        ).withOpacity(0.08)
                                                      : const Color(0xFFF1F5F9),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons
                                                      .table_restaurant_outlined,
                                                  size: 16,
                                                  color: _selectedTable != null
                                                      ? const Color(0xFF5B4FE8)
                                                      : Colors.grey[400],
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: _selectedTable != null
                                                    ? Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            'Table',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .black45,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                          Text(
                                                            _selectedTable!['table_number']
                                                                    ?.toString() ??
                                                                '',
                                                            style:
                                                                const TextStyle(
                                                                  color: Color(
                                                                    0xFF5B4FE8,
                                                                  ),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 13,
                                                                ),
                                                          ),
                                                        ],
                                                      )
                                                    : Text(
                                                        'Select Table',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[500],
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                              ),
                                              if (_selectedTable != null)
                                                GestureDetector(
                                                  onTap: () => setSheetState(
                                                    () => _selectedTable = null,
                                                  ),
                                                  child: Icon(
                                                    Icons.close_rounded,
                                                    size: 16,
                                                    color: Colors.grey[400],
                                                  ),
                                                )
                                              else
                                                Icon(
                                                  Icons.keyboard_arrow_right,
                                                  size: 18,
                                                  color: Colors.grey[400],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const Divider(
                                        height: 1,
                                        indent: 56,
                                        endIndent: 14,
                                      ),
                                      // Payment Row
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.payments_outlined,
                                                size: 16,
                                                color: theme.primaryColor,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: _selectedPaymentMode,
                                                  isExpanded: true,
                                                  icon: Icon(
                                                    Icons.expand_more_rounded,
                                                    color: theme.primaryColor,
                                                    size: 18,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF1A1A2E),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  items: [
                                                    const DropdownMenuItem(
                                                      value: 'UNPAID',
                                                      child: TranslatedText(
                                                        'Unpaid',
                                                      ),
                                                    ),
                                                    const DropdownMenuItem(
                                                      value: 'MULTI-MODE',
                                                      child: TranslatedText(
                                                        'Split',
                                                      ),
                                                    ),
                                                    ..._bankDetails.map((bank) {
                                                      final label =
                                                          bank['bank_name'] ??
                                                          bank['account_holder_name'] ??
                                                          'Bank';
                                                      return DropdownMenuItem(
                                                        value: bank['id']
                                                            .toString(),
                                                        child: Text(
                                                          label,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 13,
                                                              ),
                                                        ),
                                                      );
                                                    }),
                                                  ],
                                                  onChanged: (value) {
                                                    if (value != null) {
                                                      if (value ==
                                                          'MULTI-MODE') {
                                                        setSheetState(() {
                                                          _selectedPaymentMode =
                                                              value;
                                                        });
                                                        _showMultiModeDialog(
                                                          setSheetState,
                                                        );
                                                      } else {
                                                        setSheetState(() {
                                                          _selectedPaymentMode =
                                                              value;
                                                        });
                                                      }
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                // Inline layout: compact chips in a row
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          await _showOrderMethodSelection();
                                          setSheetState(() {});
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: Colors.orange.shade200,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.room_service_outlined,
                                                size: 16,
                                                color: Colors.orange.shade700,
                                              ),
                                              const SizedBox(height: 4),
                                              TranslatedText(
                                                _selectedOrderMethod?['order_method_name'] ??
                                                    'Type',
                                                style: TextStyle(
                                                  color: Colors.orange.shade800,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _showTableSelectionDialog(
                                          setSheetState,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _selectedTable != null
                                                ? const Color(
                                                    0xFF5B4FE8,
                                                  ).withOpacity(0.08)
                                                : const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: _selectedTable != null
                                                  ? const Color(
                                                      0xFF5B4FE8,
                                                    ).withOpacity(0.3)
                                                  : const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.table_restaurant_outlined,
                                                size: 16,
                                                color: _selectedTable != null
                                                    ? const Color(0xFF5B4FE8)
                                                    : Colors.grey[500],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _selectedTable != null
                                                    ? _selectedTable!['table_number']
                                                              ?.toString() ??
                                                          'Table'
                                                    : 'Table',
                                                style: TextStyle(
                                                  color: _selectedTable != null
                                                      ? const Color(0xFF5B4FE8)
                                                      : Colors.grey[600],
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () {
                                          _showPaymentModeSelector(
                                            setSheetState,
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.payments_outlined,
                                                size: 16,
                                                color: theme.primaryColor,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _selectedPaymentMode == 'UNPAID'
                                                    ? 'Unpaid'
                                                    : _selectedPaymentMode ==
                                                          'MULTI-MODE'
                                                    ? 'Split'
                                                    : _bankDetails
                                                          .firstWhere(
                                                            (b) =>
                                                                b['id']
                                                                    .toString() ==
                                                                _selectedPaymentMode,
                                                            orElse: () => {
                                                              'bank_name':
                                                                  'Paid',
                                                            },
                                                          )['bank_name']
                                                          .toString(),
                                                style: TextStyle(
                                                  color: const Color(
                                                    0xFF1A1A2E,
                                                  ),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 14),

                              // Order Summary / Payment Breakdown
                              if (_cartData != null &&
                                  _cartData!['cart_total'] != null) ...[
                                GestureDetector(
                                  onTap: () {
                                    setSheetState(() {
                                      showDetails = !showDetails;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const TranslatedText(
                                                  'Order Summary',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(
                                                  showDetails
                                                      ? Icons
                                                            .keyboard_arrow_up_rounded
                                                      : Icons
                                                            .keyboard_arrow_down_rounded,
                                                  size: 18,
                                                  color: Colors.grey[600],
                                                ),
                                              ],
                                            ),
                                            if (!showDetails)
                                              Text(
                                                '₹${_grandTotal.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: theme.primaryColor,
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (showDetails) ...[
                                          const SizedBox(height: 10),
                                          const Divider(height: 1),
                                          const SizedBox(height: 10),
                                          ...(_cartData!['cart_total'] as List).map(
                                            (e) => Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  TranslatedText(
                                                    e['title'] ?? '',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  TranslatedText(
                                                    '₹${e['value']?.toString() ?? '0.0'}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 12,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],

                              // Place Order Button
                              SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _reviewOrder();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      TranslatedText(
                                        'Place Order',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                      ),
                                    ],
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
  }

  /// Cache products for local fuzzy search.
  /// Avoids duplicates by checking product IDs.
  void _cacheProducts(List<Map<String, dynamic>> products) {
    final existingIds = _allProductsCache
        .map((p) => p['id']?.toString() ?? '')
        .toSet();
    for (final product in products) {
      final id = product['id']?.toString() ?? '';
      if (id.isNotEmpty && !existingIds.contains(id)) {
        _allProductsCache.add(product);
        existingIds.add(id);
      }
    }
    print('📦 Product cache size: ${_allProductsCache.length}');
  }

  /// Perform local fuzzy search on cached products.
  List<Map<String, dynamic>> _fuzzySearchLocal(String query) {
    if (query.trim().isEmpty || _allProductsCache.isEmpty) return [];

    return FuzzySearch.search<Map<String, dynamic>>(
      items: _allProductsCache,
      query: query,
      getSearchableStrings: (product) {
        final strings = <String>[];
        if (product['product_name'] != null) {
          strings.add(product['product_name'].toString());
        }
        if (product['description'] != null &&
            product['description'] != 'undefined') {
          strings.add(product['description'].toString());
        }
        if (product['child_category'] != null) {
          strings.add(product['child_category'].toString());
        }
        if (product['product_code'] != null) {
          strings.add(product['product_code'].toString());
        }
        if (product['barcode'] != null) {
          strings.add(product['barcode'].toString());
        }
        return strings;
      },
      minScore: 0.3,
    );
  }

  /// Merge server results with local fuzzy results, prioritizing server results.
  List<Map<String, dynamic>> _mergeSearchResults(
    List<Map<String, dynamic>> serverResults,
    List<Map<String, dynamic>> localResults,
  ) {
    final serverIds = serverResults
        .map((p) => p['id']?.toString() ?? '')
        .toSet();

    // Add local results that aren't already in server results
    final merged = List<Map<String, dynamic>>.from(serverResults);
    for (final localProduct in localResults) {
      final id = localProduct['id']?.toString() ?? '';
      if (id.isNotEmpty && !serverIds.contains(id)) {
        merged.add(localProduct);
      }
    }
    return merged;
  }

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      // If search is empty, fetch products by selected category
      if (_selectedCategoryId != null) {
        await _fetchProductsByCategory(_selectedCategoryId!);
      }
      return;
    }

    // Step 1: Show instant local fuzzy results first
    final localResults = _fuzzySearchLocal(query);
    if (localResults.isNotEmpty) {
      setState(() {
        _products = localResults;
        _productsError = null;
        _hasMoreProducts = false;
      });
    }

    // Step 2: Also run server search in background
    try {
      setState(() {
        // Only show loading if no local results
        if (localResults.isEmpty) {
          _isProductsLoading = true;
        }
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
          final serverProducts = List<Map<String, dynamic>>.from(
            data['response'],
          );

          // Cache server results too
          _cacheProducts(serverProducts);

          // Merge server + local fuzzy results
          final merged = _mergeSearchResults(serverProducts, localResults);

          setState(() {
            _products = merged;
            _isProductsLoading = false;
            _hasMoreProducts = data['has_next'] ?? false;
          });
        } else {
          // Server returned no results — keep local fuzzy results if available
          if (localResults.isEmpty) {
            setState(() {
              _products = [];
              _productsError = 'No products found for "$query"';
              _isProductsLoading = false;
              _hasMoreProducts = false;
            });
          } else {
            setState(() {
              _isProductsLoading = false;
            });
          }
        }
      } else {
        // API error — keep local results if available
        if (localResults.isEmpty) {
          setState(() {
            _productsError = 'Search failed';
            _isProductsLoading = false;
            _hasMoreProducts = false;
          });
        } else {
          setState(() {
            _isProductsLoading = false;
          });
        }
      }
    } catch (e) {
      // Network error — keep local results if available
      if (localResults.isEmpty) {
        setState(() {
          _productsError = 'Search error: $e';
          _isProductsLoading = false;
          _hasMoreProducts = false;
        });
      } else {
        setState(() {
          _isProductsLoading = false;
        });
      }
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

          // Select the first enabled payment method
          final enabledMethod = methods.firstWhere(
            (m) => m['is_enabled'] == true,
            orElse: () => methods.isNotEmpty ? methods.first : {},
          );

          if (enabledMethod.isNotEmpty && enabledMethod['id'] != null) {
            setState(() {
              _selectedPaymentMethodId = enabledMethod['id'];
            });
            print('Selected Payment Method ID: $_selectedPaymentMethodId');
            print(
              'Payment Method Name: ${enabledMethod['payment_method_name']}',
            );
          }
        }
      }
    } catch (e) {
      print('Error fetching payment methods: $e');
    }
  }

  void _onSearchChanged(String value) {
    // Immediately show local fuzzy results for instant feedback
    if (value.isNotEmpty) {
      final localResults = _fuzzySearchLocal(value);
      if (localResults.isNotEmpty) {
        setState(() {
          _products = localResults;
          _productsError = null;
        });
      }
    }

    // Debounce server search for network efficiency
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

  // Customer Phone Bottom Sheet — Premium Redesign
  Future<void> _showCustomerPhoneDialog() async {
    final TextEditingController phoneController = TextEditingController();
    CountryCode selectedCountry = CountryCode.fromCountryCode('IN');
    bool isLoading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
            final primaryColor = Theme.of(context).primaryColor;

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                bottom: bottomPadding + 24,
                top: 24,
                left: 28,
                right: 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Hero icon
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primaryColor.withOpacity(0.15),
                            primaryColor.withOpacity(0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 32,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title & subtitle
                  const Center(
                    child: TranslatedText(
                      'Customer Details',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TranslatedText(
                      _posCustomerWorkflow == 'ask_at_checkout'
                          ? 'Enter number to finalize the order'
                          : 'Link customer for rewards & history',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Phone input
                  Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        CountryCodePicker(
                          onChanged: (CountryCode countryCode) {
                            setState(() => selectedCountry = countryCode);
                          },
                          initialSelection: 'IN',
                          favorite: const ['+91', 'IN'],
                          showCountryOnly: false,
                          showOnlyCountryWhenClosed: false,
                          showFlagMain: true,
                          alignLeft: false,
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          boxDecoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          flagWidth: 24,
                        ),
                        Container(
                          width: 1,
                          height: 24,
                          color: const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Phone number',
                              hintStyle: TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 16,
                              ),
                              filled: false,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // QR scanner
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
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
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: Color(0xFF64748B),
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Primary action
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final phone = phoneController.text.trim();
                              if (phone.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: TranslatedText(
                                      'Please enter a phone number',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setState(() => isLoading = true);

                              final countryCode =
                                  selectedCountry.dialCode?.replaceAll(
                                    '+',
                                    '',
                                  ) ??
                                  '91';
                              final fullPhoneNumber = '$countryCode$phone';

                              try {
                                bool found = await _fetchCustomerData(
                                  fullPhoneNumber,
                                );
                                if (!found) {
                                  await _addStoreCustomer(fullPhoneNumber);
                                }
                                if (mounted) Navigator.pop(context);
                              } catch (e) {
                                setState(() => isLoading = false);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
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
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const TranslatedText(
                              'Continue',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Secondary action — Continue as Guest
                  SizedBox(
                    height: 48,
                    child: TextButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              setState(() => isLoading = true);
                              const String guestPhoneNumber = '910000000018';
                              try {
                                await _fetchCustomerData(
                                  guestPhoneNumber,
                                  silent: true,
                                );
                                if (mounted) Navigator.pop(context);
                              } catch (e) {
                                setState(() => isLoading = false);
                                debugPrint('Guest fetch error: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: TranslatedText(
                                        'Guest load failed: ${e.toString()}',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const TranslatedText(
                        'Continue as Guest',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Fetch customer data from API
  Future<bool> _fetchCustomerData(
    String phoneNumber, {
    bool silent = false,
  }) async {
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

            if (mounted && !silent) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: TranslatedText(
                    'Customer loaded: ${userData['first_name']} ${userData['last_name']}',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print('Error fetching customer data: $e');
      rethrow;
    }
  }

  /// Registers (or looks up) a customer via the store-staff endpoint.
  /// No name or gender is required — the API is idempotent and will return
  /// the existing account if the phone number is already in the database.
  Future<void> _addStoreCustomer(String phoneNumber) async {
    try {
      final response = await ApiService.post(
        '/add-store-customer/',
        body: {
          'store_access': true,
          'store_id': widget.storeId,
          'customer_phone_number': phoneNumber,
        },
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if ((data['status'] == 200 || data['status'] == 201) &&
            data['response'] != null) {
          final List<dynamic> userList = data['response'];
          if (userList.isNotEmpty) {
            final userData = userList[0] as Map<String, dynamic>;
            setState(() {
              customer_user_id =
                  data['customer_user_id'] as String? ??
                  userData['id'] as String?;
              _currentCustomer = userData;
            });

            // Refresh products and cart with new customer ID
            if (customer_user_id != null) {
              await _fetchOrderMethods();
              await _fetchUserAddresses();
              _fetchProductsByCategory(_selectedCategoryId ?? 'all');
              _validateCart();
            }
          }
        }
      } else {
        final msg =
            response['data']?['message'] ?? 'Failed to register customer';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: TranslatedText(msg.toString()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in _addStoreCustomer: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use a lighter/white background for modern look
    final scaffold = Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50], // Lighter background
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              _buildTopBanner(theme),

              Expanded(
                child: _posCategoryLayout == 'left'
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCategoriesSection(
                            theme,
                            constraints.maxWidth > 700,
                          ),
                          Expanded(child: _buildProductsGrid(theme)),
                          if (constraints.maxWidth > 1100)
                            _buildCheckoutPanel(theme, _checkoutPanelWidth),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildCategoriesSection(
                            theme,
                            constraints.maxWidth > 700,
                          ),
                          Expanded(child: _buildProductsGrid(theme)),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton:
          _totalProductsInCart > 0 && MediaQuery.of(context).size.width <= 1100
          ? SizedBox(
              height: 45,
              child: AnimatedBuilder(
                animation: _cartShimmerAnimation,
                builder: (context, child) {
                  // Alpine green base and shimmer sweep
                  const alpineGreen = Color(0xFF2E7D52);
                  const alpineGreenLight = Color(0xFF3DA068);
                  final shimmerPos = _cartShimmerAnimation.value;

                  return GestureDetector(
                    onTap: _showCartBottomSheet,
                    child: Container(
                      height: 45,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          begin: Alignment(shimmerPos - 2.5, 0),
                          end: Alignment(shimmerPos + 1.5, 0),
                          colors: const [
                            alpineGreen,
                            alpineGreen,
                            Color(
                              0xFF438A63,
                            ), // Solid, slightly lighter green for the subtle sheen (no transparency)
                            alpineGreen,
                            alpineGreen,
                          ],
                          stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: alpineGreen.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shopping_cart,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$_totalProductsInCart Items  •  ₹${_grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          : null,
    );

    return Stack(
      children: [
        scaffold,
        if (_isDesktopSearchOverlayVisible) _buildDesktopSearchOverlay(theme),
      ],
    );
  }

  void _hideDesktopSearchOverlay() {
    setState(() => _isDesktopSearchOverlayVisible = false);
    widget.desktopActionController?.restoreFocus?.call();
  }

  Widget _buildDesktopSearchOverlay(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape):
            _hideDesktopSearchOverlay,
      },
      child: Focus(
        autofocus: true,
        child: GestureDetector(
          onTap: _hideDesktopSearchOverlay,
          child: Stack(
            children: [
              // Backdrop
              Container(
                color: isDark
                    ? const Color(0xFF0F0F1A).withOpacity(0.85)
                    : const Color(0xFF1A1A2E).withOpacity(0.75),
              ),
              // Search box
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: EdgeInsets.only(
                    top: math.max(
                      80,
                      MediaQuery.of(context).size.height * 0.12,
                    ),
                  ),
                  child: GestureDetector(
                    onTap: () {}, // Prevent dismiss on inner tap
                    child: Container(
                      width: math.min(
                        640,
                        MediaQuery.of(context).size.width * 0.75,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.grey.withOpacity(0.12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 40,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Search input
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : const Color(0xFFF5F6F8),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.grey.withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search_rounded,
                                  size: 22,
                                  color: theme.primaryColor,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    focusNode: _desktopSearchFocusNode,
                                    onChanged: _onSearchChanged,
                                    onSubmitted: (_) =>
                                        _hideDesktopSearchOverlay(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textInputAction: TextInputAction.search,
                                    decoration: InputDecoration(
                                      hintText:
                                          'Search products by name or code...',
                                      hintStyle: TextStyle(
                                        color: Colors.grey.withOpacity(0.45),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                if (_searchController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                    ),
                                    color: Colors.grey,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Hint bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildKeyHint('ESC', isDark),
                              const SizedBox(width: 6),
                              Text(
                                'close',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade400,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 16),
                              _buildKeyHint('ENTER', isDark),
                              const SizedBox(width: 6),
                              Text(
                                'search',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
      ),
    );
  }

  Widget _buildKeyHint(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white60 : Colors.grey.shade600,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _showCustomerProfileDialog() {
    if (_currentCustomer == null) {
      _showCustomerPhoneDialog();
      return;
    }

    final user = _currentCustomer!;

    // Extract data with fallbacks
    final firstName = user['first_name'] ?? 'Guest';
    final lastName = user['last_name'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final phone = user['phone_number']?.toString() ?? 'N/A';

    // Get tier color for avatar styling - matching App Design (Blue)
    final creditScore = (user['credit_score'] ?? 0) as num;
    final loyaltyScore = (user['loyalty_score'] ?? 0) as num;
    final behaviourScore = (user['behaviour_score'] ?? 0) as num;

    // Use app primary color
    const primaryColor = Color(0xFF3B82F6);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compact Header with Avatar and Name
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
                  child: Column(
                    children: [
                      // Avatar at the top
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEFF6FF), // Light blue bg
                          border: Border.all(
                            color: const Color(0xFFBFDBFE),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            firstName.isNotEmpty
                                ? firstName[0].toUpperCase()
                                : 'G',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Name
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B), // Slate 800
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Phone number only
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9), // Slate 100
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.phone_rounded,
                              size: 14,
                              color: Color(0xFF64748B), // Slate 500
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '+$phone',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569), // Slate 600
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Simple Stats Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC), // Slate 50
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSimpleStat('Credit', creditScore),
                        Container(
                          width: 1,
                          height: 30,
                          color: const Color(0xFFE2E8F0),
                        ),
                        _buildSimpleStat('Loyalty', loyaltyScore),
                        Container(
                          width: 1,
                          height: 30,
                          color: const Color(0xFFE2E8F0),
                        ),
                        _buildSimpleStat('Behavior', behaviourScore),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _showCustomerPhoneDialog();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            foregroundColor: const Color(0xFF64748B),
                          ),
                          child: const Text(
                            'Switch',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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

  Widget _buildSimpleStat(String label, num score) {
    Color scoreColor;
    if (score >= 80) {
      scoreColor = const Color(0xFF16A34A); // Green
    } else if (score >= 50) {
      scoreColor = const Color(0xFF3B82F6); // Blue
    } else {
      scoreColor = const Color(0xFFF59E0B); // Amber
    }

    return Column(
      children: [
        Text(
          score.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: scoreColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8), // Slate 400
          ),
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
              padding: EdgeInsets.fromLTRB(
                12,
                MediaQuery.of(context).padding.top + 8,
                12,
                12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                              if (widget.onMenuPressed != null) {
                                widget.onMenuPressed!();
                              } else {
                                // Fallback: Try to open nearest drawer if any (only works if ancestor has it)
                                Scaffold.maybeOf(context)?.openDrawer();
                              }
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

                      // Layout Settings Button
                      SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TranslatedText(
                              'LAYOUT',
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
                              onTap: _showLayoutSettingsDialog,
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
                                  Icons.dashboard_customize_outlined,
                                  color: Colors.blueGrey,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Menu Sync Button
                      SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TranslatedText(
                              'MENU SYNC',
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
                              onTap: _showMenuSyncDialog,
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
                                child: const Icon(
                                  Icons.menu_book_outlined,
                                  color: Colors.blueGrey,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Customer Profile Button (with label and bigger size)
                      SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TranslatedText(
                              customer_user_id != null
                                  ? 'USER STATS'
                                  : 'ADD USER',
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
                              onTap: _showCustomerProfileDialog,
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
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Colors.blueGrey,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
    return Align(
      alignment: Alignment.centerLeft, // Match default bar alignment
      child: Container(
        key: const ValueKey('expanded_search'),
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
            width: 1.5,
          ), // Match button border
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          autofocus: true,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: 'Search products...',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF1565C0), // Keep blue accent for icon
              size: 20,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
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
                    size: 18,
                  ),
                  color: _isListening ? Colors.red : Colors.grey[600],
                  tooltip: 'Voice Search',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                Container(
                  height: 16,
                  width: 1,
                  color: Colors.grey[300],
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
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
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  // Helper placeholder to match previous code style if w_width_container was just my typo
  // I will assume I need to use Container with double.infinity width

  Widget _buildDefaultOptionsBar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: double.infinity,
        child: Row(
          key: const ValueKey('default_options'),
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Order Method (Minimized / Fit Content)
            _buildActionBox(
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
                          mainAxisSize: MainAxisSize.min, // Hug content
                          children: [
                            Icon(
                              Icons.room_service_outlined,
                              size: 18,
                              color: const Color(0xFFE65100),
                            ),
                            const SizedBox(width: 8),
                            // Flexible ensures text does not force infinite width
                            Flexible(
                              fit: FlexFit.loose,
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
                            const SizedBox(width: 8),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(
                      width: 120, // Min width placeholder
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
            ),

            const SizedBox(width: 12),

            // Search Action (Expanded - Takes remaining space)
            Expanded(child: _buildSearchBoxContent()),

            const SizedBox(width: 12),

            // Scanner Action (Fixed width)
            SizedBox(width: 90, child: _buildScanBoxContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBoxContent() {
    return InkWell(
      onTap: () {
        focusSearch();
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
    );
  }

  Widget _buildScanBoxContent() {
    return InkWell(
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
          padding: const EdgeInsets.only(left: 4, bottom: 2),
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
          height: 36, // Reduced height for less chunky look
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

  void _showLayoutSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final primary = Theme.of(context).primaryColor;
        return StatefulBuilder(
          builder: (context, setStateLocal) {
            Widget buildSection({
              required IconData icon,
              required String title,
              required String subtitle,
              required Widget child,
            }) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, size: 16, color: primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    child,
                  ],
                ),
              );
            }

            return Dialog(
              backgroundColor: const Color(0xFFF7F8FA),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [primary, primary.withOpacity(0.75)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Layout Settings',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Customize your POS workspace',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: Colors.grey[600],
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body (scrollable)
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            buildSection(
                              icon: Icons.view_sidebar_rounded,
                              title: 'Categories Position',
                              subtitle: 'Where the category menu appears',
                              child: Row(
                                children: [
                                  _layoutOptionChip(
                                    'Left',
                                    'left',
                                    setStateLocal,
                                  ),
                                  const SizedBox(width: 8),
                                  _layoutOptionChip(
                                    'Top',
                                    'top',
                                    setStateLocal,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            buildSection(
                              icon: Icons.straighten_rounded,
                              title: 'Sidebar Width',
                              subtitle: 'Spacing for the categories panel',
                              child: Row(
                                children: [
                                  _sizeOptionChip(
                                    'Compact',
                                    70.0,
                                    setStateLocal,
                                  ),
                                  const SizedBox(width: 8),
                                  _sizeOptionChip(
                                    'Normal',
                                    90.0,
                                    setStateLocal,
                                  ),
                                  const SizedBox(width: 8),
                                  _sizeOptionChip('Wide', 120.0, setStateLocal),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            buildSection(
                              icon: Icons.grid_view_rounded,
                              title: 'Product Card Size',
                              subtitle: 'Density of the product grid',
                              child: Builder(
                                builder: (dialogContext) {
                                  final dialogWidth = MediaQuery.of(
                                    dialogContext,
                                  ).size.width;
                                  final isMobile = dialogWidth <= 600;
                                  final smallDisabled =
                                      isMobile && _posCategoryLayout == 'left';
                                  if (smallDisabled &&
                                      _posProductCardSize <= 180.0) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          setStateLocal(
                                            () => _posProductCardSize = 220.0,
                                          );
                                        });
                                  }
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          _cardSizeOptionChip(
                                            'Small',
                                            180.0,
                                            setStateLocal,
                                            disabled: smallDisabled,
                                          ),
                                          const SizedBox(width: 8),
                                          _cardSizeOptionChip(
                                            'Normal',
                                            220.0,
                                            setStateLocal,
                                          ),
                                          const SizedBox(width: 8),
                                          _cardSizeOptionChip(
                                            'Large',
                                            280.0,
                                            setStateLocal,
                                          ),
                                        ],
                                      ),
                                      if (smallDisabled)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.info_outline_rounded,
                                                size: 13,
                                                color: Colors.grey[500],
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  "Small cards aren't available with a side menu on mobile",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
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
                            ),
                            const SizedBox(height: 12),
                            buildSection(
                              icon: Icons.text_fields_rounded,
                              title: 'Display Mode',
                              subtitle: 'Toggle product imagery',
                              child: InkWell(
                                onTap: () => setStateLocal(
                                  () => _isTextOnlyMode = !_isTextOnlyMode,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Text Only Mode',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: Color(0xFF1F2937),
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Hide product images to save space',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Switch.adaptive(
                                        value: _isTextOnlyMode,
                                        activeColor: primary,
                                        onChanged: (val) => setStateLocal(
                                          () => _isTextOnlyMode = val,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            buildSection(
                              icon: Icons.tune_rounded,
                              title: 'Checkout Options Style',
                              subtitle: 'How order options appear in the cart',
                              child: Row(
                                children: [
                                  _optionsLayoutChip(
                                    'Dropdown',
                                    'dropdown',
                                    setStateLocal,
                                  ),
                                  const SizedBox(width: 8),
                                  _optionsLayoutChip(
                                    'Inline',
                                    'inline',
                                    setStateLocal,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Footer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                foregroundColor: Colors.grey[700],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setString(
                                  'pos_category_layout',
                                  _posCategoryLayout,
                                );
                                await prefs.setDouble(
                                  'pos_category_size',
                                  _posCategorySize,
                                );
                                await prefs.setDouble(
                                  'pos_product_card_size',
                                  _posProductCardSize,
                                );
                                await prefs.setBool(
                                  'pos_text_only_mode',
                                  _isTextOnlyMode,
                                );
                                await prefs.setString(
                                  'pos_options_layout',
                                  _posOptionsLayout,
                                );
                                if (mounted) {
                                  setState(() {});
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text(
                                'Apply Changes',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
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

  Widget _layoutOptionChip(
    String label,
    String value,
    StateSetter setStateLocal,
  ) {
    final isSelected = _posCategoryLayout == value;
    return Expanded(
      child: InkWell(
        onTap: () => setStateLocal(() => _posCategoryLayout = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[300]!,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mini layout preview
              Container(
                width: 40,
                height: 30,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.2)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withOpacity(0.4)
                        : Colors.grey[400]!,
                    width: 1,
                  ),
                ),
                child: value == 'left'
                    ? Row(
                        children: [
                          Container(
                            width: 10,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[500],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(3),
                                bottomLeft: Radius.circular(3),
                              ),
                            ),
                          ),
                          Expanded(child: Container()),
                        ],
                      )
                    : Column(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[500],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(3),
                                topRight: Radius.circular(3),
                              ),
                            ),
                          ),
                          Expanded(child: Container()),
                        ],
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[800],
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionsLayoutChip(
    String label,
    String value,
    StateSetter setStateLocal,
  ) {
    final isSelected = _posOptionsLayout == value;
    return Expanded(
      child: InkWell(
        onTap: () => setStateLocal(() => _posOptionsLayout = value),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[300]!,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[800],
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sizeOptionChip(String label, double size, StateSetter setStateLocal) {
    final isSelected = _posCategorySize == size;
    return Expanded(
      child: InkWell(
        onTap: () => setStateLocal(() => _posCategorySize = size),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.grey[300]!,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[800],
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardSizeOptionChip(
    String label,
    double size,
    StateSetter setStateLocal, {
    bool disabled = false,
  }) {
    final isSelected = _posProductCardSize == size;
    return Expanded(
      child: InkWell(
        onTap: disabled
            ? null
            : () => setStateLocal(() => _posProductCardSize = size),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: disabled
                ? Colors.grey[100]
                : (isSelected ? Theme.of(context).primaryColor : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: disabled
                  ? Colors.grey[200]!
                  : (isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300]!),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: disabled
                  ? Colors.grey[400]
                  : (isSelected ? Colors.white : Colors.grey[800]),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesSection(ThemeData theme, bool isDesktop) {
    const topBarHeight = 56.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600 && screenWidth <= 900;
    final sidebarScale = isDesktop ? 1.8 : (isTablet ? 1.5 : 1.0);
    final effectiveWidth = _posCategoryLayout == 'left'
        ? _posCategorySize * sidebarScale
        : _posCategorySize;

    // Match top banner palette
    const sidebarBg = Color(0xFFEFF6FF);
    const sidebarDivider = Color(0xFFDBEAFE);
    final bool isLeftSidebar = _posCategoryLayout == 'left';

    if (_isCategoriesLoading) {
      return Container(
        width: isLeftSidebar ? effectiveWidth : double.infinity,
        height: _posCategoryLayout == 'top' ? topBarHeight : double.infinity,
        decoration: BoxDecoration(
          color: isLeftSidebar ? sidebarBg : Colors.white,
          border: isLeftSidebar
              ? const Border(right: BorderSide(color: sidebarDivider))
              : Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_categoriesError != null) {
      return Container(
        width: isLeftSidebar ? effectiveWidth : double.infinity,
        height: _posCategoryLayout == 'top' ? topBarHeight : double.infinity,
        color: isLeftSidebar ? sidebarBg : Colors.white,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.grey[400], size: 28),
            const SizedBox(height: 8),
            IconButton(
              icon: Icon(Icons.refresh, color: theme.primaryColor),
              onPressed: _fetchCategories,
              tooltip: 'Retry',
            ),
          ],
        ),
      );
    }

    // ========== TOP BAR (Clean text-only pills) ==========
    if (_posCategoryLayout == 'top') {
      return Container(
        width: double.infinity,
        height: topBarHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = category['id'] == _selectedCategoryId;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategoryId = category['id'];
                    _searchController.clear();
                  });
                  _fetchProductsByCategory(category['id']);
                },
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? theme.primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? theme.primaryColor
                          : Colors.grey[300]!,
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: theme.primaryColor.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: TranslatedText(
                      _capitalizeCategoryName(category['category_name'] ?? ''),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey[800],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    // ========== LEFT SIDEBAR (Light-blue, matching top banner) ==========
    return Container(
      width: effectiveWidth,
      decoration: const BoxDecoration(
        color: sidebarBg,
        border: Border(right: BorderSide(color: sidebarDivider, width: 1)),
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _categories.length,
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

              Future.delayed(const Duration(milliseconds: 300), () {
                if (categoryKey.currentContext != null) {
                  Scrollable.ensureVisible(
                    categoryKey.currentContext!,
                    alignment: 0.5,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              });
            },
            child: AnimatedContainer(
              key: categoryKey,
              duration: const Duration(milliseconds: 200),
              padding: isDesktop
                  ? const EdgeInsets.symmetric(horizontal: 14, vertical: 18)
                  : const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: isSelected ? theme.primaryColor : Colors.transparent,
                    width: 3,
                  ),
                  bottom: const BorderSide(color: sidebarDivider, width: 1),
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TranslatedText(
                  _capitalizeCategoryName(category['category_name'] ?? ''),
                  textAlign: TextAlign.left,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: isDesktop ? 14 : 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? theme.primaryColor : Colors.grey[800],
                    height: 1.2,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCheckoutPanel(ThemeData theme, double width) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Resizable drag handle
        MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _checkoutPanelWidth -= details.delta.dx;
                _checkoutPanelWidth = _checkoutPanelWidth.clamp(260.0, 480.0);
              });
            },
            child: Container(
              width: 8,
              color: Colors.transparent,
              child: Center(
                child: Container(
                  width: 2,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Panel content
        Container(
          width: width,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            border: Border(
              left: BorderSide(color: Colors.grey[200]!, width: 1),
            ),
          ),
          child: Column(
            children: [
              // Premium Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[100]!, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const TranslatedText(
                      'Order Summary',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A2E),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 12,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$_totalProductsInCart',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: theme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Cart Items
              Expanded(
                child: _cartItemsAvailable.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.shopping_cart_outlined,
                                size: 28,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const TranslatedText(
                              'Your cart is empty',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const TranslatedText(
                              'Add items to get started',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: _cartItemsAvailable.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _cartItemsAvailable[index];
                          final pricing = item['pricing_details'] ?? {};
                          final quantity =
                              item['enquired_quantity'] ??
                              item['quantity'] ??
                              0;
                          final productImg =
                              item['product_image'] ??
                              item['image'] ??
                              item['img_url'];

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Product Image
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F6F8),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: productImg != null
                                      ? CustomCachedNetworkImage(
                                          imgUrl: productImg,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(
                                          Icons.image_not_supported_outlined,
                                          color: Colors.grey,
                                          size: 18,
                                        ),
                                ),
                                const SizedBox(width: 12),

                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      TranslatedText(
                                        item['product_name'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Color(0xFF1A1A2E),
                                          height: 1.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      // Discount badge
                                      if ((pricing['discount_percent'] ?? 0) >
                                          0) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF5B4FE8,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${pricing['discount_percent'].toStringAsFixed(0)}% OFF',
                                                style: const TextStyle(
                                                  color: Color(0xFF5B4FE8),
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              '₹${(pricing['original_sale_price_excl_tax']?.toDouble() ?? pricing['selling_amount_excluding_tax']?.toDouble() ?? 0).toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 10,
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '₹${pricing['item_total']?.toStringAsFixed(2) ?? '0.00'}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: theme.primaryColor,
                                            ),
                                          ),
                                          // Discount + Quantity
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Discount button
                                              InkWell(
                                                onTap: () {
                                                  _showDiscountDialog(
                                                    item['product_in_cart_id']
                                                            ?.toString() ??
                                                        '',
                                                    (pricing['max_discount_percent']
                                                                ?.toDouble() ??
                                                            0)
                                                        .toDouble(),
                                                    (pricing['discount_percent']
                                                                ?.toDouble() ??
                                                            0)
                                                        .toDouble(),
                                                    () => setState(() {}),
                                                  );
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Container(
                                                  width: 26,
                                                  height: 26,
                                                  decoration: BoxDecoration(
                                                    color:
                                                        (pricing['discount_percent'] ??
                                                                0) >
                                                            0
                                                        ? const Color(
                                                            0xFF5B4FE8,
                                                          ).withOpacity(0.1)
                                                        : const Color(
                                                            0xFFF5F6F8,
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.local_offer_outlined,
                                                    size: 14,
                                                    color:
                                                        (pricing['discount_percent'] ??
                                                                0) >
                                                            0
                                                        ? const Color(
                                                            0xFF5B4FE8,
                                                          )
                                                        : Colors.grey[500],
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              // Quantity controls
                                              Container(
                                                height: 26,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFF5F6F8,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    _buildQtyBtn(
                                                      Icons.remove,
                                                      () async {
                                                        await _decrementCartItem(
                                                          item['product_combination_id'] ??
                                                              '',
                                                          item['product_id'] ??
                                                              '',
                                                        );
                                                      },
                                                    ),
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                          ),
                                                      child: Text(
                                                        '$quantity',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 12,
                                                          color: Color(
                                                            0xFF1A1A2E,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    _buildQtyBtn(
                                                      Icons.add,
                                                      () async {
                                                        await _incrementCartItem(
                                                          item['product_combination_id'] ??
                                                              '',
                                                          item['product_id'] ??
                                                              '',
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              // Bottom controls — unified card
              if (_cartItemsAvailable.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Colors.grey[100]!, width: 1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Order Details Card
                      if (_posOptionsLayout == 'dropdown')
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            children: [
                              // Order Type
                              InkWell(
                                onTap: () async {
                                  await _showOrderMethodSelection();
                                  setState(() {});
                                },
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.room_service_outlined,
                                          size: 15,
                                          color: Colors.orange.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Order Type',
                                              style: TextStyle(
                                                color: Colors.black45,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            TranslatedText(
                                              _selectedOrderMethod?['order_method_name'] ??
                                                  'Select Type',
                                              style: TextStyle(
                                                color: Colors.orange.shade800,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.keyboard_arrow_right,
                                        size: 16,
                                        color: Colors.grey[400],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Table Selector
                              InkWell(
                                onTap: () => _showTableSelectionDialog(
                                  (fn) => setState(fn),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: _selectedTable != null
                                              ? const Color(
                                                  0xFF5B4FE8,
                                                ).withOpacity(0.08)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.table_restaurant_outlined,
                                          size: 15,
                                          color: _selectedTable != null
                                              ? const Color(0xFF5B4FE8)
                                              : Colors.grey[400],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _selectedTable != null
                                            ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Table',
                                                    style: TextStyle(
                                                      color: Colors.black45,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  Text(
                                                    _selectedTable!['table_number']
                                                            ?.toString() ??
                                                        '',
                                                    style: const TextStyle(
                                                      color: Color(0xFF5B4FE8),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                'Select Table',
                                                style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                      ),
                                      if (_selectedTable != null)
                                        GestureDetector(
                                          onTap: () => setState(
                                            () => _selectedTable = null,
                                          ),
                                          child: Icon(
                                            Icons.close_rounded,
                                            size: 14,
                                            color: Colors.grey[400],
                                          ),
                                        )
                                      else
                                        Icon(
                                          Icons.keyboard_arrow_right,
                                          size: 16,
                                          color: Colors.grey[400],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              // Payment Method
                              InkWell(
                                onTap: () {
                                  _showPaymentModeSelector(
                                    (fn) => setState(fn),
                                  );
                                },
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.payments_outlined,
                                          size: 15,
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Payment',
                                              style: TextStyle(
                                                color: Colors.black45,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              _selectedPaymentMode == 'UNPAID'
                                                  ? 'Unpaid'
                                                  : _selectedPaymentMode ==
                                                        'MULTI-MODE'
                                                  ? 'Split Payment'
                                                  : (_bankDetails.firstWhere(
                                                              (b) =>
                                                                  b['id']
                                                                      .toString() ==
                                                                  _selectedPaymentMode,
                                                              orElse: () => {
                                                                'bank_name':
                                                                    'Paid',
                                                              },
                                                            )['bank_name'] ??
                                                            'Paid')
                                                        .toString(),
                                              style: TextStyle(
                                                color: theme.primaryColor,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.keyboard_arrow_right,
                                        size: 16,
                                        color: Colors.grey[400],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        // Inline layout for desktop
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  await _showOrderMethodSelection();
                                  setState(() {});
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.room_service_outlined,
                                        size: 16,
                                        color: Colors.orange.shade700,
                                      ),
                                      const SizedBox(height: 4),
                                      TranslatedText(
                                        _selectedOrderMethod?['order_method_name'] ??
                                            'Type',
                                        style: TextStyle(
                                          color: Colors.orange.shade800,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () => _showTableSelectionDialog(
                                  (fn) => setState(fn),
                                ),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _selectedTable != null
                                        ? const Color(
                                            0xFF5B4FE8,
                                          ).withOpacity(0.08)
                                        : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _selectedTable != null
                                          ? const Color(
                                              0xFF5B4FE8,
                                            ).withOpacity(0.3)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.table_restaurant_outlined,
                                        size: 16,
                                        color: _selectedTable != null
                                            ? const Color(0xFF5B4FE8)
                                            : Colors.grey[500],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedTable != null
                                            ? _selectedTable!['table_number']
                                                      ?.toString() ??
                                                  'Table'
                                            : 'Table',
                                        style: TextStyle(
                                          color: _selectedTable != null
                                              ? const Color(0xFF5B4FE8)
                                              : Colors.grey[600],
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  _showPaymentModeSelector(
                                    (fn) => setState(fn),
                                  );
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.payments_outlined,
                                        size: 16,
                                        color: theme.primaryColor,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedPaymentMode == 'UNPAID'
                                            ? 'Unpaid'
                                            : _selectedPaymentMode ==
                                                  'MULTI-MODE'
                                            ? 'Split'
                                            : _bankDetails
                                                  .firstWhere(
                                                    (b) =>
                                                        b['id'].toString() ==
                                                        _selectedPaymentMode,
                                                    orElse: () => {
                                                      'bank_name': 'Paid',
                                                    },
                                                  )['bank_name']
                                                  .toString(),
                                        style: const TextStyle(
                                          color: Color(0xFF1A1A2E),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 14),

                      // Total & Place Order
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Amount',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${_grandTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: () => _reviewOrder(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Place Order',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_rounded, size: 16),
                                  ],
                                ),
                              ),
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
      ],
    );
  }

  Widget _buildProductsGrid(ThemeData theme) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;
    final isTablet = screenWidth > 600 && screenWidth <= 900;

    // Available width for the grid (subtract sidebar, checkout panel, and outer padding)
    final sidebarScale = isDesktop ? 1.8 : (isTablet ? 1.5 : 1.0);
    final effectiveSidebarWidth = _posCategoryLayout == 'left'
        ? _posCategorySize * sidebarScale
        : 0;
    final checkoutPanelWidth =
        (screenWidth > 1100 && _posCategoryLayout == 'left')
        ? _checkoutPanelWidth
        : 0.0;
    final gridWidth =
        screenWidth - effectiveSidebarWidth - checkoutPanelWidth - 16;

    // Compute columns so each card targets ~_posProductCardSize px wide.
    // This makes Small/Normal/Large meaningful at every screen size.
    final int minCols = _posProductCardSize <= 180
        ? 2
        : (_posProductCardSize <= 220 ? 2 : 1);
    int crossAxisCount = math.max(
      minCols,
      (gridWidth / _posProductCardSize).floor(),
    );

    final totalSpacing = (crossAxisCount - 1) * 10;
    final cardWidth = (gridWidth - totalSpacing) / crossAxisCount;

    // Pick aspect ratio so card height stays comfortable
    double cardAspectRatio;
    if (_isTextOnlyMode) {
      // Guarantee enough height for: pad*2 + name(2 lines) + gap + price + gap + button
      // Min content needed: 8 + 32 + 4 + 22 + 6 + 28 = ~100px
      // Add safety margin -> 110px
      final minContentHeight = 110.0;
      // Don't let card be taller than 1.6x its width
      final targetHeight = math.max(minContentHeight, cardWidth / 1.0);
      cardAspectRatio = cardWidth / targetHeight;
    } else if (crossAxisCount == 1) {
      final targetHeight = isDesktop ? 360 : (isTablet ? 320 : 280);
      cardAspectRatio = cardWidth / targetHeight;
    } else if (crossAxisCount == 2) {
      final targetHeight = isDesktop ? 320 : (isTablet ? 280 : 250);
      cardAspectRatio = cardWidth / targetHeight;
    } else {
      final targetHeight = isDesktop ? 280 : (isTablet ? 250 : 200);
      cardAspectRatio = cardWidth / targetHeight;
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        // Trigger pagination when near the end of scroll
        if (scrollInfo.metrics.pixels >=
            scrollInfo.metrics.maxScrollExtent - 200) {
          if (!_isLoadingMore && _hasMoreProducts && !_isProductsLoading) {
            _loadMoreProducts();
          }
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async {
          final cartFuture = _validateCart();
          final categoryFuture = _fetchCategories();
          final methodFuture = _fetchOrderMethods();
          await Future.wait([cartFuture, categoryFuture, methodFuture]);
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
                padding: const EdgeInsets.only(
                  left: 8,
                  right: 8,
                  top: 12,
                  bottom: 120, // Added significant bottom padding
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: cardAspectRatio,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
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
            // Load More button when there are more products (fallback for when scrolling doesn't trigger)
            if (!_isProductsLoading &&
                !_isLoadingMore &&
                _hasMoreProducts &&
                _products.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: _loadMoreProducts,
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      label: const TranslatedText('Load More Products'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // Show "No more products" message if at end
            if (!_isProductsLoading &&
                !_hasMoreProducts &&
                _products.isNotEmpty)
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
      ),
    );
  }

  Widget _buildProductCard(ThemeData theme, Map<String, dynamic> product) {
    final productName = product['product_name'] ?? 'Product';
    final dynamic rawPrice =
        product['lowest_available_price'] ?? product['price_starts_from'];
    final bool isPriceAvailable = rawPrice != null;
    final productPrice = rawPrice ?? 0;
    final productImage = product['img_url'];

    if (_isTextOnlyMode) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isPriceAvailable ? () => _handleAddToCart(product) : null,
            borderRadius: BorderRadius.circular(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final h = constraints.maxHeight;
                final w = constraints.maxWidth;
                final pad = h < 90 ? 6.0 : (h < 120 ? 8.0 : 10.0);
                final btnH = h < 90 ? 24.0 : (h < 120 ? 26.0 : 30.0);
                final nameFontSize = w < 100 ? 11.0 : 12.0;
                final priceFontSize = w < 100 ? 10.0 : 11.0;
                final priceChipH = priceFontSize * 1.4 + 6;
                final gapPriceToBtn = h < 100 ? 4.0 : 6.0;
                final gapNameToPrice = h < 100 ? 4.0 : 6.0;

                return Padding(
                  padding: EdgeInsets.all(pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Name — takes available space above the bottom block
                      Expanded(
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: TranslatedText(
                            productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: nameFontSize,
                              color: Colors.black87,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: gapNameToPrice),
                      // Price chip (pinned above button)
                      SizedBox(
                        height: priceChipH,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isPriceAvailable
                                  ? const Color(0xFF2E7D32).withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isPriceAvailable
                                  ? '₹$productPrice'
                                  : 'Unavailable',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isPriceAvailable
                                    ? const Color(0xFF2E7D32)
                                    : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: priceFontSize,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: gapPriceToBtn),
                      // Button — absolute bottom
                      SizedBox(
                        height: btnH,
                        width: double.infinity,
                        child: _buildProductAction(theme, product),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

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
          onTap: isPriceAvailable ? () => _handleAddToCart(product) : null,
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final w = constraints.maxWidth;

              // Bottom section sizing — adaptive to card height
              final bottomPad = math.min(14.0, math.max(6.0, h * 0.05));
              final gap = math.min(8.0, math.max(2.0, h * 0.025));
              final btnH = math.min(32.0, math.max(22.0, h * 0.14));
              final nameH = math.min(32.0, math.max(16.0, h * 0.14));
              final bottomNeed =
                  bottomPad + nameH + gap + btnH + 1; // +1 for separator

              // Image gets the rest, but at least 25% of card
              final imageH = math.max(h * 0.25, h - bottomNeed);
              final actualBottomH = h - imageH - 1;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Product Image Area with Price Overlay
                  SizedBox(
                    height: imageH,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: productImage != null
                              ? (isPriceAvailable
                                    ? CustomCachedNetworkImage(
                                        imgUrl: productImage,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                      )
                                    : ColorFiltered(
                                        colorFilter:
                                            const ColorFilter.matrix(<double>[
                                              0.2126,
                                              0.7152,
                                              0.0722,
                                              0,
                                              0,
                                              0.2126,
                                              0.7152,
                                              0.0722,
                                              0,
                                              0,
                                              0.2126,
                                              0.7152,
                                              0.0722,
                                              0,
                                              0,
                                              0,
                                              0,
                                              0,
                                              1,
                                              0,
                                            ]),
                                        child: Opacity(
                                          opacity: 0.6,
                                          child: CustomCachedNetworkImage(
                                            imgUrl: productImage,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          ),
                                        ),
                                      ))
                              : Container(
                                  color: Colors.grey[100],
                                  child: Icon(
                                    Icons.inventory_2_outlined,
                                    size: math.min(
                                      28,
                                      math.max(16, imageH * 0.2),
                                    ),
                                    color: Colors.grey[400],
                                  ),
                                ),
                        ),
                        // Price Tag Overlay
                        if (isPriceAvailable)
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TranslatedText(
                                '₹$productPrice',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: math.min(12, math.max(9, w * 0.08)),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Solid Separator
                  Container(height: 1, color: Colors.grey[300]),

                  // Product Details (Name + Button)
                  Container(
                    height: actualBottomH,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      math.min(6, w * 0.03),
                      math.min(6, h * 0.02),
                      math.min(6, w * 0.03),
                      math.min(8, h * 0.03),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Name
                        SizedBox(
                          height: nameH,
                          child: TranslatedText(
                            productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: math.min(12, math.max(10, h * 0.055)),
                              color: isPriceAvailable
                                  ? Colors.black87
                                  : Colors.grey[600],
                              height: 1.15,
                            ),
                          ),
                        ),
                        SizedBox(height: gap),

                        // Button — always pinned to bottom
                        SizedBox(
                          height: btnH,
                          width: double.infinity,
                          child: _buildProductAction(theme, product),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProductAction(ThemeData theme, Map<String, dynamic> product) {
    final dynamic rawPrice =
        product['lowest_available_price'] ?? product['price_starts_from'];
    final bool isPriceAvailable = rawPrice != null;

    if (!isPriceAvailable) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final label = w < 60
              ? 'N/A'
              : w < 80
              ? 'Unavail...'
              : 'Not Available';
          return Container(
            height: constraints.maxHeight,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: math.max(2, w * 0.04)),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: TranslatedText(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          );
        },
      );
    }

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
              Flexible(
                child: TranslatedText(
                  'Add',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
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
                // Look up the product_combination_id from cart items
                String combinationId = '';
                final pid = product['id']?.toString() ?? '';
                for (var cartItem in _cartItemsAvailable) {
                  if (cartItem['product_id']?.toString() == pid ||
                      cartItem['id']?.toString() == pid) {
                    combinationId =
                        cartItem['product_combination_id']?.toString() ??
                        cartItem['id']?.toString() ??
                        '';
                    break;
                  }
                }
                _decrementCartItem(combinationId, product['id']);
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
    final productId = product['id']?.toString() ?? '';

    try {
      // Call API to get product variations (no blocking dialog)
      final variationBody = {
        'order_by': 'variation_name',
        'query': {'store_id': widget.storeId, 'product_id': product['id']},
        'store_id': widget.storeId,
        'customer_user_id': customer_user_id ?? '',
        'store_access': true,
      };
      if ((customer_user_id == null || customer_user_id!.isEmpty) &&
          _guestSessionId != null &&
          _guestSessionId!.isNotEmpty) {
        variationBody['guest_session_id'] = _guestSessionId!;
      }
      final response = await ApiService.post(
        '/product-variation-value/',
        body: variationBody,
        useBearerToken: true,
      );

      if (!mounted) return;

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        final additionalData = data['additional_data'];

        // Case A: Product added directly (no variants)
        if (additionalData != null &&
            additionalData['is_product_added_to_cart_successfully'] == true) {
          // Optimistic UI update - increment quantity locally (immediate)
          _updateLocalProductQuantity(productId, 1);

          // Update cart state in background (non-blocking)
          _validateCart();
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

  Future<void> _showOrderMethodSelection() {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final theme = Theme.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor:
              Colors.transparent, // Transparent to let Container handle it
          elevation: 0,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with improved spacing and Cancel Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TranslatedText(
                          'Order Type',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B), // Slate 800
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TranslatedText(
                          'Select how to fulfill this order',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    // Refined Close Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Options List
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: _orderMethods.map((method) {
                        final isSelected =
                            method['id'] == _selectedOrderMethod?['id'];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedOrderMethod = method;
                                });
                                Navigator.pop(context);
                                _validateCart();
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.primaryColor.withOpacity(0.04)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.primaryColor
                                        : Colors.grey[200]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Icon Box
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey[50],
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? theme.primaryColor.withOpacity(
                                                  0.1,
                                                )
                                              : Colors.transparent,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: method['img_url'] != null
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: CustomCachedNetworkImage(
                                                imgUrl: method['img_url'],
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Icon(
                                              Icons.inventory_2_rounded,
                                              color: isSelected
                                                  ? theme.primaryColor
                                                  : Colors.grey[400],
                                              size: 28,
                                            ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Text Content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TranslatedText(
                                            method['order_method_name'] ??
                                                'Unknown',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? const Color(0xFF1E293B)
                                                  : const Color(0xFF334155),
                                            ),
                                          ),
                                          if (method['order_method_description'] !=
                                                  null &&
                                              method['order_method_description']
                                                  .toString()
                                                  .isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              child: TranslatedText(
                                                method['order_method_description'],
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[500],
                                                  height: 1.3,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    // Selection Indicator
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? theme.primaryColor
                                              : Colors.grey[300]!,
                                          width: 2,
                                        ),
                                        color: isSelected
                                            ? theme.primaryColor
                                            : Colors.transparent,
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              size: 16,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        guestSessionId: _guestSessionId,
        onCartUpdated: () {
          // Optimistic UI update - increment quantity locally
          _updateLocalProductQuantity(product['id']?.toString() ?? '', 1);
          // Update cart state without refetching products
          _validateCart();
        },
      ),
    );
  }

  void _showMenuSyncDialog() {
    File? selectedFile;
    String? jobId;
    String statusMessage = 'Pick a menu image or PDF to sync';
    bool isUploading = false;
    bool isPolling = false;
    String? errorMessage;
    Map<String, dynamic>? syncResult;
    Timer? pollTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            Future<void> pickFile() async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
                  allowMultiple: false,
                );
                if (result != null && result.files.single.path != null) {
                  setDlgState(() {
                    selectedFile = File(result.files.single.path!);
                    statusMessage =
                        'Ready to upload: ${result.files.single.name}';
                    errorMessage = null;
                  });
                }
              } catch (e) {
                setDlgState(() => errorMessage = 'File pick error: $e');
              }
            }

            Future<void> uploadAndPoll() async {
              if (selectedFile == null) return;
              setDlgState(() {
                isUploading = true;
                statusMessage = 'Uploading menu image...';
                errorMessage = null;
              });

              try {
                final response = await ApiService.postMultipart(
                  endpoint: '/sync-menu-intelligence/',
                  files: {'file': selectedFile!},
                  fields: {'store_id': widget.storeId, 'store_access': 'true'},
                  useBearerToken: true,
                );

                if (response['statusCode'] == 202 && response['data'] != null) {
                  final data = response['data'];
                  jobId = data['job_id']?.toString();
                  if (jobId != null) {
                    setDlgState(() {
                      isUploading = false;
                      isPolling = true;
                      statusMessage = 'AI is processing your menu...';
                    });
                    _startMenuSyncPolling(
                      jobId!,
                      setDlgState,
                      (result) {
                        setDlgState(() {
                          syncResult = result;
                          isPolling = false;
                          statusMessage =
                              'Done! ${result['total_items_parsed'] ?? 0} items synced.';
                        });
                      },
                      (err) {
                        setDlgState(() {
                          isPolling = false;
                          errorMessage = err;
                          statusMessage = 'Sync failed';
                        });
                      },
                    );
                  } else {
                    setDlgState(() {
                      isUploading = false;
                      errorMessage = 'No job_id returned';
                    });
                  }
                } else {
                  final errorData = response['data'];
                  setDlgState(() {
                    isUploading = false;
                    errorMessage =
                        errorData?['response'] ??
                        errorData?['message'] ??
                        'Upload failed';
                  });
                }
              } catch (e) {
                setDlgState(() {
                  isUploading = false;
                  errorMessage = 'Upload error: $e';
                });
              }
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF5B4FE8), Color(0xFF8B5CF6)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.menu_book_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sync Menu from Image',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'AI reads your menu and creates products',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              pollTimer?.cancel();
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.close_rounded, size: 20),
                            color: Colors.grey[600],
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // File picker area
                            InkWell(
                              onTap: isUploading || isPolling ? null : pickFile,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selectedFile != null
                                        ? const Color(0xFF5B4FE8)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      selectedFile != null
                                          ? Icons.check_circle_rounded
                                          : Icons.add_photo_alternate_outlined,
                                      size: 40,
                                      color: selectedFile != null
                                          ? const Color(0xFF5B4FE8)
                                          : Colors.grey[400],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      selectedFile != null
                                          ? 'File selected'
                                          : 'Tap to pick image or PDF',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: selectedFile != null
                                            ? const Color(0xFF5B4FE8)
                                            : Colors.grey[600],
                                      ),
                                    ),
                                    if (selectedFile != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        selectedFile!.path
                                            .split('/')
                                            .last
                                            .split('\\')
                                            .last,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Status
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: errorMessage != null
                                    ? Colors.red[50]
                                    : syncResult != null
                                    ? Colors.green[50]
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: errorMessage != null
                                      ? Colors.red.shade200
                                      : syncResult != null
                                      ? Colors.green.shade200
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (isUploading || isPolling)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else if (errorMessage != null)
                                    Icon(
                                      Icons.error_outline_rounded,
                                      size: 16,
                                      color: Colors.red[600],
                                    )
                                  else if (syncResult != null)
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 16,
                                      color: Colors.green[600],
                                    )
                                  else
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 16,
                                      color: Colors.grey[500],
                                    ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      errorMessage ?? statusMessage,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: errorMessage != null
                                            ? Colors.red[700]
                                            : syncResult != null
                                            ? Colors.green[700]
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Result list
                            if (syncResult != null &&
                                syncResult!['items'] != null) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Synced Items',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...((syncResult!['items'] as List)
                                      .take(10)
                                      .toList())
                                  .map(
                                    (item) => Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item['product_name'] ?? 'Unknown',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
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
                                              color:
                                                  item['store_action'] ==
                                                      'added'
                                                  ? Colors.green[100]
                                                  : Colors.grey[200],
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item['store_action']
                                                      ?.toString()
                                                      .replaceAll('_', ' ') ??
                                                  '',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    item['store_action'] ==
                                                        'added'
                                                    ? Colors.green[800]
                                                    : Colors.grey[700],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              if ((syncResult!['items'] as List).length > 10)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '+ ${(syncResult!['items'] as List).length - 10} more items',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Footer
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                foregroundColor: Colors.grey[700],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: Colors.grey.shade300),
                                ),
                              ),
                              onPressed: () {
                                pollTimer?.cancel();
                                Navigator.pop(ctx);
                              },
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          if (selectedFile != null &&
                              !isUploading &&
                              !isPolling &&
                              syncResult == null) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5B4FE8),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: uploadAndPoll,
                                child: const Text(
                                  'Start Sync',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (syncResult != null) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5B4FE8),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                  ),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () {
                                  pollTimer?.cancel();
                                  Navigator.pop(ctx);
                                  // Refresh products and categories
                                  _fetchCategories();
                                  _fetchProductsByCategory(
                                    _selectedCategoryId ?? 'all',
                                    isRefresh: true,
                                  );
                                },
                                child: const Text(
                                  'Done — Refresh Store',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
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

  void _startMenuSyncPolling(
    String jobId,
    StateSetter setDlgState,
    Function(Map<String, dynamic>) onDone,
    Function(String) onError,
  ) {
    int attempts = 0;
    const maxAttempts = 60; // 4s * 60 = 4 minutes

    Timer.periodic(const Duration(seconds: 4), (timer) async {
      attempts++;
      if (attempts > maxAttempts) {
        timer.cancel();
        onError('Timed out waiting for menu sync to complete.');
        return;
      }

      try {
        final response = await ApiService.get(
          '/sync-menu-intelligence/status/$jobId/',
          useBearerToken: true,
        );

        if (response['statusCode'] == 200 && response['data'] != null) {
          final data = response['data'];
          final jobStatus = data['job_status']?.toString();

          if (jobStatus == 'done') {
            timer.cancel();
            onDone(Map<String, dynamic>.from(data['response'] ?? {}));
          } else if (jobStatus == 'failed') {
            timer.cancel();
            onError(data['error']?.toString() ?? 'Menu sync failed');
          } else {
            setDlgState(() {}); // Refresh UI to show still processing
          }
        } else if (response['statusCode'] == 404) {
          timer.cancel();
          onError('Job not found. It may have expired.');
        }
      } catch (e) {
        timer.cancel();
        onError('Polling error: $e');
      }
    });
  }
}

// Stateful Bottom Sheet Widget for Variants
class _VariantsBottomSheetContent extends StatefulWidget {
  final Map<String, dynamic> product;
  final List variations;
  final String storeId;
  final String? customerUserId;
  final String? guestSessionId;
  final VoidCallback onCartUpdated;

  const _VariantsBottomSheetContent({
    required this.product,
    required this.variations,
    required this.storeId,
    required this.customerUserId,
    this.guestSessionId,
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
      final body = {
        'product_id': widget.product['id'],
        'store_id': widget.storeId,
        'store_access': true,
        'customer_user_id': widget.customerUserId ?? '',
        'quantity': _quantity,
        'variations': _selectedVariationIds,
      };
      if ((widget.customerUserId == null || widget.customerUserId!.isEmpty) &&
          widget.guestSessionId != null &&
          widget.guestSessionId!.isNotEmpty) {
        body['guest_session_id'] = widget.guestSessionId!;
      }
      final response = await ApiService.post(
        '/validate-product-availability/',
        body: body,
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

  void _selectVariation(
    List<dynamic> variationValues,
    String variationValueId,
  ) {
    setState(() {
      // Create a list of all IDs in this variation group
      final groupIds = variationValues.map((v) => v['id']?.toString()).toList();

      // Remove any currently selected ID that belongs to this group (Mutual Exclusion)
      _selectedVariationIds.removeWhere((id) => groupIds.contains(id));

      // Add the new selection
      _selectedVariationIds.add(variationValueId);
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
                        final valueId = value['id']?.toString() ?? '';
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
                            onTap: () =>
                                _selectVariation(variationValues, valueId),
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
      final body = {
        'quantity': _quantity,
        'product_id': widget.product['id'],
        'store_id': widget.storeId,
        'store_access': true,
        'customer_user_id': widget.customerUserId ?? '',
        'variations': _selectedVariationIds,
      };
      if ((widget.customerUserId == null || widget.customerUserId!.isEmpty) &&
          widget.guestSessionId != null &&
          widget.guestSessionId!.isNotEmpty) {
        body['guest_session_id'] = widget.guestSessionId!;
      }
      final response = await ApiService.post(
        '/add-product-in-cart/',
        body: body,
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200) {
          if (mounted) {
            Navigator.pop(context);
            widget.onCartUpdated(); // Refresh cart
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
