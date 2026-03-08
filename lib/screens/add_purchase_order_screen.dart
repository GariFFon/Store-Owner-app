import 'dart:io';
import 'dart:async';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:exanor/screens/create_store_dialog.dart';
import 'package:uuid/uuid.dart';

class AddPurchaseOrderScreen extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic>? aiData;

  const AddPurchaseOrderScreen({super.key, required this.storeId, this.aiData});

  @override
  State<AddPurchaseOrderScreen> createState() => _AddPurchaseOrderScreenState();
}

class _AddPurchaseOrderScreenState extends State<AddPurchaseOrderScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  int _currentStep = 0;

  // Supplier Search
  final TextEditingController _supplierSearchController =
      TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchingSupplier = false;
  Timer? _debounce;
  String? _selectedSupplierStoreId;

  // Product Search
  final TextEditingController _productSearchController =
      TextEditingController();
  List<Map<String, dynamic>> _productSearchResults = [];
  bool _isSearchingProduct = false;
  Timer? _productSearchDebounce;
  List<Map<String, dynamic>> _selectedProducts = [];

  // Data from APIs
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _godowns = [];
  List<Map<String, dynamic>> _racks = [];
  String? _defaultUnitId;

  // Controllers for products
  final List<TextEditingController> _barcodeControllers = [];

  // Form Data
  String? _selectedSupplier;
  DateTime? _purchaseDate = DateTime.now();
  final TextEditingController _invoiceIdController = TextEditingController();
  final TextEditingController _dateController = TextEditingController(
    text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
  );

  // Payment Data
  String _paymentStatus = 'Paid';
  final TextEditingController _transactionIdController =
      TextEditingController();
  final TextEditingController _amountPaidController = TextEditingController();
  final TextEditingController _paymentDueDateController =
      TextEditingController();
  DateTime? _paymentDueDate;
  String? _paymentMethodStoreBankId;
  List<Map<String, dynamic>> _storeBankAccounts = [];
  File? _invoiceFile;

  final List<String> _steps = ['Supplier', 'Products', 'Payment', 'Review'];
  final List<IconData> _stepIcons = [
    Icons.store_mall_directory_rounded,
    Icons.shopping_cart_rounded,
    Icons.payments_rounded,
    Icons.receipt_long_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _populateFromAiData();
  }

  void _searchSuppliers(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.isEmpty) {
      if (mounted)
        setState(() {
          _searchResults = [];
          _isSearchingSupplier = false;
        });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearchingSupplier = true);
      try {
        final results = await StoreOwnerApiService.searchStore(query);
        if (mounted)
          setState(() {
            _searchResults = results;
            _isSearchingSupplier = false;
          });
      } catch (e) {
        if (mounted)
          setState(() {
            _isSearchingSupplier = false;
            _searchResults = [];
          });
      }
    });
  }

  void _searchProducts(String query) {
    if (_productSearchDebounce?.isActive ?? false)
      _productSearchDebounce!.cancel();
    if (query.isEmpty) {
      if (mounted)
        setState(() {
          _productSearchResults = [];
          _isSearchingProduct = false;
        });
      return;
    }
    _productSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isSearchingProduct = true);
      try {
        final result =
            await StoreOwnerApiService.searchProductCombinationTemplates(
              query: query,
              storeId: widget.storeId,
            );
        if (mounted) {
          setState(() {
            // Handle both {response: [...]} and classic List[...] formats
            if (result.containsKey('response')) {
              final response = result['response'];
              if (response is List) {
                _productSearchResults = List<Map<String, dynamic>>.from(
                  response,
                );
              } else if (response is Map && response.containsKey('data')) {
                _productSearchResults = List<Map<String, dynamic>>.from(
                  response['data'],
                );
              } else {
                _productSearchResults = [];
              }
            } else {
              _productSearchResults = [];
            }
            _isSearchingProduct = false;
          });
        }
      } catch (e) {
        if (mounted)
          setState(() {
            _isSearchingProduct = false;
            _productSearchResults = [];
          });
      }
    });
  }

  void _addProduct(Map<String, dynamic> productTemplate) {
    setState(() {
      final String name =
          productTemplate['product_combination_template_name'] ??
          productTemplate['product_name'] ??
          productTemplate['name'] ??
          'Product Name';
      final String category = productTemplate['category_name'] ?? 'Category';
      final String? image =
          productTemplate['product_image'] ??
          productTemplate['image'] ??
          productTemplate['img_url'] ??
          productTemplate['product_combination_template_image'];
      final String barcode =
          productTemplate['barcode'] ??
          'AG-${const Uuid().v4().substring(0, 8).toUpperCase()}';

      _selectedProducts.add({
        ...productTemplate,
        'product_name': name,
        'category_name': category,
        'image': image,
        'quantity': 1.0,
        'unit_id':
            _defaultUnitId?.toString() ??
            (_units.isNotEmpty ? _units.first['id'].toString() : null),
        'mrp':
            double.tryParse(productTemplate['mrp']?.toString() ?? '0') ?? 0.0,
        'cost_price':
            double.tryParse(productTemplate['cost_price']?.toString() ?? '0') ??
            0.0,
        'selling_price':
            double.tryParse(
              productTemplate['selling_price']?.toString() ?? '0',
            ) ??
            0.0,
        'tax_inclusive': false,
        'mfg_date': null,
        'expiry_date': null,
        'godown_id': null,
        'rack_id': null,
        'barcode': barcode,
        'is_expanded': true,
      });
      _barcodeControllers.add(TextEditingController(text: barcode));
      _productSearchController.clear();
      _productSearchResults = [];
    });
  }

  void _removeProduct(int index) {
    setState(() {
      _selectedProducts.removeAt(index);
      _barcodeControllers[index].dispose();
      _barcodeControllers.removeAt(index);
    });
  }

  Future<void> _openCreateStoreDialog() async {
    final result = await showDialog(
      context: context,
      builder: (context) => CreateStoreDialog(storeId: widget.storeId),
    );
    if (result != null && result is Map<String, dynamic>) {
      if (mounted) {
        setState(() {
          _selectedSupplierStoreId = result['id'];
          final name = result['name'];
          final gst = result['gst_in'];
          final label = gst != null && gst.toString().isNotEmpty
              ? '$name ($gst)'
              : name;
          _supplierSearchController.text = name;
          _selectedSupplier = label;
          _searchResults = [];
        });
      }
    }
  }

  void _populateFromAiData() {
    if (widget.aiData != null) {
      final response = widget.aiData!['response'] ?? {};
      if (response['invoice_id'] != null) {
        _invoiceIdController.text = response['invoice_id'].toString();
      }
      if (response['invoice_date'] != null) {
        try {
          final dateStr = response['invoice_date'].toString();
          _dateController.text = dateStr;
          _purchaseDate = DateTime.tryParse(dateStr);
        } catch (e) {
          debugPrint('Error parsing invoice date: $e');
        }
      }
    }
  }

  Future<void> _fetchInitialData() async {
    try {
      final results = await Future.wait([
        StoreOwnerApiService.getUnits(widget.storeId),
        StoreOwnerApiService.getGodowns(widget.storeId),
        StoreOwnerApiService.getRacks(widget.storeId),
        StoreOwnerApiService.getStoreBankDetails(widget.storeId),
      ]);

      if (mounted) {
        setState(() {
          _units = results[0];
          _godowns = results[1];
          _racks = results[2];
          _storeBankAccounts = results[3];
          if (_units.isNotEmpty) {
            final defaultUnit = _units.firstWhere((u) {
              final name = (u['name']?.toString() ?? '').toLowerCase();
              return name.contains('pcs') ||
                  name.contains('pieces') ||
                  name.contains('piece');
            }, orElse: () => _units.first);
            _defaultUnitId = defaultUnit['id'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Colors.blue[800]!),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _purchaseDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  double _calculateTotalAmount() {
    double total = 0.0;
    for (var product in _selectedProducts) {
      final price =
          double.tryParse(product['cost_price']?.toString() ?? '0') ?? 0.0;
      final qty =
          double.tryParse(product['quantity']?.toString() ?? '0') ?? 0.0;
      final taxIncluded = product['tax_inclusive'] ?? false;

      double gstPercent = 0.0;
      final gstData = product['gst_data'];
      if (gstData != null && gstData is Map) {
        gstPercent =
            double.tryParse(gstData['igst_percent']?.toString() ?? '0') ?? 0.0;
      } else {
        gstPercent =
            double.tryParse(product['gst_rate']?.toString() ?? '0') ?? 0.0;
      }

      double lineTotal = price * qty;
      if (!taxIncluded) {
        lineTotal += (lineTotal * gstPercent / 100);
      }
      total += lineTotal;
    }
    return total;
  }

  Future<void> _submitPurchaseOrder() async {
    if (_selectedSupplierStoreId == null) {
      _showSnack('Supplier not selected.', Colors.red);
      setState(() => _currentStep = 0);
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final items = _selectedProducts.map((product) {
        final taxInclusive = product['tax_inclusive'] ?? false;
        final rate =
            double.tryParse(product['cost_price']?.toString() ?? '0') ?? 0.0;
        final itemMap = {
          'products_combination_template_id':
              product['id'] ?? product['products_combination_template_id'],
          'qty': double.tryParse(product['quantity']?.toString() ?? '0') ?? 0,
          'mrp': double.tryParse(product['mrp']?.toString() ?? '0') ?? 0.0,
          'selling_price_including_tax':
              double.tryParse(product['selling_price']?.toString() ?? '0') ??
              0.0,
          'godown_id': product['godown_id'],
          'rack_id': product['rack_id'],
          'unit_id': product['unit_id'],
          'barcode': product['barcode'],
          'manufactured_on_date': product['mfg_date'] is DateTime
              ? DateFormat('yyyy-MM-dd').format(product['mfg_date'])
              : product['mfg_date'] ?? '1999-01-01',
          'expiry_date': product['expiry_date'] is DateTime
              ? DateFormat('yyyy-MM-dd').format(product['expiry_date'])
              : product['expiry_date'] ?? '2050-01-01',
          'purchase_date': _dateController.text,
        };
        if (taxInclusive) {
          itemMap['cost_amount_including_tax'] = rate;
        } else {
          itemMap['cost_amount_excluding_tax'] = rate;
        }
        return itemMap;
      }).toList();

      String apiPaymentStatus = 'UNPAID';
      if (_paymentStatus == 'Paid')
        apiPaymentStatus = 'PAID';
      else if (_paymentStatus == 'Partial Payment')
        apiPaymentStatus = 'PARTIAL';

      final amountPaid = double.tryParse(_amountPaidController.text) ?? 0.0;

      final result = await StoreOwnerApiService.createPurchaseEntry(
        storeId: widget.storeId,
        purchasedFromStoreId: _selectedSupplierStoreId!,
        supplierInvoiceId: _invoiceIdController.text,
        date: _dateController.text,
        items: items,
        paymentStatus: apiPaymentStatus,
        amountPaid: amountPaid,
        paymentMethodStoreBankId: _paymentMethodStoreBankId,
      );

      if (mounted) {
        if (result['status'] == 200) {
          _showSnack('Purchase Order Created!', Colors.green);
          Navigator.pop(context);
        } else {
          _showSnack(result['message'] ?? 'Failed to create order', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Supplier
        if (_selectedSupplierStoreId == null) {
          _showSnack('Please select a supplier', Colors.orange);
          return false;
        }
        if (_invoiceIdController.text.trim().isEmpty) {
          _showSnack('Please enter an invoice number', Colors.orange);
          return false;
        }
        if (_dateController.text.trim().isEmpty) {
          _showSnack('Please select a purchase date', Colors.orange);
          return false;
        }
        return true;
      case 1: // Products
        if (_selectedProducts.isEmpty) {
          _showSnack('Please add at least one product', Colors.orange);
          return false;
        }
        for (int i = 0; i < _selectedProducts.length; i++) {
          final p = _selectedProducts[i];
          final name = p['product_name'] ?? 'Product ${i + 1}';
          final qty = double.tryParse(p['quantity']?.toString() ?? '0') ?? 0;
          final cost = double.tryParse(p['cost_price']?.toString() ?? '0') ?? 0;
          final selling =
              double.tryParse(p['selling_price']?.toString() ?? '0') ?? 0;
          if (qty <= 0) {
            _showSnack('$name: Quantity must be greater than 0', Colors.orange);
            return false;
          }
          if (cost <= 0) {
            _showSnack('$name: Cost price is required', Colors.orange);
            return false;
          }
          if (selling <= 0) {
            _showSnack('$name: Selling price is required', Colors.orange);
            return false;
          }
          if (p['godown_id'] == null) {
            _showSnack('$name: Please select a godown', Colors.orange);
            return false;
          }
        }
        return true;
      case 2: // Payment
        if (_paymentStatus != 'Credit' &&
            _amountPaidController.text.trim().isEmpty) {
          _showSnack('Please enter the amount paid', Colors.orange);
          return false;
        }
        if (_paymentMethodStoreBankId == null &&
            _storeBankAccounts.isNotEmpty) {
          _showSnack('Please select a payment method', Colors.orange);
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _pickInvoiceFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() => _invoiceFile = File(result.files.single.path!));
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  void dispose() {
    _invoiceIdController.dispose();
    _dateController.dispose();
    _supplierSearchController.dispose();
    _productSearchController.dispose();
    _transactionIdController.dispose();
    _debounce?.cancel();
    _productSearchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final horizontalPad = isTablet ? 24.0 : 16.0;
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
              )
            : Column(
                children: [
                  _buildHeader(theme, screenWidth),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPad,
                        vertical: 16,
                      ),
                      child: Center(child: _buildContentCard()),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: _buildBottomValues(),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, double width) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.15),
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
                Icons.receipt_long_rounded,
                size: 140,
                color: const Color(0xFFDBEAFE).withOpacity(0.6),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 20,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'New Purchase',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.5,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create and manage purchase entry',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.blueGrey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
                child: _buildSlidingStepper(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlidingStepper() {
    return Container(
      height: 56, // Increased height for better pill spacing
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment(
              -1.0 + (2.0 * _currentStep) / (_steps.length - 1),
              0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / _steps.length,
              heightFactor: 1.0,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: List.generate(_steps.length, (index) {
              final isSelected = index == _currentStep;
              final isCompleted = index < _currentStep;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (index <= _currentStep) {
                      setState(() => _currentStep = index);
                      return;
                    }
                    for (int s = _currentStep; s < index; s++) {
                      final savedStep = _currentStep;
                      _currentStep = s;
                      if (!_validateCurrentStep()) {
                        _currentStep = savedStep;
                        return;
                      }
                      _currentStep = savedStep;
                    }
                    setState(() => _currentStep = index);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!isSelected && isCompleted)
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Color(0xFF16A34A),
                          )
                        else
                          Icon(
                            _stepIcons[index],
                            size: 14,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF64748B),
                          ),
                        if (isSelected) ...[
                          const SizedBox(width: 4),
                          Text(
                            _steps[index],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // Removed unused Segmented Control logic

  Widget _buildContentCard() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: Container(
        key: ValueKey<int>(_currentStep),
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 800),
        child: _buildStepContent(),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildSupplierStep();
      case 1:
        return _buildProductsStep();
      case 2:
        return _buildPaymentStep();
      case 3:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // ==================== STEP 0: SUPPLIER ====================
  Widget _buildSupplierStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoCard(
          title: 'Supplier',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Search Supplier',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Search Input - premium style
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _supplierSearchController,
                  onChanged: _searchSuppliers,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter name or phone...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[400],
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    suffixIcon: _isSearchingSupplier
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          )
                        : (_supplierSearchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  onPressed: () {
                                    _supplierSearchController.clear();
                                    setState(() {
                                      _searchResults = [];
                                      _selectedSupplierStoreId = null;
                                      _selectedSupplier = null;
                                    });
                                  },
                                )
                              : null),
                  ),
                ),
              ),
              // Standalone Button Removed
              // Results Dropdown (Shows matches, or Create Option if no matches)
              if (_supplierSearchController.text.isNotEmpty &&
                  _selectedSupplier == null &&
                  (_searchResults.isNotEmpty || !_isSearchingSupplier))
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets
                          .zero, // Padding handled in items or container
                      itemCount: _searchResults.length + 1,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, i) {
                        // Create New Supplier Option (Always Last Item)
                        if (i == _searchResults.length) {
                          return Material(
                            color: Colors.white,
                            child: InkWell(
                              onTap: _openCreateStoreDialog,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEFF6FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add_rounded,
                                        color: Color(0xFF3B82F6),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Create New Supplier',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: Color(0xFF2563EB),
                                            ),
                                          ),
                                          if (_supplierSearchController
                                              .text
                                              .isNotEmpty)
                                            Text(
                                              'Name: "${_supplierSearchController.text}"',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF64748B),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        // Existing usage...
                        final s = _searchResults[i];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              (s['name'] ?? s['store_name'] ?? 'S')[0]
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          title: Text(
                            s['name'] ?? s['store_name'] ?? 'Unknown Store',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((s['address'] ??
                                      s['locality'] ??
                                      s['city']) !=
                                  null)
                                Text(
                                  [s['address'] ?? s['locality'], s['city']]
                                      .where(
                                        (e) =>
                                            e != null &&
                                            e.toString().isNotEmpty,
                                      )
                                      .join(', '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              if (s['gst_in'] != null &&
                                  s['gst_in'].toString().isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFBBF7D0),
                                    ),
                                  ),
                                  child: Text(
                                    'GSTIN: ${s['gst_in']}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF16A34A),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: Color(0xFF94A3B8),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedSupplierStoreId = s['id']?.toString();
                              _selectedSupplier = s['name'] ?? s['store_name'];
                              _supplierSearchController.text =
                                  _selectedSupplier ?? '';
                              _searchResults = [];
                              FocusScope.of(context).unfocus();
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildInfoCard(
          title: 'Invoice Details',
          child: Column(
            children: [
              TextField(
                controller: _invoiceIdController,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                decoration: _inputDeco(
                  'Invoice Number',
                  icon: Icons.receipt_rounded,
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: IgnorePointer(
                  child: TextField(
                    controller: _dateController,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: _inputDeco(
                      'Purchase Date',
                      icon: Icons.calendar_today_rounded,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _buildInfoCard(
          title: 'Invoice Document',
          child: InkWell(
            onTap: _pickInvoiceFile,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_invoiceFile != null) ...[
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 28,
                      color: Color(0xFF22C55E),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _invoiceFile!.path.split('/').last,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Change Invoice Button
                        GestureDetector(
                          onTap: _pickInvoiceFile,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.swap_horiz_rounded,
                                  size: 14,
                                  color: Color(0xFF3B82F6),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Change',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Remove Invoice Button
                        GestureDetector(
                          onTap: () {
                            setState(() => _invoiceFile = null);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 14,
                                  color: Color(0xFFEF4444),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Remove',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cloud_upload_outlined,
                        size: 24,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tap to upload invoice',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'PDF, JPG, PNG supported',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== STEP 1: PRODUCTS ====================
  Widget _buildProductsStep() {
    return Column(
      children: [
        // Innovative Search Bar
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _productSearchController,
            onChanged: _searchProducts,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Search products to add...',
              hintStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[400],
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF), // Light blue tint
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Color(0xFF3B82F6),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              suffixIcon: _isSearchingProduct
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue[300],
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),

        // Results Detached
        if (_productSearchResults.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(maxHeight: 320),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _productSearchResults.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                itemBuilder: (context, index) {
                  final prod = _productSearchResults[index];
                  // Display logic
                  final pName =
                      prod['product_combination_template_name'] ??
                      prod['product_name'] ??
                      prod['name'] ??
                      prod['title'] ??
                      'Unknown Item';
                  final pCode = prod['barcode'] ?? 'No Code';

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (pName.isNotEmpty ? pName[0] : 'P').toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          fontSize: 16,
                        ),
                      ),
                    ),
                    title: Text(
                      pName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: Text(
                      pCode,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    onTap: () => _addProduct(prod),
                  );
                },
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Added Products List - Redesigned
        if (_selectedProducts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 64,
                  color: Colors.grey[200],
                ),
                const SizedBox(height: 16),
                Text(
                  'No items added',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          ..._selectedProducts.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isOpen = item['is_expanded'] ?? false;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isOpen
                      ? const Color(0xFF3B82F6).withOpacity(0.3)
                      : Colors.transparent,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: Text(
                      item['product_name'] ?? 'Product Item',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: isOpen
                        ? null
                        : Text(
                            'Tap to edit details',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 20,
                          ),
                          onPressed: () => _removeProduct(index),
                        ),
                        Icon(
                          isOpen
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: const Color(0xFF64748B),
                        ),
                      ],
                    ),
                    onTap: () => setState(() => item['is_expanded'] = !isOpen),
                  ),

                  // Expanded Details
                  if (isOpen) ...[
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Quantity Row
                          Row(
                            children: [
                              const Icon(
                                Icons.format_list_numbered_rounded,
                                size: 16,
                                color: Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'QUANTITY & UNIT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blueGrey[400],
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildModernField(
                                  'Quantity',
                                  initialValue:
                                      (item['quantity'] == 0 ||
                                          item['quantity'] == 0.0)
                                      ? ''
                                      : item['quantity'].toString(),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    setState(
                                      () => item['quantity'] =
                                          double.tryParse(v) ?? 0,
                                    );
                                  },
                                  hint: '0',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: _buildModernDropdown(
                                  label: 'Unit',
                                  value: item['unit_id']?.toString(),
                                  items: _units.map<DropdownMenuItem<String>>((
                                    u,
                                  ) {
                                    return DropdownMenuItem(
                                      value: u['id'].toString(),
                                      child: Text(u['name'] ?? 'Unit'),
                                    );
                                  }).toList(),
                                  onChanged: (v) =>
                                      setState(() => item['unit_id'] = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Pricing Row
                          Row(
                            children: [
                              const Icon(
                                Icons.currency_rupee,
                                size: 16,
                                color: Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'PRICING DETAILS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blueGrey[400],
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildModernField(
                                  'MRP',
                                  initialValue:
                                      (item['mrp'] == 0 || item['mrp'] == 0.0)
                                      ? ''
                                      : item['mrp'].toString(),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    setState(
                                      () =>
                                          item['mrp'] = double.tryParse(v) ?? 0,
                                    );
                                  },
                                  hint: '0',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildModernField(
                                  'Cost',
                                  initialValue:
                                      (item['cost_price'] == 0 ||
                                          item['cost_price'] == 0.0)
                                      ? ''
                                      : item['cost_price'].toString(),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    setState(
                                      () => item['cost_price'] =
                                          double.tryParse(v) ?? 0,
                                    );
                                  },
                                  hint: '0',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildModernField(
                                  'Selling',
                                  initialValue:
                                      (item['selling_price'] == 0 ||
                                          item['selling_price'] == 0.0)
                                      ? ''
                                      : item['selling_price'].toString(),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    setState(
                                      () => item['selling_price'] =
                                          double.tryParse(v) ?? 0,
                                    );
                                  },
                                  hint: '0',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => setState(
                              () => item['tax_inclusive'] =
                                  !(item['tax_inclusive'] ?? false),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  (item['tax_inclusive'] ?? false)
                                      ? Icons.check_box_rounded
                                      : Icons.check_box_outline_blank_rounded,
                                  color: const Color(0xFF3B82F6),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Price includes tax',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blueGrey[700],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          const SizedBox(height: 24),

                          // Storage & Extras
                          Row(
                            children: [
                              const Icon(
                                Icons.inventory_2_rounded,
                                size: 16,
                                color: Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'STORAGE & OTHER',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blueGrey[400],
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildModernDropdown(
                                  label: 'Godown',
                                  value: item['godown_id']?.toString(),
                                  items: _godowns.map<DropdownMenuItem<String>>(
                                    (g) {
                                      return DropdownMenuItem(
                                        value: g['id'].toString(),
                                        child: Text(g['name']),
                                      );
                                    },
                                  ).toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      item['godown_id'] = v;
                                      // Reset rack selection when godown changes
                                      item['rack_id'] = null;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildModernDropdown(
                                  label: 'Rack',
                                  value: item['rack_id']?.toString(),
                                  items: _racks
                                      .where(
                                        (r) =>
                                            r['godown']?.toString() ==
                                            item['godown_id']?.toString(),
                                      )
                                      .map<DropdownMenuItem<String>>((r) {
                                        return DropdownMenuItem(
                                          value: r['id'].toString(),
                                          child: Text(r['name']),
                                        );
                                      })
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => item['rack_id'] = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Dates & Barcode (in Grid or Column)
                          _buildModernField(
                            'Barcode (Auto-generated if empty)',
                            controller: _barcodeControllers[index],
                            onChanged: (v) => item['barcode'] = v,
                            suffix: GestureDetector(
                              onTap: () {
                                final newBarcode =
                                    'AG-${const Uuid().v4().substring(0, 8).toUpperCase()}';
                                setState(() {
                                  item['barcode'] = newBarcode;
                                  _barcodeControllers[index].text = newBarcode;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.autorenew_rounded,
                                  size: 16,
                                  color: Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildModernField(
                                  'Mfg Date',
                                  controller: TextEditingController(
                                    text: item['mfg_date'] is DateTime
                                        ? DateFormat(
                                            'yyyy-MM-dd',
                                          ).format(item['mfg_date'])
                                        : (item['mfg_date']?.toString() ?? ''),
                                  ),
                                  readOnly: true,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null)
                                      setState(() => item['mfg_date'] = picked);
                                  },
                                  hint: 'Select',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildModernField(
                                  'Exp Date',
                                  controller: TextEditingController(
                                    text: item['expiry_date'] is DateTime
                                        ? DateFormat(
                                            'yyyy-MM-dd',
                                          ).format(item['expiry_date'])
                                        : (item['expiry_date']?.toString() ??
                                              ''),
                                  ),
                                  readOnly: true,
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime(2050),
                                    );
                                    if (picked != null)
                                      setState(
                                        () => item['expiry_date'] = picked,
                                      );
                                  },
                                  hint: 'Select',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  // ==================== STEP 2: PAYMENT ====================
  Widget _buildPaymentStep() {
    final total = _calculateTotalAmount();
    final paid = double.tryParse(_amountPaidController.text) ?? 0;
    final due = total - paid;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[500]!],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Payable',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Net Amount',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Text(
                '₹${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildInfoCard(
          title: 'Payment Status',
          child: Column(
            children: [
              Row(
                children: [
                  _buildPaymentStatusOption('Paid', Colors.green),
                  const SizedBox(width: 8),
                  _buildPaymentStatusOption('Partial Payment', Colors.orange),
                  const SizedBox(width: 8),
                  _buildPaymentStatusOption('Credit', Colors.red),
                ],
              ),
              const SizedBox(height: 20),
              if (_paymentStatus != 'Credit')
                _buildModernField(
                  'Amount Paid (₹)',
                  controller: _amountPaidController,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() {}),
                  icon: Icons.currency_rupee,
                  hint: 'Enter amount...',
                ),
              if (_paymentStatus != 'Paid') ...[
                const SizedBox(height: 16),
                _buildModernField(
                  'Payment Due Date',
                  controller: _paymentDueDateController,
                  readOnly: true,
                  icon: Icons.calendar_month_outlined,
                  hint: 'Select Date',
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _paymentDueDate = picked;
                        _paymentDueDateController.text = DateFormat(
                          'yyyy-MM-dd',
                        ).format(picked);
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Remaining Due: ₹${due.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: 'Payment Details',
          child: Column(
            children: [
              _buildModernDropdown(
                label: 'Payment Method',
                value: _paymentMethodStoreBankId,
                items: _storeBankAccounts.map<DropdownMenuItem<String>>((b) {
                  return DropdownMenuItem(
                    value: b['id'].toString(),
                    child: Text(
                      b['account_number_or_upi_id'] == 'CASH-IN-HAND'
                          ? 'Cash'
                          : '${b['bank_name']} - ${b['account_number']}',
                    ),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _paymentMethodStoreBankId = v),
                icon: Icons.account_balance,
              ),
              const SizedBox(height: 16),
              _buildModernField(
                'Transaction ID (Optional)',
                controller: _transactionIdController,
                icon: Icons.receipt,
                hint: 'Enter transaction ID...',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== STEP 3: REVIEW ====================
  Widget _buildReviewStep() {
    return _buildStep4Summary(
      Theme.of(context),
    ); // Re-using existing summary logic but wrapped slightly
  }

  // Helper Widget for Cards
  Widget _buildInfoCard({required String title, required Widget child}) {
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
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Color(0xFF64748B),
      ),
      floatingLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF3B82F6),
      ),
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: const Color(0xFF94A3B8))
          : null,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
  }

  Widget _buildPaymentStatusOption(String status, Color color) {
    final isSelected = _paymentStatus == status;
    final IconData icon;
    switch (status) {
      case 'Paid':
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'Partial Payment':
        icon = Icons.pie_chart_outline_rounded;
        break;
      default:
        icon = Icons.schedule_rounded;
    }
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _paymentStatus = status;
            if (_paymentStatus == 'Paid') {
              _amountPaidController.text = _calculateTotalAmount()
                  .toStringAsFixed(2);
            } else if (_paymentStatus == 'Credit') {
              _amountPaidController.clear();
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withOpacity(0.08)
                : const Color(0xFFF8FAFC),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? color : const Color(0xFF94A3B8),
              ),
              const SizedBox(height: 3),
              Text(
                status == 'Partial Payment' ? 'Partial' : status,
                style: TextStyle(
                  color: isSelected ? color : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // The persistent bottom bar
  Widget _buildBottomValues() {
    final total = _calculateTotalAmount();
    final isLastStep = _currentStep == _steps.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Total Display
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Next / Submit Button
            GestureDetector(
              onTap: _isSubmitting
                  ? null
                  : () {
                      if (isLastStep) {
                        _submitPurchaseOrder();
                      } else {
                        if (!_validateCurrentStep()) return;
                        setState(() {
                          _currentStep++;
                          if (_currentStep == 2 && _paymentStatus == 'Paid') {
                            _amountPaidController.text = _calculateTotalAmount()
                                .toStringAsFixed(2);
                          }
                        });
                      }
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isLastStep
                        ? [const Color(0xFF16A34A), const Color(0xFF22C55E)]
                        : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isLastStep
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF3B82F6))
                              .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLastStep
                          ? 'Submit'
                          : (_currentStep == _steps.length - 2
                                ? 'Review'
                                : 'Next'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_isSubmitting)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    else
                      Icon(
                        isLastStep
                            ? Icons.check_circle_rounded
                            : Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- REUSED SUMMARY COMPONENTS (Copied from original logic) ---
  Widget _buildStep4Summary(ThemeData theme) {
    final total = _calculateTotalAmount();
    final paid = double.tryParse(_amountPaidController.text) ?? 0.0;
    final due = (total - paid).clamp(0.0, double.infinity);

    // Find payment method name
    String paymentMethodName = 'Not selected';
    if (_paymentMethodStoreBankId != null) {
      final bank = _storeBankAccounts.firstWhere(
        (b) => b['id'].toString() == _paymentMethodStoreBankId,
        orElse: () => {},
      );
      if (bank.isNotEmpty) {
        paymentMethodName = bank['account_number_or_upi_id'] == 'CASH-IN-HAND'
            ? 'Cash'
            : '${bank['bank_name']} - ${bank['account_number']}';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Supplier Information ---
        _buildSummaryCard(
          title: 'Supplier & Invoice',
          icon: Icons.store_mall_directory_rounded,
          content: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF3B82F6),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedSupplier ?? _supplierSearchController.text,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Invoice: ${_invoiceIdController.text.isNotEmpty ? _invoiceIdController.text : 'N/A'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Date',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      Text(
                        _dateController.text.isNotEmpty
                            ? _dateController.text
                            : 'N/A',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_invoiceFile != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.attach_file_rounded,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _invoiceFile!.path.split('/').last.split('\\').last,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3B82F6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          onEdit: () => setState(() => _currentStep = 0),
        ),
        const SizedBox(height: 16),
        // --- Products ---
        _buildSummaryCard(
          title: 'Items (${_selectedProducts.length})',
          icon: Icons.shopping_bag_outlined,
          content: Column(
            children: _selectedProducts.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final qty =
                  double.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
              final cost =
                  double.tryParse(item['cost_price']?.toString() ?? '0') ?? 0;
              final lineTotal = qty * cost;
              final unitName =
                  _units.firstWhere(
                    (u) => u['id'].toString() == item['unit_id']?.toString(),
                    orElse: () => {'name': ''},
                  )['name'] ??
                  '';

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: i < _selectedProducts.length - 1
                      ? const Border(
                          bottom: BorderSide(color: Color(0xFFF1F5F9)),
                        )
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['product_name'] ?? 'Product',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${qty.toString().replaceAll(RegExp(r'\.0$'), '')} $unitName x ₹$cost',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${lineTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          onEdit: () => setState(() => _currentStep = 1),
        ),
        const SizedBox(height: 16),
        // --- Payment Details ---
        _buildSummaryCard(
          title: 'Payment Summary',
          icon: Icons.receipt_long_rounded,
          content: Column(
            children: [
              _buildReviewRow(
                'Total Amount',
                '₹${total.toStringAsFixed(2)}',
                isBold: true,
                valueColor: const Color(0xFF0F172A),
              ),
              const SizedBox(height: 12),
              _buildReviewRow(
                'Paid Amount',
                '₹${paid.toStringAsFixed(2)}',
                valueColor: const Color(0xFF16A34A),
              ),
              if (due > 0) ...[
                const SizedBox(height: 12),
                _buildReviewRow(
                  'Due Amount',
                  '₹${due.toStringAsFixed(2)}',
                  valueColor: const Color(0xFFF59E0B),
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFFE2E8F0)),
              ),
              _buildReviewRow(
                'Status',
                _paymentStatus,
                isBadge: true,
                badgeColor: _paymentStatus == 'Paid'
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEF3C7),
                badgeTextColor: _paymentStatus == 'Paid'
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFD97706),
              ),
              const SizedBox(height: 12),
              _buildReviewRow('Method', paymentMethodName),
              if (_transactionIdController.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildReviewRow(
                  'Transaction ID',
                  _transactionIdController.text,
                ),
              ],
              if (_paymentDueDate != null) ...[
                const SizedBox(height: 12),
                _buildReviewRow(
                  'Due Date',
                  DateFormat('dd MMM yyyy').format(_paymentDueDate!),
                ),
              ],
            ],
          ),
          onEdit: () => setState(() => _currentStep = 2),
        ),
      ],
    );
  }

  Widget _buildReviewRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
    bool isBadge = false,
    Color? badgeColor,
    Color? badgeTextColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor ?? const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badgeTextColor ?? const Color(0xFF475569),
              ),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required IconData icon,
    required Widget content,
    VoidCallback? onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: const Color(0xFF3B82F6)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (onEdit != null)
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          size: 12,
                          color: Color(0xFF3B82F6),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B82F6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          content,
        ],
      ),
    );
  }

  Widget _buildModernField(
    String label, {
    String? initialValue,
    TextEditingController? controller,
    String? hint,
    ValueChanged<String>? onChanged,
    TextInputType? keyboardType,
    IconData? icon,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: IgnorePointer(
              ignoring: onTap != null,
              child: TextFormField(
                controller: controller,
                initialValue: controller == null ? initialValue : null,
                readOnly: readOnly,
                keyboardType: keyboardType,
                onChanged: onChanged,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[400],
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  suffixIcon: suffix,
                  isDense: true,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: const Color(0xFF64748B)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items,
              onChanged: onChanged,
              isExpanded: true,
              icon: const Icon(
                Icons.arrow_drop_down_rounded,
                color: const Color(0xFF64748B),
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              hint: const Text(
                'Select',
                style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
