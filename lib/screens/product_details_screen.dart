import 'package:flutter/material.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:exanor/screens/payment_information_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String? supplierStoreId;

  const ProductDetailsScreen({
    super.key,
    required this.data,
    this.supplierStoreId,
  });

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

  // Linked products - track both status and product details
  final Map<int, bool> _linkedProducts = {};
  final Map<int, String> _linkedProductNames = {};
  final Map<int, String> _linkedProductIds = {};
  final Map<int, String> _linkedProductHsnCodes = {};

  // Barcode controllers for each product
  final Map<int, TextEditingController> _barcodeControllers = {};
  
  // Date controllers for each product
  final Map<int, TextEditingController> _mfgDateControllers = {};
  final Map<int, TextEditingController> _expDateControllers = {};
  
  // Product field controllers
  final Map<int, TextEditingController> _hsnControllers = {};
  final Map<int, TextEditingController> _quantityControllers = {};
  final Map<int, TextEditingController> _costControllers = {};
  final Map<int, TextEditingController> _mrpControllers = {};
  final Map<int, TextEditingController> _sellControllers = {};
  
  final _uuid = const Uuid();

  static const String storeId = 'd95069ca-839d-4469-8037-a5796633deb1';

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
  }

  Future<void> _fetchDropdownData() async {
    try {
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

  void _showProductSearchBottomSheet(int productIndex, String productName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductSearchBottomSheet(
        productIndex: productIndex,
        productName: productName,
        onProductLinked: (productId, linkedProductName, hsnCode) {
          setState(() {
            _linkedProducts[productIndex] = true;
            _linkedProductIds[productIndex] = productId;
            _linkedProductNames[productIndex] = linkedProductName;
            _linkedProductHsnCodes[productIndex] = hsnCode;
            
            // Update the HSN controller with the linked product's HSN code
            if (_hsnControllers.containsKey(productIndex)) {
              _hsnControllers[productIndex]!.text = hsnCode;
            } else {
              _hsnControllers[productIndex] = TextEditingController(text: hsnCode);
            }
          });
        },
      ),
    );
  }

  void _unlinkProduct(int productIndex) {
    setState(() {
      _linkedProducts[productIndex] = false;
      _linkedProductIds.remove(productIndex);
      _linkedProductNames.remove(productIndex);
      _linkedProductHsnCodes.remove(productIndex);
    });
  }

  /// Build updated data with linked product IDs, selected dropdowns, and barcodes
  Map<String, dynamic> _getUpdatedData() {
    // Deep copy the original data
    final updatedData = Map<String, dynamic>.from(widget.data);
    final response = Map<String, dynamic>.from(updatedData['response'] ?? {});
    final productsList = List<dynamic>.from(response['product_data'] ?? []);
    
    // Default manufacturing date if not provided by AI
    const defaultMfgDate = '1999-01-01';

    // Update each product with linked IDs and selected values
    for (int i = 0; i < productsList.length; i++) {
      final product = Map<String, dynamic>.from(productsList[i]);
      
      // Add linked product combination template ID and HSN code
      if (_linkedProductIds.containsKey(i)) {
        product['products_combination_template_id'] = _linkedProductIds[i];
      }
      
      // Add linked HSN code if product is linked
      if (_linkedProductHsnCodes.containsKey(i)) {
        product['hsn_sac_code'] = _linkedProductHsnCodes[i];
      }
      
      // Add selected unit ID - use first unit as default if not selected
      if (_selectedUnits.containsKey(i)) {
        product['unit_id'] = _selectedUnits[i];
      } else if (_units.isNotEmpty) {
        product['unit_id'] = _units[0]['id'];
      }
      
      // Add selected godown ID - use first godown as default if not selected
      if (_selectedGodowns.containsKey(i)) {
        product['godown_id'] = _selectedGodowns[i];
      } else if (_godowns.isNotEmpty) {
        product['godown_id'] = _godowns[0]['id'];
      }
      
      // Add selected rack ID - use first rack as default if not selected
      if (_selectedRacks.containsKey(i)) {
        product['rack_id'] = _selectedRacks[i];
      } else if (_racks.isNotEmpty) {
        product['rack_id'] = _racks[0]['id'];
      }
      
      // Add barcode
      if (_barcodeControllers.containsKey(i)) {
        product['barcode'] = _barcodeControllers[i]!.text;
      }
      
      // Add manufactured date - use today's date if not set
      if (_mfgDateControllers.containsKey(i) && _mfgDateControllers[i]!.text.isNotEmpty) {
        product['manufactured_on_date'] = _mfgDateControllers[i]!.text;
      } else {
        product['manufactured_on_date'] = defaultMfgDate;
      }
      
      // Add expiry date
      if (_expDateControllers.containsKey(i) && _expDateControllers[i]!.text.isNotEmpty) {
        product['expiry_date'] = _expDateControllers[i]!.text;
      }
      
      // Add user-edited product fields
      if (_hsnControllers.containsKey(i) && _hsnControllers[i]!.text.isNotEmpty) {
        product['hsn_sac_code'] = _hsnControllers[i]!.text;
      }
      if (_quantityControllers.containsKey(i) && _quantityControllers[i]!.text.isNotEmpty) {
        product['quantity'] = double.tryParse(_quantityControllers[i]!.text) ?? product['quantity'];
      }
      if (_costControllers.containsKey(i) && _costControllers[i]!.text.isNotEmpty) {
        product['rate'] = double.tryParse(_costControllers[i]!.text) ?? product['rate'];
      }
      if (_mrpControllers.containsKey(i) && _mrpControllers[i]!.text.isNotEmpty) {
        product['mrp'] = double.tryParse(_mrpControllers[i]!.text) ?? product['mrp'];
      }
      if (_sellControllers.containsKey(i) && _sellControllers[i]!.text.isNotEmpty) {
        product['selling_price'] = double.tryParse(_sellControllers[i]!.text) ?? product['mrp'];
      }
      
      productsList[i] = product;
    }

    response['product_data'] = productsList;
    updatedData['response'] = response;
    
    return updatedData;
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
                    'Tip: Click on product name to expand. Use checkbox to link with existing products.',
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
                final isLinked = _linkedProducts[index] ?? false;

                // Use linked HSN code if product is linked, otherwise use original
                final hsnCode = isLinked && _linkedProductHsnCodes.containsKey(index)
                    ? _linkedProductHsnCodes[index]!
                    : (product['hsn_sac_code']?.toString() ?? '');

                return _buildProductCard(
                  index,
                  product['product_name'] ?? 'Unknown Product',
                  product['quantity']?.toString() ?? '1',
                  product['rate']?.toString() ?? '',
                  product['mrp']?.toString() ?? '',
                  hsnCode,
                  product['unit'] ?? '',
                  product['manufacturing_date']?.toString() ?? '',
                  product['expiry_date']?.toString() ?? '',
                  isExpanded,
                  isLinked,
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
                        // Get updated data with linked product IDs and selections
                        final updatedData = _getUpdatedData();
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PaymentInformationScreen(
                                  data: updatedData,
                                  supplierStoreId: widget.supplierStoreId,
                                ),
                          ),
                        );
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
    bool isLinked,
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
          // Header - Clickable product name
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Quantity badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${quantity}x',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Product name - clickable to expand
                Expanded(
                  child: InkWell(
                    onTap: onToggle,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Show linked product name if linked, otherwise original product name
                        Text(
                          isLinked && _linkedProductNames.containsKey(index)
                              ? _linkedProductNames[index]!
                              : productName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Show original product name in shadow text if linked
                        if (isLinked &&
                            _linkedProductNames.containsKey(index)) ...[
                          Text(
                            'Original Product: $productName',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[400],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
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
                ),
                // Checkbox button - toggle on/off
                InkWell(
                  onTap: () {
                    if (isLinked) {
                      // If already linked, unlink it
                      _unlinkProduct(index);
                    } else {
                      // If not linked, open search bottom sheet
                      _showProductSearchBottomSheet(index, productName);
                    }
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isLinked ? Colors.blue : Colors.grey[400]!,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      color: isLinked ? Colors.blue : Colors.transparent,
                    ),
                    child: isLinked
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
              ],
            ),
          ),

          // Expandable details
          if (isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildEditableField('HSN/SAC', hsn, index, 'hsn')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildEditableField('Quantity', quantity, index, 'quantity')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildEditableField('Cost (₹)', cost, index, 'cost')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildEditableField('MRP (₹)', mrp, index, 'mrp')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildEditableField('Sell (₹)', mrp, index, 'sell'),
                  const SizedBox(height: 16),
                  
                  // Date fields with controllers
                  Row(
                    children: [
                      Expanded(child: _buildDateField('MFG DATE', mfgDate, index, 'mfg')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildDateField('EXP DATE', expDate, index, 'exp')),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Dropdowns
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

                  // Barcode field (without Link button)
                  _buildBarcodeField(index),
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

  Widget _buildEditableField(String label, String initialValue, int productIndex, String type) {
    // Get or create the controller for this field
    TextEditingController? controller;
    
    switch (type) {
      case 'hsn':
        if (!_hsnControllers.containsKey(productIndex)) {
          _hsnControllers[productIndex] = TextEditingController(text: initialValue);
        }
        controller = _hsnControllers[productIndex];
        break;
      case 'quantity':
        if (!_quantityControllers.containsKey(productIndex)) {
          _quantityControllers[productIndex] = TextEditingController(text: initialValue);
        }
        controller = _quantityControllers[productIndex];
        break;
      case 'cost':
        if (!_costControllers.containsKey(productIndex)) {
          _costControllers[productIndex] = TextEditingController(text: initialValue);
        }
        controller = _costControllers[productIndex];
        break;
      case 'mrp':
        if (!_mrpControllers.containsKey(productIndex)) {
          _mrpControllers[productIndex] = TextEditingController(text: initialValue);
        }
        controller = _mrpControllers[productIndex];
        break;
      case 'sell':
        if (!_sellControllers.containsKey(productIndex)) {
          _sellControllers[productIndex] = TextEditingController(text: initialValue);
        }
        controller = _sellControllers[productIndex];
        break;
    }

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
          controller: controller,
          keyboardType: type == 'hsn' ? TextInputType.text : TextInputType.number,
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

  Widget _buildBarcodeField(int productIndex) {
    // Generate UUID for barcode if not already exists
    if (!_barcodeControllers.containsKey(productIndex)) {
      _barcodeControllers[productIndex] = TextEditingController(
        text: _uuid.v4(),
      );
    }

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
        TextField(
          controller: _barcodeControllers[productIndex],
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'Scan or Auto-generated UUID',
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
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, String initialValue, int productIndex, String type) {
    // Initialize controller if not exists
    // Get today's date in YYYY-MM-DD format for default manufacturing date
    // Default manufacturing date if not provided by AI
    const defaultMfgDate = '1999-01-01';
    
    if (type == 'mfg' && !_mfgDateControllers.containsKey(productIndex)) {
      // Use 1999-01-01 as default if manufacturing date is empty
      final dateValue = initialValue.isNotEmpty ? initialValue : defaultMfgDate;
      _mfgDateControllers[productIndex] = TextEditingController(text: dateValue);
    } else if (type == 'exp' && !_expDateControllers.containsKey(productIndex)) {
      _expDateControllers[productIndex] = TextEditingController(text: initialValue);
    }

    final controller = type == 'mfg' 
        ? _mfgDateControllers[productIndex] 
        : _expDateControllers[productIndex];

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
          controller: controller,
          decoration: InputDecoration(
            hintText: 'YYYY-MM-DD',
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
            suffixIcon: Icon(Icons.calendar_today, size: 16, color: Colors.grey[400]),
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}

// Product Search Bottom Sheet Widget
class ProductSearchBottomSheet extends StatefulWidget {
  final int productIndex;
  final String productName;
  final Function(String productId, String linkedProductName, String hsnCode) onProductLinked;

  const ProductSearchBottomSheet({
    super.key,
    required this.productIndex,
    required this.productName,
    required this.onProductLinked,
  });

  @override
  State<ProductSearchBottomSheet> createState() =>
      _ProductSearchBottomSheetState();
}

class _ProductSearchBottomSheetState extends State<ProductSearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Pre-fill search bar with product name
    _searchController.text = widget.productName;
    // Trigger search with the pre-filled product name
    _searchProducts(widget.productName);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _searchProducts(query);
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  Future<void> _searchProducts(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result =
          await StoreOwnerApiService.searchProductCombinationTemplates(
            query: query,
            storeId: _ProductDetailsScreenState.storeId,
          );

      if (result['status'] == 200 && result['response'] != null) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(result['response']);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error searching products: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Black Header with Link Icon and Close Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Link Product',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Search and link existing product',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Search bar with blue border
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search products...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),

          // Search results
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? 'Start typing to search products'
                          : 'No products found',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final product = _searchResults[index];
                      return _buildProductItem(product);
                    },
                  ),
          ),

          // Can't find? Add New Product button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Coming Soon'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.grey[700]),
                  const SizedBox(width: 8),
                  Text(
                    "Can't find? Add New Product",
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

  Widget _buildProductItem(Map<String, dynamic> product) {
    final productName =
        product['product_combination_template_name'] ?? 'Unknown';
    final gstData = product['gst_data'] ?? {};
    final hsnCode = gstData['hsn_code'] ?? '';
    final cgstPercent = gstData['cgst_percent'] ?? 0.0;
    final sgstPercent = gstData['sgst_percent'] ?? 0.0;
    final igstPercent = gstData['igst_percent'] ?? 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name and HSN
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'HSN: $hsnCode',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // GST badges
                Row(
                  children: [
                    _buildGstBadge(
                      'COST: ${cgstPercent.toStringAsFixed(1)}%',
                      Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    _buildGstBadge(
                      'SGST: ${sgstPercent.toStringAsFixed(1)}%',
                      Colors.green,
                    ),
                    const SizedBox(width: 6),
                    _buildGstBadge(
                      'IGST: ${igstPercent.toStringAsFixed(1)}%',
                      Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Link button
          InkWell(
            onTap: () {
              widget.onProductLinked(product['id'], productName, hsnCode);
              Navigator.pop(context);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.link, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGstBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
