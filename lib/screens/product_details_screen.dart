import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:exanor/screens/payment_information_screen.dart';
import 'package:intl/intl.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String? supplierStoreId;
  final String storeId;

  const ProductDetailsScreen({
    super.key,
    required this.data,
    required this.storeId,
    this.supplierStoreId,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Dropdown options
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _godowns = [];
  List<Map<String, dynamic>> _racks = [];

  // Selected values for each product
  final Map<int, String> _selectedUnits = {};
  final Map<int, String> _selectedGodowns = {};
  final Map<int, String> _selectedRacks = {};

  // Linked products
  final Map<int, bool> _linkedProducts = {};
  final Map<int, String> _linkedProductNames = {};
  final Map<int, String> _linkedProductIds = {};
  final Map<int, String> _linkedProductHsnCodes = {};

  // Controllers
  final Map<int, TextEditingController> _hsnControllers = {};
  final Map<int, TextEditingController> _quantityControllers = {};
  final Map<int, TextEditingController> _costControllers = {};
  final Map<int, TextEditingController> _mrpControllers = {};
  final Map<int, TextEditingController> _sellControllers = {};
  final Map<int, TextEditingController> _barcodeControllers = {};
  final Map<int, TextEditingController> _mfgDateControllers = {};
  final Map<int, TextEditingController> _expDateControllers = {};

  // Invoice Details
  final TextEditingController _invoiceNumController = TextEditingController();
  final TextEditingController _invoiceDateController = TextEditingController();

  double _totalEstimatedValue = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeControllers();
    _fetchDropdownData();
    _calculateTotal();
  }

  void _calculateTotal() {
    double total = 0.0;
    _costControllers.forEach((index, controller) {
      final cost = double.tryParse(controller.text) ?? 0.0;
      final qty =
          double.tryParse(_quantityControllers[index]?.text ?? '0') ?? 0.0;
      total += (cost * qty);
    });
    setState(() {
      _totalEstimatedValue = total;
    });
  }

  void _initializeControllers() {
    final response = widget.data['response'] ?? {};
    final productsList = List<dynamic>.from(response['product_data'] ?? []);

    _invoiceNumController.text = response['invoice_id']?.toString() ?? '';
    _invoiceDateController.text = response['invoice_date']?.toString() ?? '';

    for (int i = 0; i < productsList.length; i++) {
      final product = Map<String, dynamic>.from(productsList[i]);

      _hsnControllers[i] = TextEditingController(
        text: product['hsn_sac_code']?.toString() ?? '',
      );
      _quantityControllers[i] = TextEditingController(
        text: product['quantity']?.toString() ?? '1',
      )..addListener(_calculateTotal);
      _costControllers[i] = TextEditingController(
        text: product['rate']?.toString() ?? '0',
      )..addListener(_calculateTotal);
      _mrpControllers[i] = TextEditingController(
        text: product['mrp']?.toString() ?? '0',
      );
      _sellControllers[i] = TextEditingController(
        text:
            product['selling_price']?.toString() ??
            product['mrp']?.toString() ??
            '0',
      );
      _barcodeControllers[i] = TextEditingController(
        text:
            product['barcode']?.toString() ??
            'GEN-${const Uuid().v4().substring(0, 8).toUpperCase()}',
      );
      _mfgDateControllers[i] = TextEditingController(
        text: product['manufactured_on_date']?.toString() ?? '',
      );
      _expDateControllers[i] = TextEditingController(
        text: product['expiry_date']?.toString() ?? '',
      );

      if (product['unit_id'] != null) {
        _selectedUnits[i] = product['unit_id'].toString();
      }
      if (product['godown_id'] != null) {
        _selectedGodowns[i] = product['godown_id'].toString();
      }
      if (product['rack_id'] != null) {
        _selectedRacks[i] = product['rack_id'].toString();
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hsnControllers.forEach((_, c) => c.dispose());
    _quantityControllers.forEach((_, c) => c.dispose());
    _costControllers.forEach((_, c) => c.dispose());
    _mrpControllers.forEach((_, c) => c.dispose());
    _sellControllers.forEach((_, c) => c.dispose());
    _barcodeControllers.forEach((_, c) => c.dispose());
    _mfgDateControllers.forEach((_, c) => c.dispose());
    _expDateControllers.forEach((_, c) => c.dispose());
    _invoiceNumController.dispose();
    _invoiceDateController.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdownData() async {
    try {
      final units = await StoreOwnerApiService.getUnits(widget.storeId);
      final godowns = await StoreOwnerApiService.getGodowns(widget.storeId);
      final racks = await StoreOwnerApiService.getRacks(widget.storeId);

      if (mounted) {
        setState(() {
          _units = units;
          _godowns = godowns;
          _racks = racks;

          // Set defaults
          final productsList =
              (widget.data['response'] ?? {})['product_data']
                  as List<dynamic>? ??
              [];
          for (int i = 0; i < productsList.length; i++) {
            if (!_selectedUnits.containsKey(i) && _units.isNotEmpty) {
              final defaultUnit = _units.firstWhere(
                (u) =>
                    (u['name']?.toString().toUpperCase().contains('PCS') ??
                        false) ||
                    (u['name']?.toString().toUpperCase().contains('PIECES') ??
                        false),
                orElse: () => _units.first,
              );
              _selectedUnits[i] = defaultUnit['id'].toString();
            }
            if (!_selectedGodowns.containsKey(i) && _godowns.isNotEmpty) {
              _selectedGodowns[i] = _godowns[0]['id'].toString();
            }
            if (!_selectedRacks.containsKey(i) &&
                _racks.isNotEmpty &&
                _selectedGodowns.containsKey(i)) {
              final godownRacks = _racks
                  .where((r) => r['godown']?.toString() == _selectedGodowns[i])
                  .toList();
              if (godownRacks.isNotEmpty) {
                _selectedRacks[i] = godownRacks[0]['id'].toString();
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching dropdown data: $e');
    }
  }

  Future<void> _selectDate(BuildContext context, int index, bool isMfg) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isMfg ? (now.subtract(const Duration(days: 1))) : now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3B82F6), // Blue 500
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B), // Slate 800
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        if (isMfg) {
          _mfgDateControllers[index]?.text = formattedDate;
        } else {
          _expDateControllers[index]?.text = formattedDate;
        }
      });
    }
  }

  Map<String, dynamic> _getUpdatedData() {
    final updatedData = Map<String, dynamic>.from(widget.data);
    final response = Map<String, dynamic>.from(updatedData['response'] ?? {});
    final productsList = List<dynamic>.from(response['product_data'] ?? []);
    const defaultMfgDate = '1999-01-01';

    // Update invoice details
    response['invoice_id'] = _invoiceNumController.text;
    response['invoice_date'] = _invoiceDateController.text;

    for (int i = 0; i < productsList.length; i++) {
      final product = Map<String, dynamic>.from(productsList[i]);

      if (_linkedProductIds.containsKey(i)) {
        product['products_combination_template_id'] = _linkedProductIds[i];
      }
      if (_linkedProductHsnCodes.containsKey(i)) {
        product['hsn_sac_code'] = _linkedProductHsnCodes[i];
      } else if (_hsnControllers.containsKey(i)) {
        product['hsn_sac_code'] = _hsnControllers[i]!.text;
      }

      if (_selectedUnits.containsKey(i)) {
        product['unit_id'] = _selectedUnits[i];
      }
      if (_selectedGodowns.containsKey(i)) {
        product['godown_id'] = _selectedGodowns[i];
      }
      if (_selectedRacks.containsKey(i)) {
        product['rack_id'] = _selectedRacks[i];
      }

      if (_barcodeControllers.containsKey(i)) {
        product['barcode'] = _barcodeControllers[i]!.text;
      }

      if (_mfgDateControllers.containsKey(i) &&
          _mfgDateControllers[i]!.text.isNotEmpty) {
        product['manufactured_on_date'] = _mfgDateControllers[i]!.text;
      } else {
        product['manufactured_on_date'] = defaultMfgDate;
      }

      if (_expDateControllers.containsKey(i) &&
          _expDateControllers[i]!.text.isNotEmpty) {
        product['expiry_date'] = _expDateControllers[i]!.text;
      } else {
        product['expiry_date'] = '2050-01-01';
      }

      if (_quantityControllers.containsKey(i)) {
        product['quantity'] =
            double.tryParse(_quantityControllers[i]!.text) ??
            product['quantity'];
      }
      if (_costControllers.containsKey(i)) {
        product['rate'] =
            double.tryParse(_costControllers[i]!.text) ?? product['rate'];
      }
      if (_mrpControllers.containsKey(i)) {
        product['mrp'] =
            double.tryParse(_mrpControllers[i]!.text) ?? product['mrp'];
      }
      if (_sellControllers.containsKey(i)) {
        product['selling_price'] =
            double.tryParse(_sellControllers[i]!.text) ?? product['mrp'];
      }

      productsList[i] = product;
    }
    response['product_data'] = productsList;
    updatedData['response'] = response;
    return updatedData;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            _buildHeader(context),

            // Summary Preview Card (inspired by Coupon Preview)
            _buildSummaryPreview(),

            const SizedBox(height: 16),

            // Tab Bar
            _buildTabBar(),

            const SizedBox(height: 8),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildProductsList(), // Map to "Products" tab
                  _buildInvoiceDetails(), // Map to "Details" tab
                ],
              ),
            ),

            // Bottom Action Bar
            _buildBottomBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL VALUE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[500],
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${_totalEstimatedValue.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: Column(
              children: [
                Text(
                  _quantityControllers.length.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                  ),
                ),
                Text(
                  'ITEMS',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: const Color(0xFF0F172A),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_rounded, size: 16),
                SizedBox(width: 8),
                Text('Products'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_rounded, size: 16),
                SizedBox(width: 8),
                Text('Invoice Info'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    final response = widget.data['response'] ?? {};
    final productsList = response['product_data'] as List<dynamic>? ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          final leftItems = <Widget>[];
          final rightItems = <Widget>[];

          for (int i = 0; i < productsList.length; i++) {
            final product = productsList[i];
            final isLinked = _linkedProducts[i] ?? false;
            final item = _buildProductTicket(
              i,
              product['product_name'] ?? 'Unknown',
              isLinked,
            );
            if (i % 2 == 0) {
              leftItems.add(item);
            } else {
              rightItems.add(item);
            }
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: leftItems)),
                const SizedBox(width: 16),
                Expanded(child: Column(children: rightItems)),
              ],
            ),
          );
        } else {
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            itemCount: productsList.length,
            itemBuilder: (context, index) {
              final product = productsList[index];
              final isLinked = _linkedProducts[index] ?? false;
              return _buildProductTicket(
                index,
                product['product_name'] ?? 'Unknown',
                isLinked,
              );
            },
          );
        }
      },
    );
  }

  Widget _buildProductTicket(int index, String productName, bool isLinked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFF1F5F9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ),
          title: Text(
            isLinked && _linkedProductNames.containsKey(index)
                ? _linkedProductNames[index]!
                : productName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLinked && _linkedProductNames.containsKey(index))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        Icon(
                          Icons.swap_horiz_rounded,
                          size: 12,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            productName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[400],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildMiniTag(
                      'Qty: ${_quantityControllers[index]?.text}',
                      Colors.blue,
                    ),
                    _buildMiniTag(
                      'Rate: ${_costControllers[index]?.text}',
                      Colors.green,
                    ),
                    _buildMiniTag(
                      'MRP: ${_mrpControllers[index]?.text}',
                      Colors.orange,
                    ),
                  ],
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLinkControl(index, isLinked, productName),
              const SizedBox(width: 10),
              const Icon(
                Icons.expand_more_rounded,
                color: Color(0xFF94A3B8),
                size: 24,
              ),
            ],
          ),
          children: [
            const Divider(color: Color(0xFFF1F5F9), thickness: 1),
            const SizedBox(height: 16),
            // Form Fields
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    index,
                    _quantityControllers[index]!,
                    'Qty',
                    isNumber: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInput(
                    index,
                    _costControllers[index]!,
                    'Cost',
                    isNumber: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInput(
                    index,
                    _mrpControllers[index]!,
                    'MRP',
                    isNumber: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(index, 'Unit', _units, _selectedUnits),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInput(
                    index,
                    _sellControllers[index]!,
                    'Sell Price',
                    isNumber: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInput(index, _hsnControllers[index]!, 'HSN Code'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildDatePicker(index, 'Mfg Date', true)),
                const SizedBox(width: 12),
                Expanded(child: _buildDatePicker(index, 'Exp Date', false)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    index,
                    'Godown',
                    _godowns,
                    _selectedGodowns,
                    onChanged: (val) {
                      setState(() {
                        _selectedGodowns[index] = val;
                        // Reset rack selection when godown changes
                        _selectedRacks.remove(index);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    index,
                    'Rack',
                    _racks
                        .where(
                          (r) =>
                              r['godown']?.toString() ==
                              _selectedGodowns[index],
                        )
                        .toList(),
                    _selectedRacks,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInput(
              index,
              _barcodeControllers[index]!,
              'Barcode',
              suffixIcon: Icons.qr_code_rounded,
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _unlinkProduct(int index) {
    setState(() {
      _linkedProducts[index] = false;
      _linkedProductIds.remove(index);
      _linkedProductNames.remove(index);

      // Reset to original values if needed, or keep edited values
      // For now, we just remove the link status
    });
  }

  void _showLinkProductDialog(int index, String productName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductSearchSheet(
        storeId: widget.storeId,
        initialQuery: productName,
        onSelect: (product) {
          setState(() {
            _linkedProducts[index] = true;
            _linkedProductIds[index] =
                product['products_combination_template_id']?.toString() ??
                product['product_id']?.toString() ??
                product['id']?.toString() ??
                '';
            _linkedProductNames[index] =
                product['product_name'] ??
                product['product_combination_template_name'] ??
                'Unknown Product';

            // Auto-fill details from linked product
            if (product['selling_price'] != null) {
              _sellControllers[index]?.text = product['selling_price']
                  .toString();
            }
            if (product['mrp'] != null) {
              _mrpControllers[index]?.text = product['mrp'].toString();
            }
            if (product['barcode'] != null) {
              _barcodeControllers[index]?.text = product['barcode'].toString();
            }

            // Auto-fill HSN code from linked product's gst_data
            final gstData = product['gst_data'] as Map<String, dynamic>?;
            if (gstData != null && gstData['hsn_code'] != null) {
              _linkedProductHsnCodes[index] = gstData['hsn_code'].toString();
              _hsnControllers[index]?.text = gstData['hsn_code'].toString();
            }
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildLinkControl(int index, bool isLinked, String productName) {
    return GestureDetector(
      onTap: () {
        if (!isLinked) {
          _showLinkProductDialog(index, productName);
        } else {
          _unlinkProduct(index);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: isLinked
              ? const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isLinked ? null : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isLinked ? Colors.transparent : const Color(0xFFCBD5E1),
            width: 1.5,
          ),
          boxShadow: isLinked
              ? [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: isLinked
            ? const Icon(Icons.link_rounded, size: 20, color: Colors.white)
            : Icon(Icons.link_off_rounded, size: 20, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildInvoiceDetails() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildSectionTitle('Invoice Metadata'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildRawInput(
                _invoiceNumController,
                'Invoice Number',
                Icons.receipt_long_rounded,
              ),
              const SizedBox(height: 16),
              _buildRawInput(
                _invoiceDateController,
                'Invoice Date',
                Icons.calendar_today_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Supplier'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.store_rounded,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Supplier ID',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      widget.supplierStoreId ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildRawInput(
    TextEditingController controller,
    String label,
    IconData icon,
  ) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E293B),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[500],
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildMiniTag(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color[700],
        ),
      ),
    );
  }

  Widget _buildInput(
    int index,
    TextEditingController controller,
    String label, {
    bool isNumber = false,
    IconData? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 48,
          child: TextFormField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              suffixIcon: suffixIcon != null
                  ? Icon(suffixIcon, size: 16)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    int index,
    String label,
    List<Map<String, dynamic>> items,
    Map<int, String> selectionMap, {
    void Function(String)? onChanged,
  }) {
    final selectedValue = selectionMap[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.any((e) => e['id'].toString() == selectedValue)
                  ? selectedValue
                  : null,
              hint: Text(
                'Select',
                style: TextStyle(fontSize: 13, color: Colors.grey[400]),
              ),
              isExpanded: true,
              icon: const Icon(
                Icons.arrow_drop_down_rounded,
                color: Colors.grey,
              ),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item['id'].toString(),
                  child: Text(
                    item['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  if (onChanged != null) {
                    onChanged(val);
                  } else {
                    setState(() {
                      selectionMap[index] = val;
                    });
                  }
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(int index, String label, bool isMfg) {
    final controller = isMfg
        ? _mfgDateControllers[index]
        : _expDateControllers[index];
    final value = controller?.text ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _selectDate(context, index, isMfg),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value.isEmpty ? 'Select' : value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: value.isEmpty
                        ? Colors.grey[400]
                        : const Color(0xFF1E293B),
                  ),
                ),
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -10,
            child: Transform.rotate(
              angle: -math.pi / 6,
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 160,
                color: const Color(0xFFDBEAFE).withOpacity(0.5),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 12,
              16,
              20,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Purchase Entry',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'AI MODE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Edit & Verify',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.blueGrey[600],
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
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    // Check if all products are linked
    final response = widget.data['response'] ?? {};
    final productsList = List<dynamic>.from(response['product_data'] ?? []);
    bool allLinked = true;
    for (int i = 0; i < productsList.length; i++) {
      if (!_linkedProducts.containsKey(i) || _linkedProducts[i] != true) {
        allLinked = false;
        break;
      }
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: allLinked
            ? () {
                final updatedData = _getUpdatedData();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentInformationScreen(
                      data: updatedData,
                      storeId: widget.storeId,
                      supplierStoreId: widget.supplierStoreId,
                    ),
                  ),
                );
              }
            : () {
                final unlinkedProducts = <String>[];
                for (int i = 0; i < productsList.length; i++) {
                  if (!_linkedProducts.containsKey(i) ||
                      _linkedProducts[i] != true) {
                    final product = Map<String, dynamic>.from(productsList[i]);
                    unlinkedProducts.add(
                      product['product_name']?.toString() ?? 'Item ${i + 1}',
                    );
                  }
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Please link all products before continuing. Unlinked: ${unlinkedProducts.join(", ")}',
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: allLinked
                ? const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: allLinked ? null : Colors.grey[300],
            borderRadius: BorderRadius.circular(14),
            boxShadow: allLinked
                ? [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                allLinked ? 'Continue to Payment' : 'Link all the products',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: allLinked ? Colors.white : Colors.grey[600],
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                allLinked
                    ? Icons.arrow_forward_rounded
                    : Icons.link_off_rounded,
                color: allLinked ? Colors.white : Colors.grey[600],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductSearchSheet extends StatefulWidget {
  final String storeId;
  final String initialQuery;
  final Function(Map<String, dynamic>) onSelect;

  const _ProductSearchSheet({
    required this.storeId,
    required this.onSelect,
    this.initialQuery = '',
  });

  @override
  State<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<_ProductSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) {
      _searchController.text = widget.initialQuery;
      _performSearch(widget.initialQuery);
    } else {
      _loadInitialProducts();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialProducts() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response =
          await StoreOwnerApiService.searchProductCombinationTemplates(
            query: '',
            storeId: widget.storeId,
          );
      if (mounted) {
        setState(() {
          if (response['response'] != null) {
            _searchResults = List<Map<String, dynamic>>.from(
              response['response'],
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        _loadInitialProducts();
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response =
          await StoreOwnerApiService.searchProductCombinationTemplates(
            query: query,
            storeId: widget.storeId,
          );
      if (mounted) {
        setState(() {
          if (response['response'] != null) {
            _searchResults = List<Map<String, dynamic>>.from(
              response['response'],
            );
          } else {
            _searchResults = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Row(
              children: [
                const Icon(
                  Icons.link_rounded,
                  size: 24,
                  color: Color(0xFF1E293B),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Link Product',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Search and link existing product',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    padding: const EdgeInsets.all(8),
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
                decoration: InputDecoration(
                  hintText: 'Search product name...',
                  hintStyle: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[400],
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey[400],
                    size: 22,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFFFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
          // Results
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(strokeWidth: 3),
                        const SizedBox(height: 16),
                        Text(
                          'Searching...',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: Colors.grey[300],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'Type to search products'
                              : 'No products found',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final product = _searchResults[index];
                      final productName =
                          product['product_name'] ??
                          product['product_combination_template_name'] ??
                          'Unknown Product';
                      final imageUrl = product['img_url'];
                      final gstData =
                          product['gst_data'] as Map<String, dynamic>?;
                      final hsnCode = gstData?['hsn_code'] ?? '';
                      final cgst = gstData?['cgst_percent'] ?? 0;
                      final sgst = gstData?['sgst_percent'] ?? 0;
                      final igst = gstData?['igst_percent'] ?? 0;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => widget.onSelect(product),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product name + image row
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          image: imageUrl != null
                                              ? DecorationImage(
                                                  image: NetworkImage(imageUrl),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: imageUrl == null
                                            ? const Icon(
                                                Icons.shopping_bag_outlined,
                                                color: Color(0xFF3B82F6),
                                                size: 20,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          productName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Color(0xFF1E293B),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.link_rounded,
                                          color: Color(0xFF64748B),
                                          size: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Symmetrical row of 4 tags
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildInfoTag(
                                          'HSN: $hsnCode',
                                          Colors.blueGrey,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: _buildInfoTag(
                                          'CGST: $cgst%',
                                          Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildInfoTag(
                                          'SGST: $sgst%',
                                          Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: _buildInfoTag(
                                          'IGST: $igst%',
                                          Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Add New Product button
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Row(
                      children: [
                        Icon(
                          Icons.construction_rounded,
                          color: Colors.orange[700],
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        const Text('Coming Soon'),
                      ],
                    ),
                    content: const Text(
                      'This feature is currently under development. Stay tuned!',
                      style: TextStyle(fontSize: 15),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Got it'),
                      ),
                    ],
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: Colors.grey[500],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Can't find? Add New Product",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
