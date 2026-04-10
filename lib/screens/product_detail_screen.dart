import 'dart:math' as math;
import 'package:exanor/components/custom_cached_network_image.dart';
import 'package:exanor/services/api_service.dart';
import 'package:flutter/material.dart';
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
        return _buildPlaceholderInline(
            Icons.star_outline_rounded, 'Reviews coming soon');
      case 2:
        return _buildPlaceholderInline(
            Icons.precision_manufacturing_outlined,
            'Manufacturing details coming soon');
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
              _buildPlaceholderTab(
                  Icons.star_outline_rounded, 'Reviews coming soon'),
              _buildPlaceholderTab(
                  Icons.precision_manufacturing_outlined,
                  'Manufacturing details coming soon'),
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

  // ── Placeholder tabs ──────────────────────────────────────────────────────
  Widget _buildPlaceholderTab(IconData icon, String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            msg,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
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
