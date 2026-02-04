import 'dart:io';
import 'dart:async';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
        'cost_price': 0.0,
        'selling_price': 0.0,
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

  double _calculateDueAmount() {
    final total = _calculateTotalAmount();
    final paid = double.tryParse(_amountPaidController.text) ?? 0.0;
    return (total - paid).clamp(0.0, double.infinity);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: Colors.blueGrey[800]),
        title: Text(
          'New Purchase',
          style: TextStyle(
            color: Colors.blueGrey[800],
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  _buildSegmentedControl(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: _buildContentCard(),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomValues(),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        width: double.infinity,
        height: 56, // Slightly taller for better touch targets
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: List.generate(_steps.length, (index) {
            final isSelected = index == _currentStep;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (index > 0 &&
                      _selectedSupplierStoreId == null &&
                      index > _currentStep) {
                    _showSnack('Select Supplier first', Colors.orange);
                    return;
                  }
                  setState(() => _currentStep = index);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _stepIcons[index],
                        size: 16,
                        color: isSelected ? Colors.blue[700] : Colors.grey[500],
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Text(
                          _steps[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.blue[700],
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
      ),
    );
  }

  Widget _buildContentCard() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
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
          title: 'Who are we buying from?',
          child: Column(
            children: [
              // Search Input
              TextField(
                controller: _supplierSearchController,
                onChanged: _searchSuppliers,
                decoration: InputDecoration(
                  labelText: 'Search Supplier',
                  hintText: 'Enter name or phone...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  suffixIcon: _isSearchingSupplier
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_supplierSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
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
              const SizedBox(height: 16),
              // Prominent Create Supplier Button
              if (_selectedSupplier == null)
                InkWell(
                  onTap: _openCreateStoreDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[100]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Create New Supplier',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_searchResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ..._searchResults.map(
                        (s) => ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[50],
                            child: Text(
                              (s['name'] ?? s['store_name'] ?? 'S')[0]
                                  .toUpperCase(),
                              style: TextStyle(color: Colors.blue[700]),
                            ),
                          ),
                          title: Text(
                            s['name'] ?? s['store_name'] ?? 'Unknown Store',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'ID: ${s['id']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            setState(() {
                              _selectedSupplierStoreId = s['id']?.toString();
                              _selectedSupplier = s['name'] ?? s['store_name'];
                              _supplierSearchController.text =
                                  _selectedSupplier ?? '';
                              _searchResults = [];
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: 'Invoice Details',
          child: Column(
            children: [
              TextField(
                controller: _invoiceIdController,
                decoration: InputDecoration(
                  labelText: 'Invoice Number',
                  prefixIcon: const Icon(Icons.receipt_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: IgnorePointer(
                  child: TextField(
                    controller: _dateController,
                    decoration: InputDecoration(
                      labelText: 'Purchase Date',
                      prefixIcon: const Icon(Icons.calendar_today_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoCard(
          title: 'Invoice Document',
          child: InkWell(
            onTap: _pickInvoiceFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[300]!,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_invoiceFile != null) ...[
                    const Icon(
                      Icons.check_circle,
                      size: 32,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _invoiceFile!.path.split('/').last,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Change Invoice Button
                        ElevatedButton.icon(
                          onPressed: _pickInvoiceFile,
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: const Text('Change'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Remove Invoice Button
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() => _invoiceFile = null);
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Remove'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 32,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to upload invoice',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PDF, JPG, PNG',
                      style: TextStyle(color: Colors.grey[400], fontSize: 10),
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
        // Search Product Bar
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
            ],
          ),
          child: TextField(
            controller: _productSearchController,
            onChanged: _searchProducts,
            decoration: InputDecoration(
              hintText: 'Search products to add...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              suffixIcon: _isSearchingProduct
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
          ),
        ),

        // Search Results
        if (_productSearchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _productSearchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final prod = _productSearchResults[index];
                return ListTile(
                  title: Text(
                    prod['product_combination_template_name'] ??
                        prod['product_name'] ??
                        prod['name'] ??
                        'Unknown Item',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(prod['barcode'] ?? 'No Barcode'),
                  trailing: const Icon(Icons.add_circle, color: Colors.blue),
                  onTap: () => _addProduct(prod),
                );
              },
            ),
          ),

        const SizedBox(height: 24),

        // Added Products List
        if (_selectedProducts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No products added yet',
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),
              ],
            ),
          )
        else
          ...List.generate(_selectedProducts.length, (index) {
            final item = _selectedProducts[index];
            final isOpen = item['is_expanded'] ?? false;
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                  ),
                ],
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  // Card Header
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: item['image'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item['image'],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.image),
                              ),
                            )
                          : const Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.grey,
                            ),
                    ),
                    title: Text(
                      item['product_name'] ?? 'Product',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Qty: ${item['quantity']} • ₹${item['cost_price']}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _removeProduct(index),
                        ),
                        IconButton(
                          icon: Icon(
                            isOpen
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                          ),
                          onPressed: () =>
                              setState(() => item['is_expanded'] = !isOpen),
                        ),
                      ],
                    ),
                  ),

                  // Expanded Details
                  if (isOpen)
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: Column(
                        children: [
                          const Divider(),
                          const SizedBox(height: 12),
                          Row(
                            // Qty & Price
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: item['quantity'].toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDeco('Quantity'),
                                  onChanged: (v) {
                                    setState(
                                      () => item['quantity'] =
                                          double.tryParse(v) ?? 0,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: item['unit_id']
                                      ?.toString(), // Ensure this matches an item value or is null
                                  decoration: _inputDeco('Unit'),
                                  items: _units.map<DropdownMenuItem<String>>((
                                    u,
                                  ) {
                                    return DropdownMenuItem(
                                      value: u['id'].toString(),
                                      child: Text(u['name'] ?? 'Unknown'),
                                    );
                                  }).toList(),
                                  onChanged: (v) =>
                                      setState(() => item['unit_id'] = v),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: item['cost_price'].toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDeco('Cost Price'),
                                  onChanged: (v) {
                                    setState(
                                      () => item['cost_price'] =
                                          double.tryParse(v) ?? 0,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  initialValue: item['selling_price']
                                      .toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDeco('Selling Price'),
                                  onChanged: (v) {
                                    setState(
                                      () => item['selling_price'] =
                                          double.tryParse(v) ?? 0,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Tax Included in Price?',
                              style: TextStyle(fontSize: 14),
                            ),
                            value: item['tax_inclusive'] ?? false,
                            onChanged: (v) =>
                                setState(() => item['tax_inclusive'] = v),
                          ),
                          const SizedBox(height: 12),
                          const SizedBox(height: 12),
                          // Godown & Rack (Stacked for better space)
                          DropdownButtonFormField<String>(
                            value: item['godown_id']?.toString(),
                            decoration: _inputDeco(
                              'Godown',
                              icon: Icons.warehouse_rounded,
                            ),
                            items: _godowns.map<DropdownMenuItem<String>>((g) {
                              return DropdownMenuItem(
                                value: g['id'].toString(),
                                child: Text(g['name']),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => item['godown_id'] = v),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: item['rack_id']?.toString(),
                            decoration: _inputDeco('Rack', icon: Icons.shelves),
                            items: _racks.map<DropdownMenuItem<String>>((r) {
                              return DropdownMenuItem(
                                value: r['id'].toString(),
                                child: Text(r['name']),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => item['rack_id'] = v),
                          ),
                        ],
                      ),
                    ),
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
                TextField(
                  controller: _amountPaidController,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Amount Paid',
                    prefixIcon: const Icon(Icons.currency_rupee),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              if (_paymentStatus != 'Paid') ...[
                const SizedBox(height: 16),
                InkWell(
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
                  child: IgnorePointer(
                    child: TextField(
                      controller: _paymentDueDateController,
                      decoration: _inputDeco(
                        'Payment Due Date',
                        icon: Icons.calendar_month_outlined,
                      ),
                    ),
                  ),
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
                        'Remaining Due: ₹${_calculateDueAmount().toStringAsFixed(2)}',
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
              DropdownButtonFormField<String>(
                decoration: _inputDeco(
                  'Payment Method',
                  icon: Icons.account_balance,
                ),
                value: _paymentMethodStoreBankId,
                items: _storeBankAccounts
                    .map(
                      (b) => DropdownMenuItem(
                        value: b['id'].toString(),
                        child: Text(
                          b['account_number_or_upi_id'] == 'CASH-IN-HAND'
                              ? 'Cash'
                              : '${b['bank_name']} - ${b['account_number']}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _paymentMethodStoreBankId = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _transactionIdController,
                decoration: _inputDeco(
                  'Transaction ID (Optional)',
                  icon: Icons.receipt,
                ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
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
      prefixIcon: icon != null ? Icon(icon) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildPaymentStatusOption(String status, Color color) {
    final isSelected = _paymentStatus == status;
    return Expanded(
      child: InkWell(
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.white,
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            status,
            style: TextStyle(
              color: isSelected ? color : Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // The persistent bottom bar
  Widget _buildBottomValues() {
    // We show this bar on ALL steps, adjusting the button action/text
    // The previous logic hid it on the last step, but now we want Main Button here.

    final total = _calculateTotalAmount();
    final isLastStep = _currentStep == _steps.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Total Display
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TOTAL PAYABLE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '₹${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),

            // Next / Submit Button
            InkWell(
              onTap: _isSubmitting
                  ? null
                  : () {
                      if (_currentStep == 0 &&
                          _selectedSupplierStoreId == null) {
                        _showSnack('Please select a supplier', Colors.red);
                        return;
                      }
                      if (isLastStep) {
                        _submitPurchaseOrder();
                      } else {
                        setState(() => _currentStep++);
                      }
                    },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isLastStep
                        ? [
                            Colors.green[700]!,
                            Colors.green[500]!,
                          ] // Green for Submit
                        : [
                            const Color(0xFF0F172A),
                            const Color(0xFF334155),
                          ], // Slate for Next
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isLastStep ? Colors.green : const Color(0xFF0F172A))
                              .withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLastStep
                          ? 'Submit Order'
                          : (_currentStep == _steps.length - 2
                                ? 'Review Order'
                                : 'Next Step'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_isSubmitting)
                      const SizedBox(
                        width: 20,
                        height: 20,
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
                        size: 20,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryCard(
          title: 'Supplier Information',
          icon: Icons.person_outline,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryField(
                'Supplier Name',
                _selectedSupplier ?? _supplierSearchController.text,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryField(
                      'Invoice ID',
                      _invoiceIdController.text,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryField(
                      'Purchase Date',
                      _dateController.text,
                    ),
                  ),
                ],
              ),
            ],
          ),
          onEdit: () => setState(() => _currentStep = 0),
        ),
        const SizedBox(height: 16),
        _buildSummaryCard(
          title: 'Products (${_selectedProducts.length})',
          icon: Icons.inventory_2_outlined,
          content: Column(
            children: _selectedProducts
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item['product_name']} (x${item['quantity']})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₹${(double.tryParse(item['cost_price'].toString()) ?? 0) * (double.tryParse(item['quantity'].toString()) ?? 0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          onEdit: () => setState(() => _currentStep = 1),
        ),
        const SizedBox(height: 16),
        _buildSummaryCard(
          title: 'Payment Details',
          icon: Icons.payment_outlined,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow('Payment Status', _paymentStatus, isBadge: true),
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Total Amount',
                '₹${_calculateTotalAmount().toStringAsFixed(2)}',
                isBold: true,
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(
                'Amount Paid',
                '₹${_amountPaidController.text}',
                isBold: true,
                color: Colors.green,
              ),
            ],
          ),
          onEdit: () => setState(() => _currentStep = 2),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                ),
            ],
          ),
          const Divider(),
          content,
        ],
      ),
    );
  }

  Widget _buildSummaryField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
    bool isBadge = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[700])),
        if (isBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: value == 'Paid' ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: value == 'Paid' ? Colors.green : Colors.orange,
                fontSize: 12,
              ),
            ),
          )
        else
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black87,
            ),
          ),
      ],
    );
  }
}
