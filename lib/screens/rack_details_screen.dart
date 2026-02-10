import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:exanor/components/translation_widget.dart';
import 'dart:math' as math;

class RackDetailsScreen extends StatefulWidget {
  final String storeId;
  final String rackId;
  final String godownId;
  final String rackName;

  const RackDetailsScreen({
    super.key,
    required this.storeId,
    required this.rackId,
    required this.godownId,
    required this.rackName,
  });

  @override
  State<RackDetailsScreen> createState() => _RackDetailsScreenState();
}

class _RackDetailsScreenState extends State<RackDetailsScreen> {
  bool _isLoading = true;
  List<dynamic> _products = [];
  String? _errorMessage;
  int _currentPage = 1;
  bool _isSearchExpanded = false;
  int _totalCount = 0;
  final TextEditingController _searchController = TextEditingController();

  // Colors
  final Color _bg = const Color(0xFFF1F5F9);
  final Color _primary = const Color(0xFF2563EB);
  final Color _textMain = const Color(0xFF1E293B);
  final Color _textSub = const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await StoreOwnerApiService.getProductInventory(
        widget.storeId,
        widget.rackId,
        widget.godownId,
        page: _currentPage,
      );

      if (data.containsKey('response')) {
        setState(() {
          _products = data['response'];
          _totalCount = data['pagination']['total_count'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "Failed to load products";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '₹0.00';
    double value = double.tryParse(amount.toString()) ?? 0.0;
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 2,
    ).format(value);
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is int) {
      return DateFormat(
        'dd MMM yyyy',
      ).format(DateTime.fromMillisecondsSinceEpoch(timestamp * 1000));
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(
          children: [
            _buildExpandedBanner(),

            // Search Bar (Conditional)
            if (_isSearchExpanded)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search items...',
                    prefixIcon: Icon(Icons.search, color: _primary),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),

            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _errorMessage != null
                              ? _buildErrorState()
                              : _products.isEmpty
                              ? _buildEmptyState()
                              : ListView.separated(
                                  padding: const EdgeInsets.all(24),
                                  itemCount: _products.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    return _buildProductCard(_products[index]);
                                  },
                                ),
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
    );
  }

  Widget _buildExpandedBanner() {
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
                  Icons.inventory_2_outlined,
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
                24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.blueGrey.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.only(right: 2),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.black87,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TranslatedText(
                              widget.rackName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
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
                              child: Text(
                                "$_totalCount ITEMS",
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.blue,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Search Button
                      SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TranslatedText(
                              'SEARCH',
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
                              onTap: () {
                                setState(() {
                                  _isSearchExpanded = !_isSearchExpanded;
                                  if (!_isSearchExpanded) {
                                    _searchController.clear();
                                  }
                                });
                              },
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
                                  _isSearchExpanded
                                      ? Icons.close
                                      : Icons.search_rounded,
                                  size: 24,
                                  color: Colors.blueGrey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPremiumChip(Icons.sort_rounded, "Sort"),
                        const SizedBox(width: 8),
                        _buildPremiumChip(Icons.filter_list_rounded, "Filter"),
                        const SizedBox(width: 8),
                        Container(
                          height: 20,
                          width: 1,
                          color: Colors.black.withOpacity(0.1),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChoice("7d"),
                        const SizedBox(width: 8),
                        _buildFilterChoice("Available", isActive: true),
                        const SizedBox(width: 8),
                        _buildFilterChoice("Low Stock"),
                      ],
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

  Widget _buildProductCard(dynamic item) {
    final productData = item['product_combination_data'] ?? {};

    final expiryTimestamp = item['expiry_timestamp'];

    // Safety
    double stocksLeft =
        double.tryParse(item['total_stocks_left']?.toString() ?? '0') ?? 0;

    return InkWell(
      onTap: () => _showEditProductSheet(item),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top Row: Image & Key Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      productData['img_url'] ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.image_not_supported_rounded,
                        color: _textSub.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Title & Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productData['product_name'] ?? 'Unknown Item',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: _textMain,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildStatusBadge(
                            "Qty: ${stocksLeft.toStringAsFixed(0)}",
                            stocksLeft > 0 ? Colors.green : Colors.red,
                          ),
                          if (expiryTimestamp != null)
                            _buildStatusBadge(
                              "Exp: ${_formatDate(expiryTimestamp)}",
                              Colors.orange,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Price Right
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(item['selling_amount_excluding_tax']),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "MRP: ${_formatCurrency(item['mrp'])}",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: _textSub,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Bottom Stats Grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem(
                    "Purchased",
                    item['total_stocks_purchased']?.toString() ?? '0',
                  ),
                  Container(width: 1, height: 24, color: Colors.grey[200]),
                  _buildStatItem(
                    "Sold",
                    item['total_stocks_sold']?.toString() ?? '0',
                  ),
                  Container(width: 1, height: 24, color: Colors.grey[200]),
                  _buildStatItem(
                    "Returned",
                    item['total_stocks_returned']?.toString() ?? '0',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _textMain,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _textSub,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _textMain),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _textMain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChoice(String label, {bool isActive = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? _primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isActive ? _primary.withOpacity(0.2) : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isActive ? _primary : _textSub,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "Rack is Empty",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textSub,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 60, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? "Error",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textSub,
            ),
          ),
        ],
      ),
    );
  }

  // --- EDIT SHEET (Revamped & Responsive) ---

  void _showEditProductSheet(Map<String, dynamic> item) {
    final productData = item['product_combination_data'] ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Data Parsing
            final stockLeft =
                double.tryParse(item['total_stocks_left']?.toString() ?? '0') ??
                0;
            final purchaseTimestamp = item['purchase_timestamp'];
            final expiryTimestamp = item['expiry_timestamp'];
            final createdTimestamp =
                item['created_timestamp'] ?? purchaseTimestamp;

            // Access Control
            bool isWebEnabled = item['is_accessible_online'] ?? false;
            bool isPosEnabled = item['is_accessible_pos'] ?? false;

            return DraggableScrollableSheet(
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, controller) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    // Check if tablet/large screen
                    bool isTablet = constraints.maxWidth > 600;

                    return Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9), // Slate 100
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Header (Title + Close)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Edit Product",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                    Text(
                                      "${productData['product_name']} - ${productData['variation_value'] ?? ''}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.close,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Scrollable Form Content
                          Expanded(
                            child: ListView(
                              controller: controller,
                              padding: const EdgeInsets.all(20),
                              children: [
                                // Main Product Card
                                _buildMainProductCard(
                                  productData,
                                  item,
                                  stockLeft,
                                ),
                                const SizedBox(height: 20),

                                if (isTablet) ...[
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          children: [
                                            _buildStockSection(item, stockLeft),
                                            const SizedBox(height: 20),
                                            _buildDateSection(
                                              item['manufactured_on_timestamp'],
                                              purchaseTimestamp,
                                              expiryTimestamp,
                                              createdTimestamp,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 20),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            _buildPricingSection(item),
                                            const SizedBox(height: 20),
                                            _buildAdditionalSection(item),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  _buildStockSection(item, stockLeft),
                                  const SizedBox(height: 20),
                                  _buildPricingSection(item),
                                  const SizedBox(height: 20),
                                  _buildDateSection(
                                    item['manufactured_on_timestamp'],
                                    purchaseTimestamp,
                                    expiryTimestamp,
                                    createdTimestamp,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildAdditionalSection(item),
                                ],

                                const SizedBox(height: 20),
                                // Access Control (Full Width)
                                _buildAccessSection(
                                  isWebEnabled,
                                  isPosEnabled,
                                  (val) =>
                                      setSheetState(() => isWebEnabled = val),
                                  (val) =>
                                      setSheetState(() => isPosEnabled = val),
                                ),
                              ],
                            ),
                          ),

                          // Footer Buttons
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                top: BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      foregroundColor: const Color(0xFF64748B),
                                      backgroundColor: const Color(0xFFF1F5F9),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      "Cancel",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // TODO: Save Logic
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      backgroundColor: const Color(0xFF2563EB),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      "Save Changes",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
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
      },
    );
  }

  // --- WIDGETS ---

  Widget _buildMainProductCard(
    Map<String, dynamic> productData,
    Map<String, dynamic> item,
    double stockLeft,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                productData['img_url'] ?? '',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.image_not_supported_rounded,
                  color: Color(0xFFCBD5E1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${productData['product_name']} - ${productData['variation_value'] ?? ''}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  productData['brand_name']?.toString() ?? "undefined",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 4),
                if (productData['product_type'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      productData['product_type'],
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E40AF),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip(
                      stockLeft > 0 ? "Available" : "Out of Stock",
                      stockLeft > 0
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFFEE2E2),
                      stockLeft > 0
                          ? const Color(0xFF166534)
                          : const Color(0xFF991B1B),
                    ),
                    if (item['category_name'] != null)
                      _buildChip(
                        item['category_name'],
                        const Color(0xFFDBEAFE),
                        const Color(0xFF1E40AF),
                      ),
                    if (item['hsn_code'] != null)
                      _buildChip(
                        "HSN: ${item['hsn_code']}",
                        const Color(0xFFF3E8FF),
                        const Color(0xFF6B21A8),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCurrency(item['selling_amount_excluding_tax']),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockSection(Map<String, dynamic> item, double stockLeft) {
    return _buildInfoCard("Stock Information", [
      _buildRow("Purchased:", _formatNumber(item['total_stocks_purchased'])),
      _buildRow("Sold:", _formatNumber(item['total_stocks_sold'])),
      _buildRow("Returned:", _formatNumber(item['total_stocks_returned'])),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(height: 1),
      ),
      _buildRow(
        "Available:",
        _formatNumber(stockLeft),
        valueColor: Colors.green,
        isBold: true,
      ),
    ]);
  }

  Widget _buildPricingSection(Map<String, dynamic> item) {
    return _buildInfoCard("Pricing Information", [
      _buildRow("MRP:", _formatCurrency(item['mrp'])),
      _buildRow(
        "Cost (Excl. Tax):",
        _formatCurrency(item['cost_amount_excluding_tax']),
      ),
      _buildRow(
        "Cost (Incl. Tax):",
        _formatCurrency(item['cost_amount_including_tax']),
      ),
      _buildRow(
        "Selling Price:",
        _formatCurrency(item['selling_amount_excluding_tax']),
      ),
    ]);
  }

  Widget _buildDateSection(
    dynamic manufactured,
    dynamic purchased,
    dynamic expired,
    dynamic created,
  ) {
    return _buildInfoCard("Date Information", [
      _buildRow("Manufactured:", _formatDate(manufactured)),
      _buildRow("Purchased:", _formatDate(purchased)),
      if (expired != null) _buildRow("Expires:", _formatDate(expired)),
      _buildRow("Created:", _formatDate(created)),
    ]);
  }

  Widget _buildAdditionalSection(Map<String, dynamic> item) {
    final productData = item['product_combination_data'] ?? {};
    final parentCategory = productData['parent_category'];
    final childCategory = productData['child_category'];

    String category = 'N/A';
    if (parentCategory != null && childCategory != null) {
      category = '$parentCategory / $childCategory';
    } else if (parentCategory != null) {
      category = parentCategory;
    } else if (childCategory != null) {
      category = childCategory;
    }

    return _buildInfoCard("Additional Information", [
      _buildRow(
        "State Code:",
        item['state_code_of_purchase']?.toString() ?? "N/A",
      ),
      _buildRow("Category:", category),
    ]);
  }

  Widget _buildAccessSection(
    bool isWeb,
    bool isPos,
    ValueChanged<bool> onWebChange,
    ValueChanged<bool> onPosChange,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Access Control",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          _buildAccessTile(
            "Web Orders",
            "Allow customers to order this product online",
            Icons.language,
            Colors.blue,
            isWeb,
            onWebChange,
          ),
          const SizedBox(height: 12),
          _buildAccessTile(
            "POS Orders",
            "Allow this product to be sold at point of sale",
            Icons.point_of_sale,
            Colors.purple,
            isPos,
            onPosChange,
          ),
        ],
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? const Color(0xFF1E293B),
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: color),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10, // Match web image small font
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value == null) return "0.00";
    double val = double.tryParse(value.toString()) ?? 0;
    return val.toStringAsFixed(2);
  }
}
