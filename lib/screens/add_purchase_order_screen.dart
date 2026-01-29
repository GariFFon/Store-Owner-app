import 'dart:io';
import 'dart:async';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:exanor/screens/create_store_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:exanor/screens/simple_scanner_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';

class AddPurchaseOrderScreen extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic>? aiData;

  const AddPurchaseOrderScreen({super.key, required this.storeId, this.aiData});

  @override
  State<AddPurchaseOrderScreen> createState() => _AddPurchaseOrderScreenState();
}

class _AddPurchaseOrderScreenState extends State<AddPurchaseOrderScreen> {
  bool _isLoading = true;
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
  String? _defaultUnitId; // Store default unit ID

  // Controllers for products
  final List<TextEditingController> _barcodeControllers = [];

  // Form Data
  String? _selectedSupplier;
  DateTime? _purchaseDate;
  final TextEditingController _invoiceIdController = TextEditingController();

  final TextEditingController _dateController = TextEditingController();

  // Payment Data
  String _paymentStatus = 'Paid';
  final TextEditingController _transactionIdController =
      TextEditingController();
  final TextEditingController _amountPaidController =
      TextEditingController(); // For Partial
  final TextEditingController _paymentDueDateController =
      TextEditingController(); // For Credit/Partial
  DateTime? _paymentDueDate;
  String? _paymentMethodStoreBankId;
  List<Map<String, dynamic>> _storeBankAccounts = [];
  File? _invoiceFile;

  final List<String> _steps = [
    'Basic information',
    'Add products',
    'Add payment data',
    'Confirmation',
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
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearchingSupplier = false;
        });
      }
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() {
        _isSearchingSupplier = true;
      });

      try {
        final results = await StoreOwnerApiService.searchStore(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearchingSupplier = false;
          });
        }
      } catch (e) {
        debugPrint('Error searching supplier: $e');
        if (mounted) {
          setState(() {
            _isSearchingSupplier = false;
            _searchResults = [];
          });
        }
      }
    });
  }

  void _searchProducts(String query) {
    if (_productSearchDebounce?.isActive ?? false)
      _productSearchDebounce!.cancel();

    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _productSearchResults = [];
          _isSearchingProduct = false;
        });
      }
      return;
    }

    _productSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() {
        _isSearchingProduct = true;
      });

      try {
        final result =
            await StoreOwnerApiService.searchProductCombinationTemplates(
              query: query,
              storeId: widget.storeId,
            );

        if (mounted) {
          setState(() {
            // Assuming the structure is result['response'] is the list
            if (result['response'] != null) {
              _productSearchResults = List<Map<String, dynamic>>.from(
                result['response'],
              );
            } else {
              _productSearchResults = [];
            }
            _isSearchingProduct = false;
          });
        }
      } catch (e) {
        debugPrint('Error searching products: $e');
        if (mounted) {
          setState(() {
            _isSearchingProduct = false;
            _productSearchResults = [];
          });
        }
      }
    });
  }

  void _addProduct(Map<String, dynamic> productTemplate) {
    setState(() {
      // Normalize data
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

      // Auto-generate barcode if not present
      final String barcode =
          productTemplate['barcode'] ??
          'AG-${const Uuid().v4().substring(0, 8).toUpperCase()}';

      _selectedProducts.add({
        ...productTemplate,
        'product_name': name,
        'category_name': category,
        'image': image,
        'quantity': 1, // Default quantity
        'unit_id':
            _defaultUnitId ?? (_units.isNotEmpty ? _units.first['id'] : null),
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

          debugPrint('Fetched Units: $_units');
          debugPrint('Fetched Godowns: $_godowns');
          debugPrint('Fetched Racks: $_racks');
          debugPrint('Fetched Bank Accounts: $_storeBankAccounts');

          // Set default unit to PCS/Pieces if available
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
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _purchaseDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  void dispose() {
    _invoiceIdController.dispose();
    _dateController.dispose();
    _supplierSearchController.dispose();
    _supplierSearchController.dispose();
    _productSearchController.dispose();
    _transactionIdController.dispose();
    _debounce?.cancel();
    _productSearchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: const TranslatedText(
          'Back to Purchase List',
          style: TextStyle(fontSize: 14, color: Colors.blue),
        ),
        titleSpacing: 0,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.blue),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: isWide
                      ? Column(
                          children: [
                            _buildHorizontalStepper(theme),
                            const SizedBox(height: 32),
                            Expanded(child: _buildCurrentStepContent(theme)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildHorizontalStepper(theme),
                            const SizedBox(height: 24),
                            _buildCurrentStepContent(theme),
                          ],
                        ),
                );
              },
            ),
    );
  }

  Widget _buildHorizontalStepper(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(_steps.length, (index) {
              final isActive = index == _currentStep;
              final isCompleted = index < _currentStep;
              final isLast = index == _steps.length - 1;

              return Expanded(
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isActive || isCompleted
                                ? Colors.blue
                                : Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: isCompleted ? Colors.blue : Colors.grey[300],
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_steps.length, (index) {
              final isActive = index == _currentStep;
              return Expanded(
                child: Text(
                  _steps[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? Colors.blue : theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Purchase Order',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _steps[_currentStep],
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 600;
            return Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Build content based on current step
                  if (_currentStep == 0)
                    _buildStep1Form(theme)
                  else if (_currentStep == 1)
                    _buildStep2AddProducts(theme)
                  else if (_currentStep == 2)
                    _buildStep3PaymentData(theme)
                  else
                    const SizedBox.shrink(),

                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_currentStep > 0)
                        TextButton(
                          onPressed: () => setState(() => _currentStep--),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                          ),
                          child: const Text('Previous'),
                        ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          if (_currentStep < _steps.length - 1) {
                            setState(() => _currentStep++);
                          } else {
                            // Submit logic
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _currentStep == _steps.length - 1 ? 'Submit' : 'Next',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStep3PaymentData(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add payment data',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 24),

        // Payment Status & Transaction ID
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(Icons.payment, 'Payment Status'),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown(
                      label: 'Payment Status * *',
                      value: _paymentStatus,
                      items: ['Paid', 'Credit', 'Partial Payment']
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _paymentStatus = val;
                          if (val == 'Paid') {
                            _amountPaidController.text = _calculateTotalAmount()
                                .toStringAsFixed(2);
                          } else if (val == 'Credit') {
                            _amountPaidController.clear();
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      label: 'Transaction ID (Optional)',
                      onChanged: (val) {}, // Controller used directly
                      controller: _transactionIdController,
                    ),
                  ),
                ],
              ),

              if (_paymentStatus == 'Partial Payment' ||
                  _paymentStatus == 'Paid') ...[
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.4,
                      child: _buildTextField(
                        label: 'Amount Paid (₹) * *',
                        onChanged: (v) {
                          setState(() {}); // refresh to update calculations
                        },
                        keyboardType: TextInputType.number,
                        controller: _amountPaidController,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: ₹${_calculateTotalAmount().toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        if (_paymentStatus == 'Credit' ||
            _paymentStatus == 'Partial Payment') ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F0), // Light orange bg like in image
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE0B2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_filled,
                      color: Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Credit Payment Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 4,
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 30),
                            ),
                            firstDate:
                                DateTime.now(), // Due date can't be in past
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
                          child: _buildTextField(
                            label: 'Payment Due Date * *',
                            onChanged: (v) {},
                            controller: _paymentDueDateController,
                          ),
                        ),
                      ),
                    ),
                    if (_paymentStatus == 'Partial Payment' ||
                        _paymentStatus == 'Credit') ...[
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE0B2).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orange.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Amount Due (₹)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calculate,
                                    size: 16,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '₹ ${_calculateDueAmount().toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Auto-calculated: Total - Amount Paid',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Payment Method
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                Icons.account_balance,
                'Select Payment Method',
              ),
              _buildDropdown(
                label: 'Payment Method * *',
                value: _paymentMethodStoreBankId,
                items: _storeBankAccounts.map((bank) {
                  final isCash =
                      bank['account_number_or_upi_id'] == 'CASH-IN-HAND';
                  return DropdownMenuItem(
                    value: bank['id'],
                    child: Row(
                      children: [
                        Icon(
                          isCash
                              ? Icons.account_balance_wallet_outlined
                              : Icons.account_balance,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        if (isCash) ...[
                          const Text('CASH-IN-HAND'),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ] else ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                bank['bank_name'] ?? 'Bank',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (bank['account_number'] != null)
                                Text(
                                  bank['account_number'].toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
                selectedItemBuilder: (context) {
                  return _storeBankAccounts.map<Widget>((bank) {
                    final isCash =
                        bank['account_number_or_upi_id'] == 'CASH-IN-HAND';
                    return Row(
                      children: [
                        Text(
                          isCash
                              ? 'CASH-IN-HAND'
                              : (bank['bank_name'] ?? 'Bank'),
                          style: const TextStyle(color: Colors.black),
                        ),
                        if (isCash) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  }).toList();
                },
                onChanged: (val) =>
                    setState(() => _paymentMethodStoreBankId = val),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Invoice Document
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(Icons.description, 'Invoice Document'),
              InkWell(
                onTap: _pickInvoiceFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_invoiceFile != null) ...[
                        const Icon(
                          Icons.check_circle,
                          size: 48,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _invoiceFile!.path.split('/').last,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.upload_file,
                            size: 24,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Click to upload invoice',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Supports: PNG, JPG, PDF (Max 10MB)',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickInvoiceFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _invoiceFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      debugPrint('Error picking invoice file: $e');
    }
  }

  double _calculateTotalAmount() {
    double total = 0.0;
    for (var product in _selectedProducts) {
      // Parse buying price (cost_price)
      final price =
          double.tryParse(product['cost_price']?.toString() ?? '0') ?? 0.0;
      final qty =
          double.tryParse(product['quantity']?.toString() ?? '0') ?? 0.0;

      // Handle tax
      final taxIncluded = product['tax_inclusive'] ?? false;
      double gstPercent = 0.0;

      // Logic copied from product card display
      final gstData = product['gst_data'];
      if (gstData != null && gstData is Map) {
        gstPercent =
            double.tryParse(gstData['igst_percent']?.toString() ?? '0') ?? 0.0;
      } else {
        gstPercent =
            double.tryParse(product['gst_rate']?.toString() ?? '0') ?? 0.0;
      }

      double lineTotal = price * qty;

      // If tax is NOT included in the price input, we add it to the total
      // If tax IS included, the price input is the final price, so no modification needed for total pay
      // Wait, usually "Price including tax" means the entered price is final.
      // "Amount excludes tax" means we need to add tax.
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

  Widget _buildStep1Form(ThemeData theme) {
    // Keep existing implementation for Step 1
    final response = widget.aiData?['response'] ?? {};
    final supplierDetails = response['supplier_details'] ?? {};
    final addressDetails = supplierDetails['supplier_address_details'] ?? {};

    final hasAiData = widget.aiData != null && supplierDetails.isNotEmpty;
    final supplierName = supplierDetails['supplier_name'] ?? '';
    final supplierGst = supplierDetails['supplier_gst_in'] ?? '';
    final legalName =
        supplierDetails['supplier_legal_business_name'] ?? supplierName;

    final addressParts = [
      addressDetails['supplier_address_line_1'],
      addressDetails['supplier_address_line_2'],
      addressDetails['supplier_locality'],
      addressDetails['supplier_city'],
      addressDetails['supplier_state'],
      addressDetails['supplier_pincode']?.toString(),
    ].where((e) => e != null && e.isNotEmpty).join(', ');

    final gstRegistrationType =
        supplierDetails['supplier_gst_registration_type']
            ?.toString()
            .toLowerCase() ??
        'regular';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasAiData) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI Extracted Supplier Information',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Supplier Name',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  supplierName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'GST IN',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  supplierGst,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (addressParts.isNotEmpty) ...[
                  const Text(
                    'Address',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  Text(addressParts, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                ],
                ElevatedButton.icon(
                  onPressed: () async {
                    // Copied creation logic
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    );
                    try {
                      final pin =
                          int.tryParse(
                            addressDetails['supplier_pincode']?.toString() ??
                                '',
                          ) ??
                          0;

                      final result = await StoreOwnerApiService.registerStore(
                        storeId: widget.storeId,
                        storeName: supplierName,
                        legalName: legalName,
                        city: addressDetails['supplier_city'] ?? '',
                        state: addressDetails['supplier_state'] ?? '',
                        pin: pin,
                        isGstEnabled: supplierGst.isNotEmpty,
                        gstIn: supplierGst,
                        gstRegisteredState:
                            addressDetails['supplier_state'] ?? '',
                        gstRegistrationType: gstRegistrationType,
                        area: addressDetails['supplier_locality'] ?? '',
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        if (result.isNotEmpty && result['status'] == 200) {
                          setState(() {
                            _selectedSupplier = '$supplierName ($supplierGst)';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result['message'] ?? 'Supplier created!',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to create supplier'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Create Supplier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _supplierSearchController,
              onChanged: _searchSuppliers,
              decoration: InputDecoration(
                labelText: 'Pick a supplier',
                hintText: _selectedSupplier,
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey,
                ),
              ),
            ),
            if (_searchResults.isNotEmpty ||
                _isSearchingSupplier ||
                (!_isSearchingSupplier &&
                    _supplierSearchController.text.isNotEmpty &&
                    _searchResults.isEmpty &&
                    _selectedSupplier != _supplierSearchController.text))
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSearchingSupplier)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: LinearProgressIndicator()),
                      ),
                    if (_searchResults.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _searchResults.length,
                          separatorBuilder: (ctx, i) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final store = _searchResults[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                store['store_name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${store['gst_in'] ?? 'No GST'} • ${store['city'] ?? ''}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedSupplierStoreId = store['store_id'];
                                  _supplierSearchController.text =
                                      store['store_name'];
                                  _selectedSupplier = store['store_name'];
                                  _searchResults = [];
                                });
                              },
                            );
                          },
                        ),
                      ),
                    if (!_isSearchingSupplier &&
                        _supplierSearchController.text.isNotEmpty &&
                        _searchResults.isEmpty &&
                        _selectedSupplier != _supplierSearchController.text)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'No suppliers found',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _openCreateStoreDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('+ Add New Store'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: 24),
        InkWell(
          onTap: _selectDate,
          child: IgnorePointer(
            child: TextField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: 'Purchase Date *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _invoiceIdController,
          decoration: InputDecoration(
            labelText: 'Supplier Invoice Id *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // --- Step 2: Add Products Implementation ---

  Widget _buildStep2AddProducts(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar
        Column(
          children: [
            TextField(
              controller: _productSearchController,
              onChanged: _searchProducts,
              decoration: InputDecoration(
                hintText: 'Search products',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
            // Search Results Overlay
            if (_productSearchResults.isNotEmpty || _isSearchingProduct)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade200),
                ),
                constraints: const BoxConstraints(maxHeight: 300),
                child: _isSearchingProduct
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _productSearchResults.length,
                        separatorBuilder: (ctx, i) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = _productSearchResults[index];
                          debugPrint(
                            'Product Search Result Item: $product',
                          ); // DEBUG PRINT

                          // Correctly map the fields based on API response
                          final name =
                              product['product_combination_template_name'] ??
                              product['product_name'] ??
                              product['name'] ??
                              'Product Name';
                          final category =
                              product['category_name'] ?? 'Category';
                          final image =
                              product['product_image'] ??
                              product['image'] ??
                              product['img_url'] ??
                              product['product_combination_template_image'];

                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: image != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        image,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                              Icons.image_not_supported,
                                              size: 20,
                                              color: Colors.grey,
                                            ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.image,
                                      size: 20,
                                      color: Colors.grey,
                                    ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'quantity: ${product['quantity'] ?? '1'} ${product['unit_name'] ?? product['unit'] ?? 'Pc'}',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    Builder(
                                      builder: (context) {
                                        final parentName =
                                            product['parent_category_name'] ??
                                            product['parent_category'] ??
                                            product['parent_cat_name'];
                                        final childName =
                                            product['child_category_name'] ??
                                            product['child_category'] ??
                                            product['child_cat_name'];

                                        final chips = <Widget>[];

                                        if (parentName != null &&
                                            parentName.toString().isNotEmpty) {
                                          chips.add(
                                            _buildCategoryChip(
                                              parentName.toString(),
                                            ),
                                          );
                                        }
                                        if (childName != null &&
                                            childName.toString().isNotEmpty) {
                                          chips.add(
                                            _buildCategoryChip(
                                              childName.toString(),
                                            ),
                                          );
                                        }

                                        // Fallback to generic category if no specific ones found
                                        if (chips.isEmpty &&
                                            category != 'Category') {
                                          chips.add(
                                            _buildCategoryChip(category),
                                          );
                                        }

                                        return Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: chips,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: const Icon(
                              Icons.add_circle,
                              color: Colors.blue,
                            ),
                            onTap: () => _addProduct(product),
                          );
                        },
                      ),
              ),
          ],
        ),

        const SizedBox(height: 32),

        if (_selectedProducts.isEmpty)
          _buildEmptyProductState()
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected Products (${_selectedProducts.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              ..._selectedProducts.asMap().entries.map((entry) {
                return _buildProductCard(entry.key, entry.value, theme);
              }).toList(),
            ],
          ),
      ],
    );
  }

  Widget _buildEmptyProductState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(
              'No products added yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'Search and add products to start building your purchase order',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(
    int index,
    Map<String, dynamic> product,
    ThemeData theme,
  ) {
    // Determine card state (expanded or not)
    final bool isExpanded = product['is_expanded'] ?? false;
    final String name =
        product['product_name'] ?? product['name'] ?? 'Product Name';
    final String category = product['category_name'] ?? 'Category';
    // Mock image for now or use network image if available
    final String? imageUrl = product['image'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header (Always Visible)
          InkWell(
            onTap: () {
              setState(() {
                product['is_expanded'] = !isExpanded;
              });
            },
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: Radius.circular(isExpanded ? 0 : 12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_not_supported,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : const Icon(Icons.image, color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          category,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'MRP: N/A',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Builder(
                                builder: (context) {
                                  // Extract GST info
                                  var gstPercent = 0.0;
                                  final gstData = product['gst_data'];
                                  if (gstData != null && gstData is Map) {
                                    gstPercent =
                                        double.tryParse(
                                          gstData['igst_percent']?.toString() ??
                                              '0',
                                        ) ??
                                        0.0;
                                  } else {
                                    gstPercent =
                                        double.tryParse(
                                          product['gst_rate']?.toString() ??
                                              '0',
                                        ) ??
                                        0.0;
                                  }

                                  return Text(
                                    'GST: ${gstPercent.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[700],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    onPressed: () => _removeProduct(index),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          if (isExpanded) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FD).withOpacity(0.5),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quantity Section
                  _buildSectionHeader(Icons.bar_chart, 'Quantity'),
                  _buildTextField(
                    label: 'Quantity * *',
                    onChanged: (val) => product['quantity'] = val,
                    keyboardType: TextInputType.number,
                    initialValue: product['quantity']?.toString(),
                  ),
                  const SizedBox(height: 16),
                  _buildDropdown(
                    label: 'Unit * *',
                    value: product['unit_id'],
                    items: _units.isEmpty
                        ? [
                            const DropdownMenuItem(
                              value: null,
                              child: Text(
                                'No units found',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ]
                        : _units.map((u) {
                            final name = u['name']?.toString() ?? '';
                            final shortName =
                                u['short_name']?.toString() ??
                                u['code']?.toString() ??
                                u['symbol']?.toString() ??
                                name;
                            return DropdownMenuItem(
                              value: u['id'],
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      shortName,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (shortName.toLowerCase() !=
                                        name.toLowerCase())
                                      Text(
                                        name,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                    selectedItemBuilder: (BuildContext context) {
                      return _units.map<Widget>((u) {
                        final name = u['name']?.toString() ?? '';
                        final shortName =
                            u['short_name']?.toString() ??
                            u['code']?.toString() ??
                            u['symbol']?.toString() ??
                            name;
                        return Text(
                          '$shortName - $name',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList();
                    },
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => product['unit_id'] = val);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Pricing Section
                  _buildSectionHeader(
                    Icons.monetization_on_outlined,
                    'Pricing',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'MRP (₹) * *',
                          onChanged: (v) {},
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          label: 'Cost Price (₹)...',
                          onChanged: (v) => product['cost_price'] = v,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          label: 'Selling Price (...',
                          onChanged: (v) => product['selling_price'] = v,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Tax Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Switch(
                        value: product['tax_inclusive'] ?? false,
                        onChanged: (val) =>
                            setState(() => product['tax_inclusive'] = val),
                        activeColor: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        (product['tax_inclusive'] ?? false)
                            ? 'Price including tax'
                            : 'Amount excludes tax',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Dates
                  _buildSectionHeader(Icons.calendar_today, 'Dates'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateField(
                          label: 'Manufacturing Date',
                          value: product['mfg_date'],
                          onSelect: (d) =>
                              setState(() => product['mfg_date'] = d),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDateField(
                          label: 'Expiry Date',
                          value: product['expiry_date'],
                          onSelect: (d) =>
                              setState(() => product['expiry_date'] = d),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Storage Location
                  _buildSectionHeader(
                    Icons.inventory_2_outlined,
                    'Storage Location',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: 'Select Godown * *',
                          value: product['godown_id'],
                          items: _godowns.isEmpty
                              ? [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text(
                                      'No godowns found',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ]
                              : _godowns
                                    .map(
                                      (g) => DropdownMenuItem(
                                        value: g['id'],
                                        child: Text(
                                          g['name'] ?? '',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          onChanged: (val) {
                            if (val != null)
                              setState(() => product['godown_id'] = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDropdown(
                          label: 'Select Rack (Optional)',
                          value: product['rack_id'],
                          items: _racks.isEmpty
                              ? [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text(
                                      'No racks found',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                ]
                              : _racks
                                    .map(
                                      (r) => DropdownMenuItem(
                                        value: r['id'],
                                        child: Text(
                                          r['name'] ?? '',
                                          style: const TextStyle(
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          onChanged: (val) {
                            if (val != null)
                              setState(() => product['rack_id'] = val);
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Barcode
                  _buildSectionHeader(Icons.qr_code, 'Barcode'),
                  TextField(
                    controller: _barcodeControllers[index],
                    decoration: InputDecoration(
                      hintText: 'Barcode',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.qr_code_scanner,
                          color: Colors.blue,
                        ),
                        onPressed: () => _scanBarcode(index),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                    onChanged: (val) => product['barcode'] = val,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _scanBarcode(int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SimpleScannerScreen()),
    );

    if (result != null && result is String) {
      if (mounted) {
        setState(() {
          _barcodeControllers[index].text = result;
          _selectedProducts[index]['barcode'] = result;
        });
      }
    }
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required Function(String) onChanged,
    TextInputType? keyboardType,
    String? initialValue,
    TextEditingController? controller, // Add this
  }) {
    return TextFormField(
      controller: controller, // Use it
      initialValue: controller != null
          ? null
          : initialValue, // initialValue and controller cannot be both set
      onChanged: onChanged,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required dynamic value,
    required List<DropdownMenuItem<dynamic>> items,
    required Function(dynamic) onChanged,
    List<Widget> Function(BuildContext)? selectedItemBuilder, // Add this
  }) {
    return DropdownButtonFormField(
      value: value,
      items: items,
      selectedItemBuilder: selectedItemBuilder, // Pass it here
      onChanged: onChanged,
      isExpanded: true,
      isDense: true,
      // itemHeight: null, // Let it be null for flexible height
      dropdownColor: Colors.white, // Ensure white background
      style: const TextStyle(
        color: Colors.black,
      ), // Ensure selected item text is black
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
    );
  }

  Widget _buildCategoryChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.blue[700],
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required Function(DateTime) onSelect,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onSelect(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        child: Text(
          value != null ? DateFormat('yyyy-MM-dd').format(value) : '',
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}

class IntelligenceUploadDialog extends StatefulWidget {
  final String storeId;
  const IntelligenceUploadDialog({super.key, required this.storeId});

  @override
  State<IntelligenceUploadDialog> createState() =>
      _IntelligenceUploadDialogState();
}

class _IntelligenceUploadDialogState extends State<IntelligenceUploadDialog> {
  File? _selectedFile;
  bool _isAnalyzing = false;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          _selectedFile = File(photo.path);
        });
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error accessing camera: $e')));
      }
    }
  }

  Future<void> _analyzeWithAi() async {
    if (_selectedFile == null) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      Position? position;
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('Location services are disabled.');
        } else {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }

          if (permission == LocationPermission.denied) {
            debugPrint('Location permissions are denied');
          } else if (permission == LocationPermission.deniedForever) {
            debugPrint('Location permissions are permanently denied');
          } else {
            position = await Geolocator.getLastKnownPosition();
            position ??= await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.medium,
              timeLimit: const Duration(seconds: 5),
            );
          }
        }
      } catch (e) {
        debugPrint('Error getting location: $e');
      }

      final lat = position?.latitude ?? 0.0;
      final lng = position?.longitude ?? 0.0;

      final result = await StoreOwnerApiService.uploadPurchaseInvoice(
        widget.storeId,
        _selectedFile!,
        lat,
        lng,
      );

      if (mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Analysis failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAnalyzing) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(32),
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Analyzing with AI...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI is processing your data...',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 24),
              LinearProgressIndicator(backgroundColor: Colors.grey[200]),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '35% Complete',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    'Step 2 of 4',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white),
                  const SizedBox(width: 8),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Invoice',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Upload and analyze your purchase invoice',
                        style: TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Container(color: Colors.white, height: 1),
            Flexible(
              child: SingleChildScrollView(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upload Invoice',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Upload a PDF, JPG, or PNG file of your purchase invoice',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _pickFile,
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey[300]!,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[50],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_selectedFile != null) ...[
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    _selectedFile!.path.split('/').last,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TextButton.icon(
                                      onPressed: _pickFile,
                                      icon: const Icon(
                                        Icons.upload_file,
                                        size: 18,
                                      ),
                                      label: const Text("Change File"),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: _takePhoto,
                                      icon: const Icon(
                                        Icons.camera_alt,
                                        size: 18,
                                      ),
                                      label: const Text("Retake Photo"),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                const Icon(
                                  Icons.cloud_upload,
                                  color: Colors.grey,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Click to upload or drag and drop',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'PDF, JPG, or PNG (Max 10MB)',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.camera_alt, color: Colors.black),
                        label: const Text(
                          'Take Photo',
                          style: TextStyle(color: Colors.black),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          side: const BorderSide(color: Colors.black),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CANCEL'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _selectedFile != null
                                ? _analyzeWithAi
                                : null,
                            icon: const Icon(Icons.auto_awesome, size: 16),
                            label: const Text('Analyze with AI'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
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
}
