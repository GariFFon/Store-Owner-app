import 'package:flutter/material.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const ProductDetailsScreen({super.key, required this.data});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  // Track which products are expanded
  final Set<int> _expandedProducts = {};

  @override
  Widget build(BuildContext context) {
    // Extract products from API response
    final response = widget.data['response'] ?? {};
    final productsList = response['product_data'] as List<dynamic>? ?? [];

    // Count statistics
    final totalProducts = productsList.length;
    final alreadyExist = productsList
        .where((p) => p['product_already_exists'] == true)
        .length;
    final needCreation = totalProducts - alreadyExist;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Back to Purchase List',
          style: TextStyle(fontSize: 14, color: Colors.blue),
        ),
        titleSpacing: 0,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header Card
          Container(
            color: Colors.black,
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Review and edit AI-extracted products',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Progress Steps
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildProgressChip('Upload Invoice', true, true),
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  _buildProgressChip('Supplier Details', true, true),
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  _buildProgressChip('Product Data Mapping', true, false),
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  _buildProgressChip('Payment Information', false, false),
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  _buildProgressChip('Confirmation', false, false),
                ],
              ),
            ),
          ),

          // Statistics
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatBox(
                  totalProducts.toString(),
                  'Total Products',
                  Colors.blue,
                ),
                _buildStatBox(
                  alreadyExist.toString(),
                  'Already Exist',
                  Colors.green,
                ),
                _buildStatBox(
                  needCreation.toString(),
                  'Need Creation',
                  Colors.orange,
                ),
              ],
            ),
          ),

          // Tip Banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: Click on a product to expand and view/edit details.',
                    style: TextStyle(fontSize: 11, color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
          ),

          // Product List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: productsList.length,
              itemBuilder: (context, index) {
                final product = productsList[index];
                final isExpanded = _expandedProducts.contains(index);

                return _buildProductCard(
                  index,
                  product['product_name'] ?? 'Unknown Product',
                  product['hsn_sac_code']?.toString() ?? '',
                  product['unit'] ?? 'Select Unit',
                  product['quantity']?.toString() ?? '1',
                  product['rate']?.toString() ?? '',
                  product['mrp']?.toString() ?? '',
                  product['rate']?.toString() ?? '',
                  product['manufacturing_date']?.toString() ?? '',
                  product['expiry_date']?.toString() ?? '',
                  product['product_already_exists'] ?? false,
                  isExpanded,
                  () {
                    setState(() {
                      if (isExpanded) {
                        _expandedProducts.remove(index);
                      } else {
                        _expandedProducts.add(index);
                      }
                    });
                  },
                );
              },
            ),
          ),

          // Bottom Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Colors.black),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _buildProgressChip(String label, bool isCompleted, bool isActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.blue
            : isCompleted
            ? Colors.green
            : Colors.grey[300],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isActive || isCompleted ? Colors.white : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildStatBox(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildProductCard(
    int index,
    String productName,
    String hsn,
    String unit,
    String qty,
    String cost,
    String mrp,
    String sell,
    String mfgDate,
    String expDate,
    bool productExists,
    bool isExpanded,
    VoidCallback onToggle,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Always visible: Product Header (clickable to expand/collapse)
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      (index + 1).toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: productExists
                                    ? Colors.green
                                    : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              productExists ? 'Already exists' : 'New product',
                              style: TextStyle(
                                fontSize: 12,
                                color: productExists
                                    ? Colors.green
                                    : Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey[600],
                    size: 28,
                  ),
                ],
              ),
            ),
          ),

          // Expandable details section
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldRow('HSN/SAC', hsn, 'Unit', unit),
                  const SizedBox(height: 16),
                  _buildFieldRow('Quantity', qty, 'Cost (₹)', cost),
                  const SizedBox(height: 16),
                  _buildFieldRow('MRP (₹)', mrp, 'Sell (₹)', sell),
                  const SizedBox(height: 16),
                  _buildThreeFieldRow(
                    'MFG DATE',
                    mfgDate,
                    'EXP DATE',
                    expDate,
                    'GODOWN',
                    'Default Godown',
                  ),
                  const SizedBox(height: 16),
                  _buildField('RACK', 'Default Rack'),
                  const SizedBox(height: 16),
                  _buildBarcodeField(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThreeFieldRow(
    String label1,
    String value1,
    String label2,
    String value2,
    String label3,
    String value3,
  ) {
    return Row(
      children: [
        Expanded(child: _buildField(label1, value1)),
        const SizedBox(width: 12),
        Expanded(child: _buildField(label2, value2)),
        const SizedBox(width: 12),
        Expanded(child: _buildField(label3, value3)),
      ],
    );
  }

  Widget _buildFieldRow(
    String label1,
    String value1,
    String label2,
    String value2,
  ) {
    return Row(
      children: [
        Expanded(child: _buildField(label1, value1)),
        const SizedBox(width: 12),
        Expanded(child: _buildField(label2, value2)),
      ],
    );
  }

  Widget _buildField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: TextEditingController(text: value),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildBarcodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'BARCODE',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Scan or generate',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.add, color: Colors.white, size: 20),
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.link, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Link',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
