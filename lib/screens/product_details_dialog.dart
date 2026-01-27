import 'package:flutter/material.dart';

class ProductDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onContinue;
  final VoidCallback onBack;

  const ProductDetailsDialog({
    super.key,
    required this.data,
    required this.onContinue,
    required this.onBack,
  });

  @override
  State<ProductDetailsDialog> createState() => _ProductDetailsDialogState();
}

class _ProductDetailsDialogState extends State<ProductDetailsDialog> {
  int _currentView = 0; // 0 = Basic Info, 1 = Additional Info

  @override
  Widget build(BuildContext context) {
    // Extract products from API response
    final response = widget.data['response'] ?? {};
    final productsList = response['products'] as List<dynamic>? ?? [];

    // Count statistics
    final totalProducts = productsList.length;
    final alreadyExist = productsList
        .where((p) => p['product_already_exists'] == true)
        .length;
    final needCreation = totalProducts - alreadyExist;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
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
                          'Review and edit 2 AI-extracted products',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onBack,
                  ),
                ],
              ),
            ),

            // Progress Steps
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              color: Colors.grey[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStepIndicator('Upload Invoice', true, true),
                  _buildStepConnector(true),
                  _buildStepIndicator('Supplier Details', true, true),
                  _buildStepConnector(true),
                  _buildStepIndicator('Product Data Mapping', true, false),
                  _buildStepConnector(false),
                  _buildStepIndicator('Payment Information', false, false),
                  _buildStepConnector(false),
                  _buildStepIndicator('Confirmation', false, false),
                ],
              ),
            ),

            // Statistics
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatBox(
                    totalProducts.toString(),
                    'Total Products',
                    Colors.blue,
                  ),
                  const SizedBox(width: 40),
                  _buildStatBox(
                    alreadyExist.toString(),
                    'Already Exist',
                    Colors.green,
                  ),
                  const SizedBox(width: 40),
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
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tip: Use TAB to move forward, SHIFT+TAB to move backward, and arrow keys to navigate.',
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _currentView == 0
                    ? _buildBasicInfoView(productsList)
                    : _buildAdditionalInfoView(productsList),
              ),
            ),

            const Divider(height: 1),

            // Footer
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: widget.onContinue,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('Continue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FloatingActionButton(
                    onPressed: () {},
                    backgroundColor: Colors.blue,
                    mini: true,
                    child: const Icon(Icons.message),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(String label, bool isCompleted, bool isActive) {
    return Container(
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
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive || isCompleted ? Colors.white : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildStepConnector(bool isCompleted) {
    return Container(
      height: 2,
      width: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: isCompleted ? Colors.green : Colors.grey[300],
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
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildBasicInfoView(List<dynamic> products) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 40,
                child: Text(
                  '#',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                flex: 3,
                child: Text(
                  'PRODUCT NAME',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                flex: 2,
                child: Text(
                  'HSN/SAC',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                flex: 2,
                child: Text(
                  'UNIT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                flex: 1,
                child: Text(
                  'QTY',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                flex: 2,
                child: Text(
                  'COST (₹)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                flex: 2,
                child: Text(
                  'MRP (₹)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                flex: 2,
                child: Text(
                  'SELL (₹)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Table Rows
        ...List.generate(products.length, (index) {
          final product = products[index];
          return _buildProductRow(
            index + 1,
            product['product_name'] ?? 'Unknown Product',
            product['hsn_code']?.toString() ?? '',
            product['unit'] ?? 'Select Unit',
            product['quantity']?.toString() ?? '1',
            product['cost']?.toString() ?? '',
            product['mrp']?.toString() ?? '',
            product['sell_price']?.toString() ?? '',
          );
        }),
      ],
    );
  }

  Widget _buildProductRow(
    int index,
    String productName,
    String hsn,
    String unit,
    String qty,
    String cost,
    String mrp,
    String sell,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(index.toString(), style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              productName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: TextField(
              controller: TextEditingController(text: hsn),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(unit, style: const TextStyle(fontSize: 13)),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: TextField(
              controller: TextEditingController(text: qty),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: TextField(
              controller: TextEditingController(text: cost),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: TextField(
              controller: TextEditingController(text: mrp),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: TextField(
              controller: TextEditingController(text: sell),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoView(List<dynamic> products) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 40,
                child: Text(
                  '#',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                flex: 2,
                child: Text(
                  'SELL (₹)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                flex: 2,
                child: Text(
                  'MFG DATE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                flex: 2,
                child: Text(
                  'EXP DATE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                flex: 2,
                child: Text(
                  'GODOWN',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                flex: 2,
                child: Text(
                  'RACK',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                flex: 2,
                child: Text(
                  'BARCODE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                flex: 2,
                child: Text(
                  'STATUS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Table Rows
        ...List.generate(products.length, (index) {
          final product = products[index];
          return _buildAdditionalInfoRow(
            index + 1,
            product['sell_price']?.toString() ?? '',
            product['manufacture_date'] ?? '27-01-2026',
            product['expiry_date'] ?? 'DD-MM-YYYY',
          );
        }),
      ],
    );
  }

  Widget _buildAdditionalInfoRow(
    int index,
    String sell,
    String mfgDate,
    String expDate,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(index.toString(), style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: TextField(
              controller: TextEditingController(text: sell),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: TextField(
              controller: TextEditingController(text: mfgDate),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: TextField(
              controller: TextEditingController(text: expDate),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: Colors.red[400]!),
                ),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Default Godown', style: TextStyle(fontSize: 13)),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Default Rack', style: TextStyle(fontSize: 13)),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Scan or generate',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 16),
                    onPressed: () {},
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Link',
                    style: TextStyle(color: Colors.white, fontSize: 13),
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
