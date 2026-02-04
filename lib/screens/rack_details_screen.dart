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
            Expanded(
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
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TranslatedText(
                            'BACK',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.blueGrey[400],
                              letterSpacing: 1.2,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.blueGrey,
                              size: 24,
                            ),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
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
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Color(0xFF64748B),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Container(
                          height: 20,
                          width: 1,
                          color: Colors.grey[200],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: "Search items",
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: TextStyle(
                              color: _textMain,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.search_rounded, color: _primary),
                      ],
                    ),
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

  // --- EDIT SHEET (Briefly styled) ---

  void _showEditProductSheet(Map<String, dynamic> item) {
    final productData = item['product_combination_data'] ?? {};

    // Data Parsing
    final stockLeft =
        double.tryParse(item['total_stocks_left']?.toString() ?? '0') ?? 0;
    final purchaseTimestamp = item['purchase_timestamp'];
    final expiryTimestamp = item['expiry_timestamp'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[100]!),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              productData['img_url'] ?? '',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.image_not_supported_rounded,
                                color: _textSub.withOpacity(0.3),
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Title & ID
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "IN STOCK",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: _primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                productData['product_name'] ?? 'Unknown Item',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: _textMain,
                                  height: 1.2,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Barcode: ${item['barcode'] ?? 'N/A'}",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _textSub,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: ListView(
                      controller: controller,
                      padding: const EdgeInsets.all(24),
                      children: [
                        // 1. Pricing Section
                        _buildSectionHeader("Pricing & Economics"),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF64748B,
                                ).withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildDetailItem(
                                  "Selling Price",
                                  _formatCurrency(
                                    item['selling_amount_excluding_tax'],
                                  ),
                                  icon: Icons.sell_rounded,
                                  isHighlight: true,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey[200],
                              ),
                              Expanded(
                                child: _buildDetailItem(
                                  "MRP",
                                  _formatCurrency(item['mrp']),
                                  icon: Icons.price_change_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // 2. Stock & Dates
                        _buildSectionHeader("Stock & Metadata"),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF64748B,
                                ).withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailItem(
                                      "Current Stock",
                                      stockLeft.toStringAsFixed(0),
                                      icon: Icons.inventory_2_rounded,
                                      valueColor: stockLeft > 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildDetailItem(
                                      "Added On",
                                      _formatDate(purchaseTimestamp),
                                      icon: Icons.calendar_today_rounded,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Divider(height: 1),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailItem(
                                      "Expires On",
                                      _formatDate(expiryTimestamp),
                                      icon: Icons.event_busy_rounded,
                                      valueColor: Colors.orange,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildDetailItem(
                                      "Batch No",
                                      item['batch_number'] ?? 'N/A',
                                      icon: Icons.qr_code_rounded,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // 3. Movement History
                        _buildSectionHeader("Movement History"),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildHistoryCard(
                              "Purchased",
                              item['total_stocks_purchased']?.toString() ?? '0',
                              Colors.blue,
                            ),
                            const SizedBox(width: 12),
                            _buildHistoryCard(
                              "Sold",
                              item['total_stocks_sold']?.toString() ?? '0',
                              Colors.green,
                            ),
                            const SizedBox(width: 12),
                            _buildHistoryCard(
                              "Returned",
                              item['total_stocks_returned']?.toString() ?? '0',
                              Colors.red,
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),

                  // Bottom Action Bar
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      16 + MediaQuery.of(context).padding.bottom,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Colors.grey[100]!)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // TODO: Implement Adjust Stock logic
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              "Adjust Stock",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _textMain,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // TODO: Implement Edit logic
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _textMain,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Edit Details",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
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
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: _primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _textMain,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem(
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: _textSub),
          ),
        if (icon != null) const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _textSub,
                  letterSpacing: 0.5,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: isHighlight ? 18 : 15,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? _textMain,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
