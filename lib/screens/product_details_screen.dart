import 'package:flutter/material.dart';
import 'package:exanor/services/store_owner_api_service.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const ProductDetailsScreen({super.key, required this.data});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  // Track which products are expanded
  final Set<int> _expandedProducts = {};

  // Dropdown options
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _godowns = [];
  List<Map<String, dynamic>> _racks = [];

  // Selected values for each product
  final Map<int, String> _selectedUnits = {};
  final Map<int, String> _selectedGodowns = {};
  final Map<int, String> _selectedRacks = {};

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
  }

  Future<void> _fetchDropdownData() async {
    try {
      // Get store ID from wherever it's stored (you may need to adjust this)
      const storeId =
          'd95069ca-839d-4469-8037-a5796633deb1'; // TODO: Get from auth or storage

      final units = await StoreOwnerApiService.getUnits(storeId);
      final godowns = await StoreOwnerApiService.getGodowns(storeId);
      final racks = await StoreOwnerApiService.getRacks(storeId);

      setState(() {
        _units = units;
        _godowns = godowns;
        _racks = racks;
      });
    } catch (e) {
      print('Error fetching dropdown data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract products from API response
    final response = widget.data['response'] ?? {};
    final productsList = response['product_data'] as List<dynamic>? ?? [];

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
                  product['quantity']?.toString() ?? '1',
                  product['rate']?.toString() ?? '',
                  product['mrp']?.toString() ?? '',
                  product['hsn_sac_code']?.toString() ?? '',
                  product['unit'] ?? '',
                  product['manufacturing_date']?.toString() ?? '',
                  product['expiry_date']?.toString() ?? '',
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

  Widget _buildProductCard(
    int index,
    String productName,
    String quantity,
    String cost,
    String mrp,
    String hsn,
    String unit,
    String mfgDate,
    String expDate,
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
                  // Quantity instead of S.No.
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      quantity,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 16,
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
                        // Show MRP and Cost instead of product status
                        Row(
                          children: [
                            Text(
                              'MRP: ₹$mrp',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Cost: ₹$cost',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
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
                  _buildFieldRow('HSN/SAC', hsn, 'Quantity', quantity),
                  const SizedBox(height: 16),
                  _buildFieldRow('Cost (₹)', cost, 'MRP (₹)', mrp),
                  const SizedBox(height: 16),
                  _buildFieldRow('Sell (₹)', cost, 'MFG DATE', mfgDate),
                  const SizedBox(height: 16),
                  _buildFieldRow('EXP DATE', expDate, '', ''),
                  const SizedBox(height: 16),

                  // Dropdowns for Unit, Godown, Rack
                  _buildDropdownField('Unit', unit, _units, index, 'unit'),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    'Godown',
                    'Default Godown',
                    _godowns,
                    index,
                    'godown',
                  ),
                  const SizedBox(height: 16),
                  _buildDropdownField(
                    'Rack',
                    'Default Rack',
                    _racks,
                    index,
                    'rack',
                  ),
                  const SizedBox(height: 16),

                  // Barcode field
                  _buildBarcodeField(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldRow(
    String label1,
    String value1,
    String label2,
    String value2,
  ) {
    if (label2.isEmpty) {
      return _buildField(label1, value1);
    }
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

  Widget _buildDropdownField(
    String label,
    String defaultValue,
    List<Map<String, dynamic>> options,
    int productIndex,
    String type,
  ) {
    // Get the appropriate selected value based on type
    String? selectedValue;
    if (type == 'unit') {
      selectedValue = _selectedUnits[productIndex];
    } else if (type == 'godown') {
      selectedValue = _selectedGodowns[productIndex];
    } else if (type == 'rack') {
      selectedValue = _selectedRacks[productIndex];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: selectedValue,
              hint: Text(defaultValue, style: const TextStyle(fontSize: 13)),
              items: options.map((option) {
                String displayText;
                String value;

                if (type == 'unit') {
                  displayText = '${option['code']} - ${option['description']}';
                  value = option['id'];
                } else if (type == 'godown') {
                  displayText = option['name'];
                  value = option['id'];
                } else {
                  // rack
                  displayText = option['name'];
                  value = option['id'];
                }

                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    displayText,
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  if (type == 'unit') {
                    _selectedUnits[productIndex] = value!;
                  } else if (type == 'godown') {
                    _selectedGodowns[productIndex] = value!;
                  } else if (type == 'rack') {
                    _selectedRacks[productIndex] = value!;
                  }
                });
              },
            ),
          ),
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
