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
  List<String> _orderMethods = []; // distinct order methods from /orders/ API
  bool _mfgLoading = false;
  bool _mfgFetched = false;
  String? _mfgError;
  static const _kAllMethods = '__all__';
  String _selectedOrderMethod = _kAllMethods; // sentinel = All Methods

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Listen to tab changes so setState re-reads _product fresh each time.
    _tabController.addListener(_onTabChanged);
    if (widget.initialData != null) {
      _product = widget.initialData;
      _isLoading = false;
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
        StoreOwnerApiService.getOrdersByStatus(
          storeId: widget.storeId,
          status: 'order_placed',
        ),
      ]);

      if (!mounted) return;

      // Handle both response shapes:
      //   { "response": { "boms": [...] } }  — nested
      //   { "response": [ ... ] }             — flat list
      final bomResponse = results[0]['response'];
      final List<dynamic> rawBoms;
      if (bomResponse is List) {
        rawBoms = bomResponse;
      } else if (bomResponse is Map) {
        rawBoms = (bomResponse['boms'] as List<dynamic>?) ?? [];
      } else {
        rawBoms = [];
      }

      // Extract unique order methods from orders response.
      final rawOrders = results[1]['response'] as List<dynamic>? ?? [];
      final methods = <String>{};
      for (final o in rawOrders) {
        final m = (o as Map<String, dynamic>)['order_method_name']?.toString();
        if (m != null && m.isNotEmpty) methods.add(m);
      }

      setState(() {
        _mfgLoading = false;
        _mfgFetched = true;
        _boms = rawBoms.map((e) => Map<String, dynamic>.from(e)).toList();
        _orderMethods = methods.toList();
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

      final ok = response['statusCode'] == 200 &&
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
      }
    } catch (e) {
      if (!mounted) return;
      _product![field] = previous;
      setState(() {});
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
      case 'is_accessible_online': return 'Online Access';
      case 'is_accessible_pos':    return 'POS Access';
      case 'auto_produce':         return 'Auto Produce';
      default:                     return field;
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
      final dt =
          DateTime.fromMillisecondsSinceEpoch((ts as num).toInt() * 1000);
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
      v == null || v.toString().toLowerCase() == 'undefined' || v.toString().isEmpty;

  List<Map<String, dynamic>> get _inventory {
    final inv = _product?['inventory'];
    if (inv == null || inv is! List) return [];
    return List<Map<String, dynamic>>.from(inv);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _isLoading && _product == null
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _product == null
                    ? _buildErrorState()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    final p = _product;
    final name = p?['product_name'] ?? 'Product Detail';

    final parentCat = _cap(p?['parent_category'] ?? '');
    final childCat = _cap(p?['child_category'] ?? '');
    final productType = _cap(p?['product_type'] ?? '');

    final chips = <String>[
      if (parentCat.isNotEmpty && !_isUndefined(parentCat)) parentCat,
      if (childCat.isNotEmpty && !_isUndefined(childCat)) childCat,
      if (productType.isNotEmpty && !_isUndefined(productType)) productType,
    ];


    return Container(
      width: double.infinity,
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back + Title row
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 22, color: Color(0xFF334155)),
                    onPressed: () => Navigator.of(context).maybePop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Category chips
            if (chips.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.only(left: 44, bottom: 10, right: 12),
                child: Wrap(
                  spacing: 6,
                  children: chips
                      .map((c) => _chip(c))
                      .toList(),
                ),
              ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF475569)),
      ),
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
          Text(_error ?? 'Something went wrong',
              style: TextStyle(color: Colors.grey[600])),
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

  // ── Content ───────────────────────────────────────────────────────────────
  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 680;
        if (isWide) {
          // Wide: Row inside Scaffold Expanded — finite height available.
          // Expanded → TabBarView works perfectly here.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 320,
                child: _buildLeftPanel(),
              ),
              const VerticalDivider(
                  width: 1, thickness: 1, color: Color(0xFFE2E8F0)),
              Expanded(child: _buildRightPanelWide()),
            ],
          );
        }
        // Mobile: everything in one big CustomScrollView.
        // TabBarView is NOT used — content is rendered inline.
        return _buildMobileScrollView();
      },
    );
  }

  // ── Mobile: single scrollable column ─────────────────────────────────────
  Widget _buildMobileScrollView() {
    // Read ALL data fresh here — this method is called by build() every
    // time setState fires, so _product is always current.
    final p = _product!;
    final imgUrl = p['img_url'] as String?;
    final hasImg = imgUrl != null && imgUrl.isNotEmpty;
    final totalBought = (p['total_purchased'] as num?)?.toDouble() ?? 0.0;
    final totalSold   = (p['total_sold']      as num?)?.toDouble() ?? 0.0;
    final totalLeft   = (p['total_left']      as num?)?.toDouble() ?? 0.0;

    // No AnimatedBuilder here — plain CustomScrollView.
    // Tab changes and toggle changes both call setState() on the parent,
    // which re-calls build() -> _buildMobileScrollView() with fresh data.
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                if (hasImg)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 1.8,
                      child: CustomCachedNetworkImage(
                        imgUrl: imgUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  )
                else
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(Icons.inventory_2_outlined,
                          size: 60, color: Colors.grey[400]),
                    ),
                  ),
                const SizedBox(height: 14),

                // Quick stats
                Row(
                  children: [
                    Expanded(
                        child: _quickStatCard(
                            label: 'Total Bought',
                            value: totalBought.toStringAsFixed(0),
                            color: const Color(0xFF2563EB))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _quickStatCard(
                            label: 'Total Sold',
                            value: totalSold.toStringAsFixed(0),
                            color: Colors.orange[700]!)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _quickStatCard(
                            label: 'In Stock',
                            value: totalLeft.toStringAsFixed(0),
                            color: const Color(0xFF16A34A))),
                  ],
                ),
                const SizedBox(height: 16),

                // Product details
                _sectionHeader('PRODUCT DETAILS'),
                const SizedBox(height: 8),
                _detailCard([
                  _detailRow('Category',
                      [_cap(p['parent_category'] ?? ''),
                       _cap(p['child_category']  ?? '')]
                          .where((s) => !_isUndefined(s))
                          .join(' › ')),
                  _detailRow('Product Type', _cap(p['product_type'] ?? '')),
                  _detailRow('Food Class',   _cap(p['food_class']   ?? '')),
                  _detailRow('Status',       _cap(p['status']       ?? '')),
                  _detailRow('Rating',
                      (p['rating_count'] as num?) == 0
                          ? 'No ratings'
                          : '${p['average_rating']} (${p['rating_count']})'),
                  _detailRow('Sale Price', _fmtMoney(p['sale_price'])),
                  _detailRow('MRP',        _fmtMoney(p['mrp'])),
                  _detailRow('Cost Price', _fmtMoney(p['cost_price'])),
                ]),
                const SizedBox(height: 16),

                // Access toggles — reads p fresh so setState reflects instantly
                _sectionHeader('ACCESS & AUTOMATION'),
                const SizedBox(height: 8),
                _accessCard(p),
                const SizedBox(height: 20),

                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 8),

                // Tab selector
                _buildMobileTabSelector(),
                const SizedBox(height: 16),

                // Tab content
                _buildMobileTabContent(),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTabSelector() {
    const tabs = ['Inventory', 'Reviews', 'Manufacturing'];
    return Row(
      children: List.generate(tabs.length, (i) {
        final selected = _tabController.index == i;
        return GestureDetector(
          onTap: () => _tabController.animateTo(i),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF2563EB)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? const Color(0xFF2563EB)
                    : Colors.grey[300]!,
              ),
            ),
            child: Text(
              tabs[i],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    selected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
        );
      }),
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
          Icons.inventory_2_outlined, 'No inventory records');
    }
    return Column(
      children: [
        for (int i = 0; i < inv.length; i++)
          _buildInventoryCard(inv[i], i),
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
            Text(msg,
                style:
                    TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      ),
    );
  }


  // ── LEFT PANEL (wide only) ────────────────────────────────────────────────
  Widget _buildLeftPanel() {
    final p = _product!;
    final imgUrl = p['img_url'] as String?;
    final hasImg = imgUrl != null && imgUrl.isNotEmpty;
    final totalBought = (p['total_purchased'] as num?)?.toDouble() ?? 0.0;
    final totalSold   = (p['total_sold']      as num?)?.toDouble() ?? 0.0;
    final totalLeft   = (p['total_left']      as num?)?.toDouble() ?? 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (hasImg)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 1.4,
                child: CustomCachedNetworkImage(
                  imgUrl: imgUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Icon(Icons.inventory_2_outlined,
                    size: 60, color: Colors.grey[400]),
              ),
            ),
          const SizedBox(height: 14),

          // Quick stats
          Row(
            children: [
              Expanded(
                child: _quickStatCard(
                  label: 'Total Bought',
                  value: totalBought.toStringAsFixed(0),
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _quickStatCard(
                  label: 'Total Sold',
                  value: totalSold.toStringAsFixed(0),
                  color: Colors.orange[700]!,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _quickStatCard(
                  label: 'In Stock',
                  value: totalLeft.toStringAsFixed(0),
                  color: const Color(0xFF16A34A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _sectionHeader('PRODUCT DETAILS'),
          const SizedBox(height: 8),
          _detailCard([
            _detailRow('Category',
                [_cap(p['parent_category'] ?? ''), _cap(p['child_category'] ?? '')]
                    .where((s) => !_isUndefined(s))
                    .join(' › ')),
            _detailRow('Product Type', _cap(p['product_type'] ?? '')),
            _detailRow('Food Class',   _cap(p['food_class']   ?? '')),
            _detailRow('Status',       _cap(p['status']       ?? '')),
            _detailRow('Rating',
                (p['rating_count'] as num?) == 0
                    ? 'No ratings'
                    : '${p['average_rating']} (${p['rating_count']})'),
            _detailRow('Sale Price', _fmtMoney(p['sale_price'])),
            _detailRow('MRP',        _fmtMoney(p['mrp'])),
            _detailRow('Cost Price', _fmtMoney(p['cost_price'])),
          ]),
          const SizedBox(height: 16),

          _sectionHeader('ACCESS & AUTOMATION'),
          const SizedBox(height: 8),
          _accessCard(p),
        ],
      ),
    );
  }

  Widget _quickStatCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF94A3B8),
        letterSpacing: 1.3,
      ),
    );
  }

  Widget _detailCard(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1)
              const Divider(
                  height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _accessCard(Map<String, dynamic> p) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _accessRow(
            'Online Access',
            null,
            p['is_accessible_online'] == true,
            onChanged: (v) => _updateToggle('is_accessible_online', v),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          _accessRow(
            'POS Access',
            null,
            p['is_accessible_pos'] == true,
            onChanged: (v) => _updateToggle('is_accessible_pos', v),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          _accessRow(
            'Auto Produce',
            'Automatically trigger BOM production when\nstock is depleted',
            p['auto_produce'] == true,
            onChanged: (v) => _updateToggle('auto_produce', v),
          ),
        ],
      ),
    );
  }

  Widget _accessRow(
    String title,
    String? subtitle,
    bool value, {
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            thumbColor: value
                ? WidgetStateProperty.all(Colors.white)
                : WidgetStateProperty.all(Colors.grey[400]),
            trackColor: value
                ? WidgetStateProperty.all(const Color.fromARGB(255, 44, 150, 83))
                : WidgetStateProperty.all(Colors.grey[300]),
          ),
        ],
      ),
    );
  }

  // ── RIGHT PANEL — Wide only (has finite height from Scaffold→Expanded→Row)
  Widget _buildRightPanelWide() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500),
            tabs: const [
              Tab(text: 'Inventory'),
              Tab(text: 'Reviews'),
              Tab(text: 'Manufacturing'),
            ],
          ),
        ),
        // TabBarView needs finite height — provided by Expanded below,
        // which gets its height from the parent Row → Scaffold Expanded.
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildInventoryListWide(),
              _buildReviewsTab(isWide: true),
              _buildManufacturingTab(isWide: true),
            ],
          ),
        ),
      ],
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
            Icon(Icons.inventory_2_outlined,
                size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text('No inventory records',
                style:
                    TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: inv.length,
      itemBuilder: (context, index) =>
          _buildInventoryCard(inv[index], index),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> inv, int index) {
    final barcode = inv['uni_barcode']?.toString() ?? '';
    final originalBarcode = inv['original_barcode']?.toString() ?? '';
    final purchased = _fmtNum(inv['total_stocks_purchased']);
    final sold = _fmtNum(inv['total_stocks_sold']);
    final left = (inv['total_stocks_left'] as num?)?.toDouble() ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          // ── Barcode section ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Barcode graphic
                      SizedBox(
                        height: 48,
                        child: CustomPaint(
                          painter: _BarcodePainter(barcode),
                          child: Container(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Barcode text (split in rows of 24)
                      Text(
                        _breakEvery(barcode, 24),
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: Color(0xFF475569),
                          height: 1.4,
                        ),
                      ),
                      if (originalBarcode.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Original: $originalBarcode',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Print button
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Print barcode — coming soon')),
                    );
                  },
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text('PRINT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Purchased / Sold / Left ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                    child: _stockCard('Purchased', purchased,
                        const Color(0xFF2563EB))),
                const SizedBox(width: 8),
                Expanded(
                    child: _stockCard(
                        'Sold', sold, Colors.orange[700]!)),
                const SizedBox(width: 8),
                Expanded(
                    child: _stockCard(
                        'Left',
                        left.toStringAsFixed(0),
                        left > 0
                            ? const Color(0xFF16A34A)
                            : Colors.grey[600]!)),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Financial grid ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFinancialGrid(inv),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _stockCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialGrid(Map<String, dynamic> inv) {
    final rows = [
      _GridItem('Cost (incl. tax)',
          _fmtMoney(inv['cost_amount_including_tax'])),
      _GridItem('Cost (excl. tax)',
          _fmtMoney(inv['cost_amount_excluding_tax'])),
      _GridItem('Sale (incl. tax)',
          _fmtMoney(inv['selling_amount_including_tax'])),
      _GridItem('MRP', _fmtMoney(inv['mrp'])),
      _GridItem('CGST', _pct(inv['cgst_percent'])),
      _GridItem('SGST', _pct(inv['sgst_percent'])),
      _GridItem('IGST', _pct(inv['igst_percent'])),
      _GridItem('HSN Code', inv['hsn_code']?.toString() ?? '—'),
      _GridItem('Purchased On', _fmtTs(inv['purchase_timestamp'])),
      _GridItem('Expires', _fmtTs(inv['expiry_timestamp'])),
      _GridItem('State of Purchase',
          _cap(inv['state_code_of_purchase'] ?? '')),
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
              const Icon(Icons.star_rounded,
                  color: Color(0xFFF59E0B), size: 20),
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
                      horizontal: 10, vertical: 3),
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
                  Icon(Icons.error_outline,
                      size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text(
                    _reviewsError ?? 'Failed to load reviews',
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 13),
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
                  Icon(Icons.rate_review_outlined,
                      size: 52, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'No reviews yet',
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Be the first to review this product!',
                    style: TextStyle(
                        color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          ...[
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
      return ListView(
        padding: EdgeInsets.zero,
        children: [content],
      );
    }
    return content;
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = review['comment']?.toString() ?? '';
    final author = (review['customer_name']?.toString().isNotEmpty == true
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
                backgroundColor:
                    const Color(0xFF2563EB).withValues(alpha: 0.12),
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
                    color: filled
                        ? const Color(0xFFF59E0B)
                        : Colors.grey[300],
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
            .where((b) =>
                b['order_method_name']?.toString() == _selectedOrderMethod)
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
                    _showBar('Create BOM — coming soon', const Color(0xFF2563EB)),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('CREATE BOM'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
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
                    style:
                        TextStyle(color: Colors.grey[600], fontSize: 13),
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
                  Icon(Icons.precision_manufacturing_outlined,
                      size: 52, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    _boms.isEmpty ? 'No BOMs found' : 'No BOMs for selected method',
                    style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
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

  Widget _buildMethodDropdown(List<String> methods) {
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
                const Icon(Icons.check,
                    size: 16, color: Color(0xFF2563EB))
              else
                const SizedBox(width: 16),
              const SizedBox(width: 8),
              const Text('All Methods'),
            ],
          ),
        ),
        for (final m in methods)
          PopupMenuItem<String>(
            value: m,
            child: Row(
              children: [
                if (_selectedOrderMethod == m)
                  const Icon(Icons.check,
                      size: 16, color: Color(0xFF2563EB))
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(m),
              ],
            ),
          ),
      ],
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
            const Icon(Icons.arrow_drop_down,
                size: 18, color: Color(0xFF2563EB)),
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
                      horizontal: 8, vertical: 3),
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
                        fontSize: 10, fontWeight: FontWeight.w700),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
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
                        fontSize: 10, fontWeight: FontWeight.w700),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(width: 6),
                // PRODUCE
                ElevatedButton.icon(
                  onPressed: () => _showBar(
                      'Produce BOM $bomId — coming soon',
                      const Color(0xFF16A34A)),
                  icon: const Icon(Icons.settings_outlined, size: 13),
                  label: const Text('PRODUCE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
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
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Output Qty card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF2563EB), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Output Qty',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB)
                                .withValues(alpha: 0.8),
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
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFE2E8F0)),
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
                          decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Quantity to Produce',
                        labelStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFF64748B)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFF2563EB), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
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
                                  color: const Color(0xFF2563EB)),
                            ),
                            child: const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
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
                                    color: Color(0xFF2563EB), width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Color(0xFF2563EB), width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('All Godowns (Global)',
                                    overflow: TextOverflow.ellipsis),
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
                              fontSize: 14, fontWeight: FontWeight.w700,
                              letterSpacing: 0.8),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: _validating
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
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
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF991B1B)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          letterSpacing: 0.6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
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
                    horizontal: 12, vertical: 6),
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
                          const Icon(Icons.warning_amber_rounded,
                              size: 14, color: Color(0xFFCA8A04)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              w.toString(),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF78350F),
                                  height: 1.4),
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
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
              ),
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
          color: sufficient
              ? const Color(0xFFE2E8F0)
              : const Color(0xFFFCA5A5),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
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
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF94A3B8))),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B))),
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
      final data =
          await StoreOwnerApiService.getBomDetails(bomId: widget.bomId);
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
                        foregroundColor: const Color(0xFF64748B)),
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
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: Color(0xFFDC2626))),
                        )
                      : _buildBody(_bom!),
            ),

            // ── Footer ────────────────────────────────────────────────────
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                          letterSpacing: 0.6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
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
                    horizontal: 12, vertical: 5),
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
                    horizontal: 12, vertical: 5),
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
                    horizontal: 12, vertical: 5),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
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
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
