import 'dart:math' as math;
import 'package:exanor/components/custom_cached_network_image.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ProductDetailScreen extends StatefulWidget {
  final String storeId;
  final String productId; // combination id

  /// Optionally pass the lightweight summary already loaded in the list
  /// to avoid showing an empty left panel while the detail API loads.
  final Map<String, dynamic>? initialData;

  const ProductDetailScreen({
    super.key,
    required this.storeId,
    required this.productId,
    this.initialData,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _product;
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  // ── Reviews state ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _reviews = [];
  bool _reviewsLoading = false;
  bool _reviewsHasNext = false;
  int _reviewsPage = 1;
  String? _reviewsError;
  bool _reviewsFetched = false;

  // ── Manufacturing state ──────────────────────────────────────────────
  List<Map<String, dynamic>> _boms = [];
  List<Map<String, String>> _orderMethods =
      []; // {id, name} pairs from /orders/ API
  bool _mfgLoading = false;
  bool _mfgFetched = false;
  String? _mfgError;
  static const _kAllMethods = '__all__';
  String _selectedOrderMethod = _kAllMethods; // sentinel = All Methods

  // ── Pricing edit state ───────────────────────────────────────────────
  bool _isPriceEditMode = false;
  bool _isPriceSaving = false;
  late TextEditingController _salePriceCtrl;
  late TextEditingController _mrpCtrl;
  late TextEditingController _costPriceCtrl;
  late TextEditingController _maxDiscountCtrl;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Initialise price controllers with empty — they get populated after fetch
    _salePriceCtrl = TextEditingController();
    _mrpCtrl = TextEditingController();
    _costPriceCtrl = TextEditingController();
    _maxDiscountCtrl = TextEditingController();
    if (widget.initialData != null) {
      _product = widget.initialData;
      _isLoading = false;
      _syncPriceControllers();
    }
    _fetchDetail();
  }

  void _onTabChanged() {
    // Only trigger on settled tab (not mid-animation).
    if (mounted && !_tabController.indexIsChanging) {
      setState(() {});
      // Auto-load reviews the first time the Reviews tab is selected.
      if (_tabController.index == 1 && !_reviewsFetched) {
        _fetchReviews();
      }
      // Auto-load manufacturing the first time that tab is selected.
      if (_tabController.index == 2 && !_mfgFetched) {
        _fetchManufacturing();
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _salePriceCtrl.dispose();
    _mrpCtrl.dispose();
    _costPriceCtrl.dispose();
    _maxDiscountCtrl.dispose();
    super.dispose();
  }

  // ── API ───────────────────────────────────────────────────────────────────
  Future<void> _fetchDetail() async {
    if (!_isLoading) setState(() => _isLoading = true);
    try {
      final response = await ApiService.post(
        '/show-my-store-products-combinations/',
        body: {
          'store_id': widget.storeId,
          'query': {'id': widget.productId},
          'page': 1,
          'limit': 10,
          'store_access': true,
        },
        useBearerToken: true,
      );
      if (!mounted) return;
      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 &&
            data['response'] != null &&
            (data['response'] as List).isNotEmpty) {
          setState(() {
            _product = Map<String, dynamic>.from(data['response'][0]);
            _isLoading = false;
            _error = null;
          });
          _syncPriceControllers();
        } else {
          setState(() {
            _isLoading = false;
            _error = 'Product not found.';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load product details.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Error: $e';
      });
    }
  }

  // ── Reviews API ──────────────────────────────────────────────────────────
  Future<void> _fetchReviews({bool loadMore = false}) async {
    if (_reviewsLoading) return;
    if (!mounted) return;

    final productId = _product?['product_id']?.toString() ?? '';
    if (productId.isEmpty) return;

    final page = loadMore ? _reviewsPage + 1 : 1;

    setState(() {
      _reviewsLoading = true;
      _reviewsError = null;
      if (!loadMore) {
        _reviews = [];
        _reviewsPage = 1;
      }
    });

    try {
      final data = await StoreOwnerApiService.getProductReviews(
        storeId: widget.storeId,
        productId: productId,
        page: page,
      );

      if (!mounted) return;

      final List<dynamic> rawList = data['response'] ?? [];
      final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

      setState(() {
        _reviewsLoading = false;
        _reviewsFetched = true;
        _reviewsPage = page;
        _reviewsHasNext = pagination['has_next'] == true;
        if (loadMore) {
          _reviews.addAll(rawList.map((e) => Map<String, dynamic>.from(e)));
        } else {
          _reviews = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reviewsLoading = false;
        _reviewsError = e.toString();
      });
    }
  }

  // ── Manufacturing API ──────────────────────────────────────────────────
  Future<void> _fetchManufacturing() async {
    if (_mfgLoading || !mounted) return;

    setState(() {
      _mfgLoading = true;
      _mfgError = null;
    });

    try {
      // Run both API calls in parallel.
      final results = await Future.wait([
        StoreOwnerApiService.getBomOperations(
          storeId: widget.storeId,
          productCombinationId: widget.productId,
        ),
        StoreOwnerApiService.getOrderMethods(widget.storeId),
      ]);

      if (!mounted) return;

      // Handle both response shapes:
      //   { "response": { "boms": [...] } }  — nested
      //   { "response": [ ... ] }             — flat list
      final bomResponse = (results[0] as Map)['response'];
      final List<dynamic> rawBoms;
      if (bomResponse is List) {
        rawBoms = bomResponse;
      } else if (bomResponse is Map) {
        rawBoms = (bomResponse['boms'] as List<dynamic>?) ?? [];
      } else {
        rawBoms = [];
      }

      // Order methods come directly as List<Map<String,String>> from getOrderMethods.
      final orderMethods = results[1] as List<Map<String, String>>;

      setState(() {
        _mfgLoading = false;
        _mfgFetched = true;
        _boms = rawBoms.map((e) => Map<String, dynamic>.from(e)).toList();
        _orderMethods = orderMethods;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mfgLoading = false;
        _mfgError = e.toString();
      });
    }
  }

  // ── Toggle update API ───────────────────────────────────────────────
  Future<void> _updateToggle(String field, bool newValue) async {
    if (_product == null) return;

    // Optimistic update — mutate in-place so the widget tree recognises
    // the same map instance and only repaints the Switch, avoiding a
    // full tree teardown that deactivates contexts.
    final previous = _product![field];
    _product![field] = newValue;
    if (mounted) setState(() {});

    try {
      final response = await ApiService.put(
        '/product-combinations/',
        body: {
          'products_combinations_id': widget.productId,
          'store_id': widget.storeId,
          'store_access': true,
          'data': {field: newValue},
        },
        useBearerToken: true,
      );

      if (!mounted) return;

      final ok =
          response['statusCode'] == 200 &&
          (response['data']?['status'] == 200 ||
              response['data']?['status'] == 'success');

      if (!ok) {
        // Roll back
        _product![field] = previous;
        setState(() {});
        _showBar('Update failed. Please try again.', Colors.red);
      } else {
        _showBar(
          '${_fieldLabel(field)} ${newValue ? "enabled" : "disabled"}',
          const Color(0xFF16A34A),
        );
        // Auto-refresh so all fields reflect the server state
        _fetchDetail();
      }
    } catch (e) {
      if (!mounted) return;
      _product![field] = previous;
      setState(() {});
      _showBar('Error: $e', Colors.red);
    }
  }

  /// Sync price text controllers from the loaded product map.
  void _syncPriceControllers() {
    final p = _product;
    if (p == null) return;
    _salePriceCtrl.text =
        (double.tryParse(p['sale_price']?.toString() ?? '0') ?? 0.0)
            .toStringAsFixed(2);
    _mrpCtrl.text = (double.tryParse(p['mrp']?.toString() ?? '0') ?? 0.0)
        .toStringAsFixed(2);
    _costPriceCtrl.text =
        (double.tryParse(p['cost_price']?.toString() ?? '0') ?? 0.0)
            .toStringAsFixed(2);
    _maxDiscountCtrl.text =
        (double.tryParse(p['max_discount_percent']?.toString() ?? '0') ?? 0.0)
            .toStringAsFixed(2);
  }

  /// PUT /product-combinations/ — update sale_price, mrp, cost_price.
  Future<void> _updatePrices() async {
    final salePrice = double.tryParse(_salePriceCtrl.text.trim()) ?? 0.0;
    final mrp = double.tryParse(_mrpCtrl.text.trim()) ?? 0.0;
    final costPrice = double.tryParse(_costPriceCtrl.text.trim()) ?? 0.0;
    final maxDiscountPercent =
        double.tryParse(_maxDiscountCtrl.text.trim()) ?? 0.0;

    setState(() => _isPriceSaving = true);
    try {
      final response = await ApiService.put(
        '/product-combinations/',
        body: {
          'products_combinations_id': widget.productId,
          'store_id': widget.storeId,
          'store_access': true,
          'data': {
            'sale_price': salePrice,
            'mrp': mrp,
            'cost_price': costPrice,
            'max_discount_percent': maxDiscountPercent,
          },
        },
        useBearerToken: true,
      );
      if (!mounted) return;
      final ok =
          response['statusCode'] == 200 &&
          (response['data']?['status'] == 200 ||
              response['data']?['status'] == 'success');
      if (ok) {
        // Update local product map to reflect new prices
        _product?['sale_price'] = salePrice;
        _product?['mrp'] = mrp;
        _product?['cost_price'] = costPrice;
        _product?['max_discount_percent'] = maxDiscountPercent;
        setState(() {
          _isPriceEditMode = false;
          _isPriceSaving = false;
        });
        _showBar('Prices updated successfully', const Color(0xFF16A34A));
        // Auto-refresh to sync server state
        _fetchDetail();
      } else {
        setState(() => _isPriceSaving = false);
        _showBar('Failed to update prices. Please try again.', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPriceSaving = false);
      _showBar('Error: $e', Colors.red);
    }
  }

  /// Safe snackbar helper — only shows if still mounted.
  void _showBar(String message, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: bg,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _fieldLabel(String field) {
    switch (field) {
      case 'is_accessible_online':
        return 'Online Access';
      case 'is_accessible_pos':
        return 'POS Access';
      case 'auto_produce':
        return 'Auto Produce';
      case 'is_inventory_management_required':
        return 'Inventory Management';
      default:
        return field;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _cap(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _fmtTs(dynamic ts) {
    if (ts == null) return '—';
    try {
      final dt = DateTime.fromMillisecondsSinceEpoch(
        (ts as num).toInt() * 1000,
      );
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return '—';
    }
  }

  String _fmtMoney(dynamic v, {String prefix = '₹ '}) {
    if (v == null) return '$prefix 0';
    final n = double.tryParse(v.toString()) ?? 0.0;
    if (n == n.truncateToDouble()) {
      return '$prefix${n.toInt()}';
    }
    return '$prefix${n.toStringAsFixed(2)}';
  }

  String _fmtNum(dynamic v, {int decimals = 3}) {
    if (v == null) return '0';
    final n = double.tryParse(v.toString()) ?? 0.0;
    return n.toStringAsFixed(decimals);
  }

  String _pct(dynamic v) {
    if (v == null) return '0%';
    final n = double.tryParse(v.toString()) ?? 0.0;
    return '${n % 1 == 0 ? n.toInt() : n}%';
  }

  bool _isUndefined(dynamic v) =>
      v == null ||
      v.toString().toLowerCase() == 'undefined' ||
      v.toString().isEmpty;

  List<Map<String, dynamic>> get _inventory {
    final inv = _product?['inventory'];
    if (inv == null || inv is! List) return [];
    return List<Map<String, dynamic>>.from(inv);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading && _product == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _product == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: _buildErrorState(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 680) {
          return _buildWideLayout();
        }
        return _buildMobileLayout();
      },
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Something went wrong',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchDetail,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ── ULTRA PREM: Mobile Layout ─────────────────────────────────────────────
  Widget _buildMobileLayout() {
    final p = _product!;
    final imgUrl = p['img_url'] as String?;
    final hasImg = imgUrl != null && imgUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _fetchDetail,
        color: Colors.black,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 380,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    hasImg
                        ? CustomCachedNetworkImage(
                            imgUrl: imgUrl,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: const Color(0xFFF8FAFC),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              size: 80,
                              color: Colors.grey,
                            ),
                          ),
                    // Bottom gradient overlay for smooth blend
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 120,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              const Color(0xFFF8FAFC).withOpacity(0.0),
                              const Color(0xFFF8FAFC).withOpacity(0.8),
                              const Color(0xFFF8FAFC),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                transform: Matrix4.translationValues(0, -32, 0),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    _buildHeroBanner(p),
                    const SizedBox(height: 24),
                    _buildUnifiedDetailsContent(p),
                    const SizedBox(height: 28),
                    _buildMobileTabSelector(),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildMobileTabContent(),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedDetailsContent(Map<String, dynamic> p) {
    final totalBought = (p['total_purchased'] as num?)?.toDouble() ?? 0.0;
    final totalSold = (p['total_sold'] as num?)?.toDouble() ?? 0.0;
    final totalLeft = (p['total_left'] as num?)?.toDouble() ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Quick Stats ─────────────────────────────────────────────
        _buildSectionCard(
          title: 'Inventory Summary',
          accentColor: const Color(0xFF10B981),
          child: Row(
            children: [
              _statItem('Bought', totalBought.toStringAsFixed(0)),
              Container(height: 36, width: 1, color: const Color(0xFFE2E8F0)),
              _statItem('Sold', totalSold.toStringAsFixed(0)),
              Container(height: 36, width: 1, color: const Color(0xFFE2E8F0)),
              _statItem(
                'In Stock',
                totalLeft.toStringAsFixed(0),
                color: const Color(0xFF10B981),
              ),
            ],
          ),
        ),

        // ── Pricing Section ───────────────────────────────────────────
        _buildSectionCard(
          title: 'Pricing',
          accentColor: const Color(0xFFF59E0B),
          action: _buildEditAction(),
          child: _isPriceEditMode
              ? _buildPriceEditUX()
              : Row(
                  children: [
                    _priceColumn(
                      'Sale Price',
                      _fmtMoney(p['sale_price']),
                      true,
                    ),
                    const SizedBox(width: 28),
                    _priceColumn('MRP', _fmtMoney(p['mrp']), false),
                    const SizedBox(width: 28),
                    _priceColumn('Cost', _fmtMoney(p['cost_price']), false),
                    const SizedBox(width: 28),
                    _priceColumn(
                      'Max Discount',
                      _pct(p['max_discount_percent']),
                      false,
                    ),
                  ],
                ),
        ),

        // ── Specifications ──────────────────────────────────────────
        _buildSectionCard(
          title: 'Specifications',
          accentColor: const Color(0xFF8B5CF6),
          child: Column(
            children: [
              _buildSpecRow('Format', _cap(p['product_type'] ?? '')),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildSpecRow('Dietary', _cap(p['food_class'] ?? '')),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildSpecRow('Status', _cap(p['status'] ?? ''), isStatus: true),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _buildSpecRow(
                'Rating',
                (p['rating_count'] as num?) == 0
                    ? 'No ratings'
                    : '${p['average_rating']} (${p['rating_count']})',
              ),
            ],
          ),
        ),

        // ── Access & Controls ───────────────────────────────────────
        _buildSectionCard(
          title: 'Access & Controls',
          accentColor: const Color(0xFFEF4444),
          child: Column(
            children: [
              _minimalToggle(
                'Web Store Sync',
                'Available for online ordering',
                p['is_accessible_online'] == true,
                (v) => _updateToggle('is_accessible_online', v),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _minimalToggle(
                'POS Sync',
                'Available at physical terminals',
                p['is_accessible_pos'] == true,
                (v) => _updateToggle('is_accessible_pos', v),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _minimalToggle(
                'Auto-Replenish',
                'Trigger production automatically',
                p['auto_produce'] == true,
                (v) => _updateToggle('auto_produce', v),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _minimalToggle(
                'Stock Tracking',
                'Enforce inventory strict limits',
                p['is_inventory_management_required'] == true,
                (v) => _updateToggle('is_inventory_management_required', v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTabSelector() {
    const tabs = ['Inventory', 'Reviews', 'Manufacturing'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final selected = _tabController.index == i;
          return GestureDetector(
            onTap: () => _tabController.animateTo(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Text(
                tabs[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMobileTabContent() {
    switch (_tabController.index) {
      case 0:
        return _buildInventoryColumn();
      case 1:
        return _buildReviewsTab(isWide: false);
      case 2:
        return _buildManufacturingTab(isWide: false);
      default:
        return const SizedBox();
    }
  }

  // Inventory rendered as a plain Column (shrinkWrap-safe)
  Widget _buildInventoryColumn() {
    final inv = _inventory;
    if (inv.isEmpty) {
      return _buildPlaceholderInline(
        Icons.inventory_2_outlined,
        'No inventory records',
      );
    }
    return Column(
      children: [
        for (int i = 0; i < inv.length; i++) _buildInventoryCard(inv[i], i),
      ],
    );
  }

  Widget _buildPlaceholderInline(IconData icon, String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(msg, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ── ULTRA PREM: Wide Layout ───────────────────────────────────────────────
  Widget _buildWideLayout() {
    final p = _product!;
    final imgUrl = p['img_url'] as String?;
    final hasImg = imgUrl != null && imgUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(20),
          child: const Center(
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: Colors.black,
            ),
          ),
        ),
        title: const Text(
          'Product Detail',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Panel (Static info)
          SizedBox(
            width: 440,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasImg)
                    AspectRatio(
                      aspectRatio: 1.2,
                      child: CustomCachedNetworkImage(
                        imgUrl: imgUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    )
                  else
                    Container(
                      height: 300,
                      width: double.infinity,
                      color: const Color(0xFFF8FAFC),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        size: 80,
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildHeroBanner(p),
                  ),
                  const SizedBox(height: 24),
                  _buildUnifiedDetailsContent(p),
                ],
              ),
            ),
          ),
          const VerticalDivider(
            width: 1,
            thickness: 1,
            color: Color(0xFFF1F5F9),
          ),
          // Right Panel (Tabs)
          Expanded(
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xFF1E293B),
                    unselectedLabelColor: const Color(0xFF94A3B8),
                    indicatorColor: const Color(0xFF1E293B),
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    tabs: const [
                      Tab(text: 'Inventory'),
                      Tab(text: 'Reviews'),
                      Tab(text: 'Manufacturing'),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInventoryListWide(),
                        _buildReviewsTab(isWide: true),
                        _buildManufacturingTab(isWide: true),
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
  }

  // ── ULTRA PREM: Components ──────────────────────────────────────────────────
  Widget _statItem(String label, String value, {Color? color}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color ?? const Color(0xFF1E293B),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceColumn(String label, String value, bool isPrimary) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isPrimary ? 20 : 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
              letterSpacing: -0.3,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Hero Banner ───────────────────────────────────────────────────────────
  Widget _buildHeroBanner(Map<String, dynamic> p) {
    final name = p['product_name'] ?? 'Product Detail';
    final category = [
      _cap(p['parent_category'] ?? ''),
      _cap(p['child_category'] ?? ''),
    ].where((s) => !_isUndefined(s)).join(' › ');
    final status = _cap(p['status'] ?? '');
    final imgUrl = p['img_url'] as String?;
    final hasImg = imgUrl != null && imgUrl.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFBFDBFE)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Watermark decoration
            Positioned(
              right: -20,
              top: -20,
              child: Transform.rotate(
                angle: -math.pi / 8,
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 140,
                  color: const Color(0xFFBFDBFE).withOpacity(0.5),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: thumbnail + status badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product thumbnail
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFBFDBFE),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: hasImg
                            ? CustomCachedNetworkImage(
                                imgUrl: imgUrl,
                                fit: BoxFit.cover,
                                width: 56,
                                height: 56,
                              )
                            : const Icon(
                                Icons.inventory_2_outlined,
                                size: 28,
                                color: Color(0xFF94A3B8),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _statusColor(status).withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _statusColor(status),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Product name
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.8,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Category breadcrumb
                  if (category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFBFDBFE).withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                          letterSpacing: 0.3,
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
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('active') || s.contains('available'))
      return const Color(0xFF10B981);
    if (s.contains('draft')) return const Color(0xFFF59E0B);
    if (s.contains('inactive') || s.contains('discontinued'))
      return const Color(0xFFEF4444);
    return const Color(0xFF64748B);
  }

  // ── Section Card ──────────────────────────────────────────────────────────
  Widget _buildSectionCard({
    required String title,
    required Widget child,
    Widget? action,
    Color accentColor = const Color(0xFF2563EB),
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Accent bar
            Container(height: 3, width: double.infinity, color: accentColor),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  if (action != null) action,
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditAction() {
    return InkWell(
      onTap: () {
        _syncPriceControllers();
        setState(() => _isPriceEditMode = !_isPriceEditMode);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _isPriceEditMode
              ? const Color(0xFFFEF2F2)
              : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isPriceEditMode
                ? const Color(0xFFFCA5A5)
                : const Color(0xFFBFDBFE),
          ),
        ),
        child: Text(
          _isPriceEditMode ? 'Cancel' : 'Edit',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _isPriceEditMode
                ? const Color(0xFFDC2626)
                : const Color(0xFF2563EB),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceEditUX() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _minimalInput(
          label: 'Sale Price',
          controller: _salePriceCtrl,
          prefix: '₹',
        ),
        const SizedBox(height: 12),
        _minimalInput(label: 'MRP', controller: _mrpCtrl, prefix: '₹'),
        const SizedBox(height: 12),
        _minimalInput(
          label: 'Cost Price',
          controller: _costPriceCtrl,
          prefix: '₹',
        ),
        const SizedBox(height: 12),
        _minimalInput(
          label: 'Max Discount',
          controller: _maxDiscountCtrl,
          suffix: '%',
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isPriceSaving ? null : _updatePrices,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isPriceSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save Changes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _minimalInput({
    required String label,
    required TextEditingController controller,
    String? prefix,
    String? suffix,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                if (prefix != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      prefix,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                ),
                if (suffix != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      suffix,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecRow(String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: isStatus
                ? _buildStatusBadgePure(value)
                : Text(
                    value.isEmpty || _isUndefined(value) ? '—' : value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadgePure(String status) {
    final s = status.toLowerCase();
    Color color = const Color(0xFF64748B);
    if (s.contains('active') || s.contains('available'))
      color = const Color(0xFF10B981);
    if (s.contains('draft') || s.contains('inactive'))
      color = const Color(0xFFF59E0B);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          status.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _minimalToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF2563EB),
            activeTrackColor: const Color(0xFF2563EB).withOpacity(0.3),
          ),
        ],
      ),
    );
  }

  // Used in the wide TabBarView — ListView gets infinite height from TabBarView.
  Widget _buildInventoryListWide() {
    final inv = _inventory;
    if (inv.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No inventory records',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: inv.length,
      itemBuilder: (context, index) => _buildInventoryCard(inv[index], index),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> inv, int index) {
    final barcode = inv['uni_barcode']?.toString() ?? '';
    final originalBarcode = inv['original_barcode']?.toString() ?? '';
    final purchased = _fmtNum(inv['total_stocks_purchased']);
    final sold = _fmtNum(inv['total_stocks_sold']);
    final left = (inv['total_stocks_left'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.1)),
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
          // ── Barcode section ─────────────────────────────────────────
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BARCODE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Barcode graphic
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 48,
                              child: CustomPaint(
                                painter: _BarcodePainter(barcode),
                                child: Container(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Barcode text (split in rows of 24)
                            Text(
                              _breakEvery(barcode, 24),
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                                letterSpacing: 2.0,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (originalBarcode.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Original: $originalBarcode',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Print button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Print barcode — coming soon'),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.print_rounded,
                            size: 16,
                            color: Color(0xFF2563EB),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'PRINT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Purchased / Sold / Left ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _stockCard(
                    'Purchased',
                    purchased,
                    const Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _stockCard('Sold', sold, Colors.orange[700]!)),
                const SizedBox(width: 12),
                Expanded(
                  child: _stockCard(
                    'Left',
                    left.toStringAsFixed(0),
                    left > 0 ? const Color(0xFF16A34A) : Colors.grey[600]!,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 20),

          // ── Financial grid ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildFinancialGrid(inv),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _stockCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: color.withOpacity(0.8),
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialGrid(Map<String, dynamic> inv) {
    final rows = [
      _GridItem(
        'Cost (incl. tax)',
        _fmtMoney(inv['cost_amount_including_tax']),
      ),
      _GridItem(
        'Cost (excl. tax)',
        _fmtMoney(inv['cost_amount_excluding_tax']),
      ),
      _GridItem(
        'Sale (incl. tax)',
        _fmtMoney(inv['selling_amount_including_tax']),
      ),
      _GridItem('MRP', _fmtMoney(inv['mrp'])),
      _GridItem('CGST', _pct(inv['cgst_percent'])),
      _GridItem('SGST', _pct(inv['sgst_percent'])),
      _GridItem('IGST', _pct(inv['igst_percent'])),
      _GridItem('HSN Code', inv['hsn_code']?.toString() ?? '—'),
      _GridItem('Purchased On', _fmtTs(inv['purchase_timestamp'])),
      _GridItem('Expires', _fmtTs(inv['expiry_timestamp'])),
      _GridItem('State of Purchase', _cap(inv['state_code_of_purchase'] ?? '')),
    ];

    return Wrap(
      spacing: 0,
      runSpacing: 0,
      children: [
        for (int i = 0; i < rows.length; i++) _financialCell(rows[i], i),
      ],
    );
  }

  Widget _financialCell(_GridItem item, int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 64) / 3,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Reviews tab ───────────────────────────────────────────────────────────
  Widget _buildReviewsTab({required bool isWide}) {
    // If reviews haven't been fetched yet (e.g., wide layout loads all
    // TabBarView children upfront), trigger the first fetch.
    if (!_reviewsFetched && !_reviewsLoading) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_reviewsFetched) _fetchReviews();
      });
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Customer Reviews',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              if (_reviews.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_reviews.length} review${_reviews.length != 1 ? "s" : ""}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // ── Body ──────────────────────────────────────────────────────
        if (_reviewsLoading && _reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_reviewsError != null && _reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    _reviewsError ?? 'Failed to load reviews',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _fetchReviews,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (_reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 52,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No reviews yet',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Be the first to review this product!',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else ...[
          for (final review in _reviews) _buildReviewCard(review),
          if (_reviewsHasNext)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _reviewsLoading
                      ? null
                      : () => _fetchReviews(loadMore: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                  child: _reviewsLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load More'),
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
      ],
    );

    // Wide = inside Expanded TabBarView (finite height) → ListView.
    // Mobile = inside CustomScrollView (inline) → plain Column.
    if (isWide) {
      return ListView(padding: EdgeInsets.zero, children: [content]);
    }
    return content;
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = review['comment']?.toString() ?? '';
    final author =
        (review['customer_name']?.toString().isNotEmpty == true
            ? review['customer_name']!.toString()
            : null) ??
        (review['user_name']?.toString().isNotEmpty == true
            ? review['user_name']!.toString()
            : null) ??
        (review['name']?.toString().isNotEmpty == true
            ? review['name']!.toString()
            : null) ??
        'Anonymous';
    final ts = review['created_at'] ?? review['timestamp'];
    String dateStr = '';
    if (ts != null) {
      try {
        final dt = ts is num
            ? DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000)
            : DateTime.parse(ts.toString());
        dateStr = DateFormat('dd MMM yyyy').format(dt);
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(
                  0xFF2563EB,
                ).withValues(alpha: 0.12),
                child: Text(
                  author.isNotEmpty ? author[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                  ],
                ),
              ),
              // Star rating
              Row(
                children: List.generate(5, (i) {
                  final filled = i < rating.round();
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? const Color(0xFFF59E0B) : Colors.grey[300],
                    size: 16,
                  );
                }),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              comment,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Manufacturing tab ──────────────────────────────────────────────────────
  Widget _buildManufacturingTab({required bool isWide}) {
    if (!_mfgFetched && !_mfgLoading) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_mfgFetched) _fetchManufacturing();
      });
    }

    // Use order methods fetched from /orders/ API.
    final methods = _orderMethods;

    // "All Methods" sentinel → show every BOM regardless of order_method_name.
    // Specific method selected → match only that method.
    final filteredBoms = _selectedOrderMethod == _kAllMethods
        ? _boms // all BOMs, including those with null order_method_name
        : _boms
              .where(
                (b) =>
                    b['order_method_name']?.toString() == _selectedOrderMethod,
              )
              .toList();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header: row 1 = title + count ───────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: const Text(
            'Bills of Materials',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        if (_boms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '${_boms.length} active BOM${_boms.length != 1 ? "s" : ""}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
        // ── Header: row 2 = filter + create button ───────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Method filter dropdown
              if (methods.isNotEmpty) _buildMethodDropdown(methods),
              if (methods.isNotEmpty) const SizedBox(width: 8),
              // Create BOM button
              ElevatedButton.icon(
                onPressed: () =>
                    showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => _CreateBomDialog(
                        storeId: widget.storeId,
                        combinationId: widget.productId,
                        productName:
                            _product?['product_name']?.toString() ??
                            'This Product',
                        orderMethods: _orderMethods,
                      ),
                    ).then((created) {
                      if (created == true) _fetchManufacturing();
                    }),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('CREATE BOM'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // ── Body ──────────────────────────────────────────────────────
        if (_mfgLoading && _boms.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_mfgError != null && _boms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    _mfgError ?? 'Failed to load BOMs',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _fetchManufacturing,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (filteredBoms.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.precision_manufacturing_outlined,
                    size: 52,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _boms.isEmpty
                        ? 'No BOMs found'
                        : 'No BOMs for selected method',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final bom in filteredBoms) _buildBomCard(bom),

        const SizedBox(height: 20),
      ],
    );

    if (isWide) {
      return ListView(padding: EdgeInsets.zero, children: [content]);
    }
    return content;
  }

  Widget _buildMethodDropdown(List<Map<String, String>> methods) {
    return PopupMenuButton<String>(
      initialValue: _selectedOrderMethod,
      // onSelected is always called for non-null values — sentinel '_all_' is safe.
      onSelected: (value) => setState(() => _selectedOrderMethod = value),
      tooltip: 'Filter by order method',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: _kAllMethods,
          child: Row(
            children: [
              if (_selectedOrderMethod == _kAllMethods)
                const Icon(Icons.check, size: 16, color: Color(0xFF2563EB))
              else
                const SizedBox(width: 16),
              const SizedBox(width: 8),
              const Text('All Methods'),
            ],
          ),
        ),
        for (final m in methods)
          PopupMenuItem<String>(
            value: m['name'] ?? '',
            child: Row(
              children: [
                if (_selectedOrderMethod == m['name'])
                  const Icon(Icons.check, size: 16, color: Color(0xFF2563EB))
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(m['name'] ?? ''),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2563EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _selectedOrderMethod == _kAllMethods
                  ? 'All Methods'
                  : _selectedOrderMethod,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: Color(0xFF2563EB),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBomCard(Map<String, dynamic> bom) {
    final version = bom['version'] ?? 1;
    final methodName = bom['order_method_name']?.toString();
    final finishedItem = bom['finished_item']?.toString() ?? '—';
    final outputQty = bom['output_quantity']?.toString() ?? '0';
    final outputUnit = bom['output_unit']?.toString() ?? '';
    final components = (bom['components_count'] as num?)?.toInt() ?? 0;
    final isActive = bom['is_active'] == true;
    final bomId = bom['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Row 1: badge + version/method ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Row(
              children: [
                // Active badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF16A34A)
                        : Colors.grey[400],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Version & method — Flexible prevents overflow
                Flexible(
                  child: Text(
                    'V$version${methodName != null ? " • ${methodName.toUpperCase()}" : ""}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF475569),
                      letterSpacing: 0.4,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // ── Row 2: action buttons (right-aligned) ────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // GET REPORT
                OutlinedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => _FeasibilityReportDialog(
                      storeId: widget.storeId,
                      bomId: bomId,
                      outputQty: outputQty,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    textStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text('GET REPORT'),
                ),
                const SizedBox(width: 6),
                // MATERIALS
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => _BomDetailsDialog(bomId: bomId),
                  ),
                  icon: const Icon(Icons.remove_red_eye_outlined, size: 13),
                  label: const Text('MATERIALS'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    textStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // PRODUCE
                ElevatedButton.icon(
                  onPressed: () => showDialog<void>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        _ProduceDialog(bomId: bomId, storeId: widget.storeId),
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 13),
                  label: const Text('PRODUCE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Finished item name
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: Text(
              finishedItem,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // Output Qty + Components
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Output Qty card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF2563EB),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Output Qty',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          outputQty,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        if (outputUnit.isNotEmpty)
                          Text(
                            outputUnit,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Components card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Components',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$components',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
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
  }

  // ── Utility ───────────────────────────────────────────────────────────────
  String _breakEvery(String s, int n) {
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && i % n == 0) buf.write('\n');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// ── Grid item model ───────────────────────────────────────────────────────
class _GridItem {
  final String label;
  final String value;
  const _GridItem(this.label, this.value);
}

// ── Barcode painter ───────────────────────────────────────────────────────
class _BarcodePainter extends CustomPainter {
  final String data;
  _BarcodePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    if (data.isEmpty) return;

    // Use char codes to drive bar widths so the same string always
    // produces the same barcode-like graphic.
    final rng = math.Random(data.hashCode);
    double x = 0;
    const minW = 1.5;
    const maxW = 3.5;
    const gap = 1.0;

    while (x < size.width) {
      final barW = minW + rng.nextDouble() * (maxW - minW);
      final isBar = rng.nextBool();
      if (isBar) {
        canvas.drawRect(Rect.fromLTWH(x, 0, barW, size.height), paint);
      }
      x += barW + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodePainter old) => old.data != data;
}

// ── Feasibility Report Dialog ────────────────────────────────────────────────
class _FeasibilityReportDialog extends StatefulWidget {
  final String storeId;
  final String bomId;
  final String outputQty; // pre-fill quantity from BOM card

  const _FeasibilityReportDialog({
    required this.storeId,
    required this.bomId,
    required this.outputQty,
  });

  @override
  State<_FeasibilityReportDialog> createState() =>
      _FeasibilityReportDialogState();
}

class _FeasibilityReportDialogState extends State<_FeasibilityReportDialog> {
  // ── Input state ────────────────────────────────────────────────────────────
  final _qtyController = TextEditingController();
  List<Map<String, dynamic>> _godowns = [];
  String? _selectedGodownId; // null = All Godowns (Global)

  // ── Loading / result state ─────────────────────────────────────────────────
  bool _godownsLoading = true;
  bool _validating = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _qtyController.text = widget.outputQty.isNotEmpty ? widget.outputQty : '1';
    _loadGodowns();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _loadGodowns() async {
    try {
      final list = await StoreOwnerApiService.getGodowns(widget.storeId);
      if (mounted) {
        setState(() {
          _godowns = list;
          _godownsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _godownsLoading = false);
    }
  }

  Future<void> _generateReport() async {
    final qty = double.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      setState(() => _error = 'Enter a valid quantity greater than 0.');
      return;
    }
    setState(() {
      _validating = true;
      _error = null;
      _result = null;
    });
    try {
      final data = await StoreOwnerApiService.validateProductionPossibility(
        storeId: widget.storeId,
        bomId: widget.bomId,
        quantityToProduce: qty,
        godownId: _selectedGodownId,
      );
      final resp = data['response'];
      if (resp is Map) {
        setState(() {
          _result = Map<String, dynamic>.from(resp);
          _validating = false;
        });
      } else {
        setState(() {
          _error = 'Unexpected response format.';
          _validating = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _validating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
          maxWidth: 680,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Text(
                    'Feasibility Report',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16, indent: 20, endIndent: 20),

            // ── Scrollable body ───────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Inputs (stacked vertically for mobile safety) ────────
                    // Qty field
                    TextField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Quantity to Produce',
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Enter target output quantity.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 14),
                    // Godown dropdown
                    _godownsLoading
                        ? Container(
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : DropdownButtonFormField<String?>(
                            initialValue: _selectedGodownId,
                            isExpanded: true, // prevents overflow
                            decoration: InputDecoration(
                              labelText: 'Godown (Optional)',
                              labelStyle: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF2563EB),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2563EB),
                                  width: 1.5,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2563EB),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  'All Godowns (Global)',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              for (final g in _godowns)
                                DropdownMenuItem<String?>(
                                  value: g['id']?.toString(),
                                  child: Text(
                                    g['name']?.toString() ?? '—',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _selectedGodownId = v),
                          ),
                    const SizedBox(height: 4),
                    const Text(
                      'Filter by stock in specific godown.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),

                    const SizedBox(height: 16),

                    // ── Generate button ───────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _validating ? null : _generateReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: _validating
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('GENERATE REPORT'),
                      ),
                    ),

                    // ── Error ─────────────────────────────────────────────
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Color(0xFFDC2626),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Result ────────────────────────────────────────────
                    if (_result != null) ...[
                      const SizedBox(height: 16),
                      _buildResultCard(_result!),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Footer ────────────────────────────────────────────────────
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('CLOSE'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(Map<String, dynamic> result) {
    final feasible = result['feasible'] == true;
    final outputItem = result['output_item']?.toString() ?? '—';
    final outputQty = result['output_quantity']?.toString() ?? '—';
    final totalCost = result['total_cost_estimate']?.toString() ?? '—';
    final limit = result['production_limit'] as Map? ?? {};
    final maxQty = limit['max_producible_quantity']?.toString() ?? '—';
    final components = result['components'] as List<dynamic>? ?? [];
    final warnings = result['warnings'] as List<dynamic>? ?? [];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Output item + feasibility badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OUTPUT ITEM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      outputItem,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: feasible
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  feasible ? 'Possible to Produce' : 'Not Feasible',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Stats row ─────────────────────────────────────────────────
          Row(
            children: [
              _statBox('Estimate', '₹$totalCost'),
              const SizedBox(width: 8),
              _statBox('Requested', outputQty),
              const SizedBox(width: 8),
              _statBox('Max Possible', maxQty),
            ],
          ),

          // ── Warnings ──────────────────────────────────────────────────
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF9C3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE047)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WARNINGS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final w in warnings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: Color(0xFFCA8A04),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              w.toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF78350F),
                                height: 1.4,
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

          // ── Components breakdown ───────────────────────────────────────
          if (components.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'COMPONENTS BREAKDOWN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 8),
            for (final c in components)
              _buildComponentCard(Map<String, dynamic>.from(c)),
          ],
        ],
      ),
    );
  }

  Widget _statBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponentCard(Map<String, dynamic> c) {
    final name = c['raw_item']?.toString() ?? '—';
    final required = c['required_quantity']?.toString() ?? '—';
    final available = c['available_quantity']?.toString() ?? '—';
    final unit = c['unit']?.toString() ?? '';
    final cost = c['total_cost']?.toString() ?? '—';
    final sufficient = c['is_sufficient'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: sufficient ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sufficient
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  sufficient ? 'Sufficient' : 'Insufficient',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: sufficient
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _componentStat('Required', '$required $unit'),
              _componentStat('Available', '$available $unit'),
              _componentStat('Est. Cost', '₹$cost'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _componentStat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }
}

// ── BOM Details (Materials) Dialog ──────────────────────────────────────────
class _BomDetailsDialog extends StatefulWidget {
  final String bomId;
  const _BomDetailsDialog({required this.bomId});

  @override
  State<_BomDetailsDialog> createState() => _BomDetailsDialogState();
}

class _BomDetailsDialogState extends State<_BomDetailsDialog> {
  bool _loading = true;
  Map<String, dynamic>? _bom;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await StoreOwnerApiService.getBomDetails(
        bomId: widget.bomId,
      );
      final bom = (data['response'] as Map?)?.cast<String, dynamic>()['bom'];
      if (!mounted) return;
      if (bom is Map) {
        setState(() {
          _bom = Map<String, dynamic>.from(bom);
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Unexpected response format.';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 560,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  const Text(
                    'BOM Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16, indent: 20, endIndent: 20),

            // ── Body ──────────────────────────────────────────────────────
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFDC2626)),
                      ),
                    )
                  : _buildBody(_bom!),
            ),

            // ── Footer ────────────────────────────────────────────────────
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('CLOSE'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> bom) {
    final finishedItem = bom['finished_item']?.toString() ?? '—';
    final version = bom['version']?.toString() ?? '1';
    final outputQty = bom['output_quantity']?.toString() ?? '—';
    final outputUnit = bom['output_unit']?.toString() ?? '';
    final isActive = bom['is_active'] == true;
    final components = bom['components'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Finished item section ────────────────────────────────────
          const Text(
            'FINISHED ITEM',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            finishedItem,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 10),
          // Badges row
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              // Version
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Text(
                  'Version $version',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              // Output qty
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Output: $outputQty $outputUnit',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              // Active / Inactive
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFF16A34A)
                      : const Color(0xFF94A3B8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Raw materials section ────────────────────────────────────
          Text(
            'RAW MATERIALS (${components.length})',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 10),

          if (components.isEmpty)
            const Text(
              'No components defined for this BOM.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            )
          else
            for (final c in components)
              _componentRow(Map<String, dynamic>.from(c)),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _componentRow(Map<String, dynamic> c) {
    final name = c['raw_item']?.toString() ?? '—';
    final qty = c['quantity']?.toString() ?? '—';
    final unit = c['unit']?.toString() ?? '';
    final scrap =
        double.tryParse(c['scrap_percentage']?.toString() ?? '0') ?? 0.0;
    final isOptional = c['is_optional'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: name + Optional badge + scrap
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name row with optional badge
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (isOptional)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF2563EB),
                            width: 1.2,
                          ),
                        ),
                        child: const Text(
                          'Optional',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                  ],
                ),
                // Scrap % — only show if > 0
                if (scrap > 0) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Scrap: ${scrap.toStringAsFixed(2)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDC2626), // red-600
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Right: qty chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Text(
              '$qty $unit',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Execute Production Dialog ────────────────────────────────────────────────
class _ProduceDialog extends StatefulWidget {
  final String bomId;
  final String storeId;

  const _ProduceDialog({required this.bomId, required this.storeId});

  @override
  State<_ProduceDialog> createState() => _ProduceDialogState();
}

class _ProduceDialogState extends State<_ProduceDialog> {
  // ── Form state ─────────────────────────────────────────────────────────────
  final _qtyController = TextEditingController(text: '1');

  List<Map<String, dynamic>> _godowns = [];
  List<Map<String, dynamic>> _racks = [];

  String? _selectedGodownId;
  String? _selectedRackId;

  bool _godownsLoading = true;
  bool _racksLoading = false;
  bool _producing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGodowns();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _loadGodowns() async {
    try {
      final list = await StoreOwnerApiService.getGodowns(widget.storeId);
      if (!mounted) return;
      setState(() {
        _godowns = list;
        _godownsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _godownsLoading = false);
    }
  }

  Future<void> _loadRacks(String godownId) async {
    setState(() {
      _racksLoading = true;
      _racks = [];
      _selectedRackId = null;
    });
    try {
      final list = await StoreOwnerApiService.getRacksByGodown(
        storeId: widget.storeId,
        godownId: godownId,
      );
      if (!mounted) return;
      setState(() {
        _racks = list;
        _racksLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _racksLoading = false);
    }
  }

  Future<void> _produce() async {
    // validate
    final multiplier = int.tryParse(_qtyController.text.trim());
    if (multiplier == null || multiplier <= 0) {
      setState(() => _error = 'Enter a valid quantity multiplier (≥ 1).');
      return;
    }
    if (_selectedGodownId == null) {
      setState(() => _error = 'Please select a godown.');
      return;
    }

    setState(() {
      _producing = true;
      _error = null;
    });

    try {
      final now = DateTime.now();
      final date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final data = await StoreOwnerApiService.produceFromBom(
        bomId: widget.bomId,
        storeId: widget.storeId,
        godownId: _selectedGodownId!,
        quantityMultiplier: multiplier,
        date: date,
        rackId: _selectedRackId,
      );

      if (!mounted) return;
      setState(() => _producing = false);

      final status = data['status'] as int?;
      final response = data['response'] as Map?;
      final success = status == 200 || status == 201;
      final message =
          response?['message']?.toString() ??
          (success
              ? 'Production completed successfully.'
              : 'Production failed.');

      // Close dialog then show result
      Navigator.of(context).pop();
      _showResultDialog(success: success, message: message, response: response);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _producing = false;
        });
      }
    }
  }

  void _showResultDialog({
    required bool success,
    required String message,
    Map? response,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: success
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: success
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              success
                  ? 'Production Recorded Successfully'
                  : 'Production Failed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: success
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            if (success && response != null) ...[
              const SizedBox(height: 16),
              _resultInfo('Voucher', response['voucher_number']?.toString()),
              _resultInfo('Output Item', response['output_item']?.toString()),
              _resultInfo(
                'Output Qty',
                response['output_quantity']?.toString(),
              ),
              _resultInfo(
                'Components Used',
                response['components_consumed']?.toString(),
              ),
              _resultInfo(
                'Total Cost',
                response['total_cost'] != null
                    ? '₹${response['total_cost']}'
                    : null,
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'CLOSE',
              style: TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultInfo(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 520,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  const Text(
                    'Execute Production',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _producing
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16, indent: 20, endIndent: 20),

            // ── Scrollable body ───────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quantity Multiplier
                    TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantity Multiplier',
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Scales all component requirements proportionally.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 16),

                    // Godown dropdown
                    _godownsLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : DropdownButtonFormField<String?>(
                            initialValue: _selectedGodownId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Select Godown',
                              labelStyle: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2563EB),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                            hint: const Text('Select Godown'),
                            items: _godowns
                                .map(
                                  (g) => DropdownMenuItem<String?>(
                                    value: g['id']?.toString(),
                                    child: Text(
                                      g['name']?.toString() ?? '—',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedGodownId = v;
                                _racks = [];
                                _selectedRackId = null;
                              });
                              if (v != null) _loadRacks(v);
                            },
                          ),
                    const SizedBox(height: 4),
                    const Text(
                      'Where production output will be stored.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 16),

                    // Rack dropdown
                    _racksLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 14),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : DropdownButtonFormField<String?>(
                            initialValue: _selectedRackId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Select Rack',
                              labelStyle: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2563EB),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                            hint: Text(
                              _selectedGodownId == null
                                  ? 'Select a godown first'
                                  : _racks.isEmpty
                                  ? 'No racks available'
                                  : 'Select Rack (Optional)',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                            items: _racks
                                .map(
                                  (r) => DropdownMenuItem<String?>(
                                    value: r['id']?.toString(),
                                    child: Text(
                                      r['name']?.toString() ?? '—',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _selectedGodownId == null
                                ? null
                                : (v) => setState(() => _selectedRackId = v),
                          ),
                    const SizedBox(height: 4),
                    const Text(
                      'Select a godown first.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),

                    // Error
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Color(0xFFDC2626),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ── Footer ────────────────────────────────────────────────────
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _producing
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _producing ? null : _produce,
                    icon: _producing
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('PRODUCE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
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
}

// ── Create BOM Dialog ────────────────────────────────────────────────────────

/// Lightweight model for a single BOM component row in the form.
class _BomComponentRow {
  String? combinationId;
  String? combinationName;
  final TextEditingController qtyCtrl = TextEditingController(text: '1');
  String? unitId;
  final TextEditingController scrapCtrl = TextEditingController(text: '0');
  bool isOptional = false; // maps to is_optional in the API payload
  // search state
  String searchQuery = '';
  List<Map<String, dynamic>> searchResults = [];
  bool searching = false;

  _BomComponentRow();

  void dispose() {
    qtyCtrl.dispose();
    scrapCtrl.dispose();
  }
}

class _CreateBomDialog extends StatefulWidget {
  final String storeId;
  final String combinationId;
  final String productName;
  final List<Map<String, String>> orderMethods;

  const _CreateBomDialog({
    required this.storeId,
    required this.combinationId,
    required this.productName,
    required this.orderMethods,
  });

  @override
  State<_CreateBomDialog> createState() => _CreateBomDialogState();
}

class _CreateBomDialogState extends State<_CreateBomDialog> {
  // ── Form fields ────────────────────────────────────────────────────────────
  final _outputQtyCtrl = TextEditingController(text: '1');
  String? _selectedUnitId;
  String? _selectedOrderMethod; // null = universal recipe

  // ── Units ──────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _units = [];
  bool _unitsLoading = true;

  // ── Components ─────────────────────────────────────────────────────────────
  final List<_BomComponentRow> _components = [_BomComponentRow()];

  // ── Submission ─────────────────────────────────────────────────────────────
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUnits();
  }

  @override
  void dispose() {
    _outputQtyCtrl.dispose();
    for (final c in _components) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUnits() async {
    try {
      final list = await StoreOwnerApiService.getUnits(widget.storeId);
      if (!mounted) return;
      setState(() {
        _units = list;
        _unitsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _unitsLoading = false);
    }
  }

  Future<void> _searchCombinations(_BomComponentRow row, String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        row.searchQuery = '';
        row.searchResults = [];
        row.searching = false;
      });
      return;
    }
    setState(() {
      row.searchQuery = query;
      row.searching = true;
    });
    try {
      final data = await StoreOwnerApiService.searchProductCombinations(
        storeId: widget.storeId,
        query: query.trim(),
      );
      if (!mounted) return;
      final results = List<Map<String, dynamic>>.from(
        data['response'] as List? ?? [],
      );
      setState(() {
        row.searchResults = results;
        row.searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => row.searching = false);
    }
  }

  Future<void> _save() async {
    // Validate output qty
    final outputQty = double.tryParse(_outputQtyCtrl.text.trim());
    if (outputQty == null || outputQty <= 0) {
      setState(() => _error = 'Enter a valid output quantity.');
      return;
    }
    if (_selectedUnitId == null) {
      setState(() => _error = 'Select an output unit.');
      return;
    }
    // Validate components
    for (int i = 0; i < _components.length; i++) {
      final c = _components[i];
      if (c.combinationId == null) {
        setState(
          () => _error = 'Select a raw material for Component #${i + 1}.',
        );
        return;
      }
      final qty = double.tryParse(c.qtyCtrl.text.trim());
      if (qty == null || qty <= 0) {
        setState(
          () => _error = 'Enter a valid quantity for Component #${i + 1}.',
        );
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final componentPayload = _components.map((c) {
        final map = <String, dynamic>{
          'raw_combination_id': c.combinationId!,
          'quantity': double.parse(c.qtyCtrl.text.trim()),
          'scrap_percentage': double.tryParse(c.scrapCtrl.text.trim()) ?? 0.0,
          'is_optional': c.isOptional,
        };
        if (c.unitId != null) map['unit_id'] = c.unitId!;
        return map;
      }).toList();

      final data = await StoreOwnerApiService.saveBom(
        storeId: widget.storeId,
        finishedCombinationId: widget.combinationId,
        outputQuantity: outputQty,
        outputUnitId: _selectedUnitId!,
        orderMethodId: _selectedOrderMethod,
        components: componentPayload,
      );

      if (!mounted) return;

      final status = data['status'] as int?;
      final success = status == 200 || status == 201;

      if (success) {
        setState(() => _saving = false);
        final resp = data['response'];
        final msg =
            (resp is Map ? resp['message'] : null)?.toString() ??
            'BOM created successfully.';
        _showResult(success: true, message: msg);
      } else {
        // Stay in dialog — show exact server error inline
        final resp = data['response'];
        String errMsg;
        if (resp is Map && resp['message'] != null) {
          errMsg = resp['message'].toString();
        } else if (data.isEmpty) {
          errMsg = 'No response from server. Please try again.';
        } else {
          errMsg = 'Failed to create BOM (status $status).';
        }
        setState(() {
          _saving = false;
          _error = errMsg;
        });
      }
    } catch (e) {
      if (mounted) {
        // Strip generic wrapper prefix added by saveBom()
        final raw = e.toString();
        final clean = raw.startsWith('Exception: Failed to save BOM: ')
            ? raw.replaceFirst('Exception: Failed to save BOM: ', '')
            : raw.replaceFirst('Exception: ', '');
        setState(() {
          _error = clean;
          _saving = false;
        });
      }
    }
  }

  void _showResult({required bool success, required String message}) {
    Navigator.of(context).pop(success); // pop dialog, signal refresh
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: success
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                color: success
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              success ? 'BOM Created!' : 'Failed',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: success
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
          maxWidth: 700,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Create New Bill of Materials',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: IconButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16, indent: 20, endIndent: 20),

            // ── Scrollable body ────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── FINISHED PRODUCT ──────────────────────────
                    _sectionLabel('FINISHED PRODUCT'),
                    TextField(
                      readOnly: true,
                      controller: TextEditingController(
                        text: widget.productName,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Finished Product Combination',
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Combination is autofilled and cannot be changed.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 18),

                    // ── OUTPUT DETAILS ────────────────────────────
                    _sectionLabel('OUTPUT DETAILS'),
                    // Row 1: Output Qty + Unit side-by-side
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Output qty
                        SizedBox(
                          width: 110,
                          child: TextField(
                            controller: _outputQtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Output Qty',
                              labelStyle: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF2563EB),
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Unit dropdown
                        Expanded(
                          child: _unitsLoading
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : DropdownButtonFormField<String?>(
                                  initialValue: _selectedUnitId,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'Select unit',
                                    labelStyle: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF2563EB),
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                  ),
                                  items: _units
                                      .map(
                                        (u) => DropdownMenuItem<String?>(
                                          value: u['id']?.toString(),
                                          child: Text(
                                            '${u['code'] ?? ''} — ${u['description'] ?? ''}',
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedUnitId = v),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Row 2: Universal Recipe full-width
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedOrderMethod,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Universal Recipe (optional)',
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'Universal Recipe',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        for (final m in widget.orderMethods)
                          DropdownMenuItem<String?>(
                            value: m['id'],
                            child: Text(
                              m['name'] ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedOrderMethod = v),
                    ),
                    const SizedBox(height: 20),

                    // ── RAW MATERIAL COMPONENTS ───────────────────
                    _sectionLabel('RAW MATERIAL COMPONENTS'),
                    for (int i = 0; i < _components.length; i++)
                      _buildComponentCard(i),

                    // ADD COMPONENT
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _components.add(_BomComponentRow())),
                      icon: const Icon(
                        Icons.add,
                        size: 16,
                        color: Color(0xFF2563EB),
                      ),
                      label: const Text(
                        'ADD COMPONENT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),

                    // Error
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Color(0xFFDC2626),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color.fromRGBO(153, 27, 27, 1),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),

            // ── Footer ────────────────────────────────────────────
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.shopping_cart_outlined, size: 16),
                    label: const Text('SAVE BOM'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
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

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildComponentCard(int index) {
    final row = _components[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + delete
          Row(
            children: [
              Text(
                'Component #${index + 1}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              if (_components.length > 1)
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                  onPressed: () => setState(() {
                    row.dispose();
                    _components.removeAt(index);
                  }),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Raw Material search (full-width)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (row.combinationId != null)
                GestureDetector(
                  onTap: () => setState(() {
                    row.combinationId = null;
                    row.combinationName = null;
                    row.searchResults = [];
                    row.searchQuery = '';
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF2563EB),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.combinationName ?? '—',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.close,
                          size: 14,
                          color: Color(0xFF2563EB),
                        ),
                      ],
                    ),
                  ),
                )
              else
                _SearchField(
                  hint: 'Raw Material Combination',
                  searching: row.searching,
                  results: row.searchResults,
                  onChanged: (q) => _searchCombinations(row, q),
                  onSelected: (item) => setState(() {
                    row.combinationId = item['id']?.toString();
                    row.combinationName = item['product_name']?.toString();
                    row.searchResults = [];
                    row.searchQuery = '';
                  }),
                ),
              const SizedBox(height: 4),
              const Text(
                'The ingredient/input product combination.',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Qty + Unit + Scrap % in a compact row below
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Qty
              Expanded(
                flex: 2,
                child: TextField(
                  controller: row.qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Qty',
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF2563EB),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Unit (optional)
              Expanded(
                flex: 3,
                child: _unitsLoading
                    ? const SizedBox(height: 52)
                    : DropdownButtonFormField<String?>(
                        initialValue: row.unitId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Unit (optional)',
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF2563EB),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 14,
                          ),
                        ),
                        hint: const Text(
                          'Auto',
                          style: TextStyle(fontSize: 12),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'Auto',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          for (final u in _units)
                            DropdownMenuItem<String?>(
                              value: u['id']?.toString(),
                              child: Text(
                                u['code']?.toString() ?? '—',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => row.unitId = v),
                      ),
              ),
              const SizedBox(width: 8),
              // Scrap %
              Expanded(
                flex: 2,
                child: TextField(
                  controller: row.scrapCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Scrap %',
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFF2563EB),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Auto from inventory batch if blank',
            style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 8),
          // Optional Component checkbox
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => row.isOptional = !row.isOptional),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: row.isOptional,
                      onChanged: (v) =>
                          setState(() => row.isOptional = v ?? false),
                      activeColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: const BorderSide(
                        color: Color(0xFF94A3B8),
                        width: 1.5,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Optional component',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569),
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
}

/// A search-as-you-type field that shows a results overlay.
class _SearchField extends StatefulWidget {
  final String hint;
  final bool searching;
  final List<Map<String, dynamic>> results;
  final void Function(String) onChanged;
  final void Function(Map<String, dynamic>) onSelected;

  const _SearchField({
    required this.hint,
    required this.searching,
    required this.results,
    required this.onChanged,
    required this.onSelected,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            labelText: widget.hint,
            labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            suffixIcon: widget.searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.arrow_drop_down, color: Color(0xFF94A3B8)),
          ),
        ),
        if (widget.results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: widget.results.length,
              itemBuilder: (_, i) {
                final item = widget.results[i];
                final name = item['product_name']?.toString() ?? '—';
                return InkWell(
                  onTap: () {
                    _ctrl.text = name;
                    widget.onSelected(item);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
