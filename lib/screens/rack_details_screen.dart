import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:exanor/components/translation_widget.dart';

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

  @override
  void initState() {
    super.initState();
    _fetchProducts();
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
          _totalCount = data['pagination']['total_count'];
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
    if (timestamp == null) return '';
    if (timestamp is int) {
      return DateFormat(
        'MMM d, yyyy',
      ).format(DateTime.fromMillisecondsSinceEpoch(timestamp * 1000));
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TranslatedText(
          widget.rackName,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(left: 72, bottom: 16),
            child: Row(
              children: [
                Text(
                  '$_totalCount products',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search and Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            DropdownButton<String>(
                              value: 'Barcode',
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Barcode',
                                  child: Text(
                                    'Barcode',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                              onChanged: (val) {},
                            ),
                            Container(
                              height: 24,
                              width: 1,
                              color: Colors.grey.shade300,
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Search by barcode...',
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            const Icon(Icons.search, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(Icons.calendar_today, '7d'),
                      const SizedBox(width: 8),
                      _buildFilterChip(null, '15d'),
                      const SizedBox(width: 8),
                      _buildFilterChip(null, '30d'),
                      const SizedBox(width: 16),
                      _buildActionButton(Icons.filter_list, 'Filters'),
                      const SizedBox(width: 8),
                      _buildActionButton(Icons.sort, 'Sort'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : _products.isEmpty
                ? const Center(child: Text('No products found'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _products.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _buildProductCard(_products[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(IconData? icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.grey[700]),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(dynamic item) {
    final productData = item['product_combination_data'] ?? {};
    final purchaseTimestamp = item['purchase_timestamp'];
    final expiryTimestamp = item['expiry_timestamp'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    productData['img_url'] ?? '',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productData['product_name'] ?? 'Unknown Product',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        productData['brand_name'] ?? 'undefined',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildStatusTag(
                            'Available',
                            Colors.green.shade50,
                            Colors.green.shade700,
                          ),
                          if (item['is_accessible_online'] == true)
                            _buildStatusTag(
                              'Online',
                              Colors.blue.shade50,
                              Colors.blue.shade700,
                            ),
                          if (item['is_accessible_pos'] == true)
                            _buildStatusTag(
                              'POS',
                              Colors.purple.shade50,
                              Colors.purple.shade700,
                            ),
                          if (item['hsn_code'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.tag,
                                    size: 12,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'HSN: ${item['hsn_code']}',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
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
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFF9FAFB),
            child: Row(
              children: [
                Expanded(
                  child: _buildStockInfo(
                    Icons.shopping_bag_outlined,
                    'Purchased',
                    item['total_stocks_purchased'],
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStockInfo(
                    Icons.shopping_cart_outlined,
                    'Sold',
                    item['total_stocks_sold'],
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStockInfo(
                    Icons.replay,
                    'Returned',
                    item['total_stocks_returned'],
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildPriceInfo('MRP', _formatCurrency(item['mrp'])),
                ),
                Expanded(
                  child: _buildPriceInfo(
                    'Cost (Excl.)',
                    _formatCurrency(item['cost_amount_excluding_tax']),
                  ),
                ),
                Expanded(
                  child: _buildPriceInfo(
                    'Cost (Incl.)',
                    _formatCurrency(item['cost_amount_including_tax']),
                  ),
                ),
                Expanded(
                  child: _buildPriceInfo(
                    'Selling Price',
                    _formatCurrency(item['selling_amount_excluding_tax']),
                    isGreen: true,
                  ),
                ),
              ],
            ),
          ),

          if (expiryTimestamp != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Expires: ${_formatDate(expiryTimestamp)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusTag(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStockInfo(
    IconData icon,
    String label,
    dynamic value,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            Text(
              double.tryParse(value?.toString() ?? '0')?.toStringAsFixed(1) ??
                  '0.0',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceInfo(String label, String value, {bool isGreen = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isGreen ? Colors.green[700] : Colors.black87,
          ),
        ),
      ],
    );
  }
}
