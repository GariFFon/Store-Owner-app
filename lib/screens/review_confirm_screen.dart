import 'package:flutter/material.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:intl/intl.dart';

class ReviewConfirmScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String paymentStatus;
  final String? transactionId;
  final String? dueDate;
  final String storeId;
  final String? supplierStoreId;

  const ReviewConfirmScreen({
    super.key,
    required this.data,
    required this.paymentStatus,
    required this.storeId,
    this.transactionId,
    this.dueDate,
    this.supplierStoreId,
  });

  @override
  State<ReviewConfirmScreen> createState() => _ReviewConfirmScreenState();
}

class _ReviewConfirmScreenState extends State<ReviewConfirmScreen> {
  double _totalAmount = 0.0;
  int _totalProducts = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _calculateTotals();
  }

  void _calculateTotals() {
    final response = widget.data['response'] ?? {};
    final productsList = response['product_data'] as List<dynamic>? ?? [];

    _totalProducts = productsList.length;
    _totalAmount = 0.0;

    for (var product in productsList) {
      final quantity =
          double.tryParse(product['quantity']?.toString() ?? '0') ?? 0.0;
      final rate = double.tryParse(product['rate']?.toString() ?? '0') ?? 0.0;
      _totalAmount += quantity * rate;
    }
  }

  /// Convert various date formats to ISO format (YYYY-MM-DD)
  String _formatDateToISO(String dateStr) {
    if (dateStr.isEmpty) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }

    // Already in ISO format
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
      return dateStr;
    }

    // Try parsing various formats
    final formats = [
      'dd-MMM-yyyy', // 23-Jun-2020
      'dd/MM/yyyy', // 23/06/2020
      'MM/dd/yyyy', // 06/23/2020
      'dd-MM-yyyy', // 23-06-2020
      'yyyy/MM/dd', // 2020/06/23
      'MMM dd, yyyy', // Jun 23, 2020
      'd-MMM-yyyy', // 3-Jun-2020 (single digit day)
    ];

    for (var format in formats) {
      try {
        final date = DateFormat(format).parse(dateStr);
        return DateFormat('yyyy-MM-dd').format(date);
      } catch (e) {
        // Try next format
      }
    }

    // If all parsing fails, return today's date
    debugPrint('⚠️ Could not parse date: $dateStr, using today\'s date');
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void> _submitPurchaseEntry() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = widget.data['response'] ?? {};
      final productsList = response['product_data'] as List<dynamic>? ?? [];

      // Get store ID
      final storeId = widget.storeId;

      // Get supplier store ID from the passed parameter
      final purchasedFromStoreId = widget.supplierStoreId ?? '';

      // Get invoice ID from response
      final supplierInvoiceId = response['invoice_id']?.toString() ?? '';

      // Get invoice date and convert to ISO format
      final rawInvoiceDate = response['invoice_date']?.toString() ?? '';
      final invoiceDate = _formatDateToISO(rawInvoiceDate);

      // Build items array from product data
      final List<Map<String, dynamic>> items = [];
      for (var product in productsList) {
        final quantity =
            double.tryParse(product['quantity']?.toString() ?? '0') ?? 0.0;
        final rate = double.tryParse(product['rate']?.toString() ?? '0') ?? 0.0;
        final mrp = double.tryParse(product['mrp']?.toString() ?? '0') ?? rate;

        items.add({
          'products_combination_template_id':
              product['products_combination_template_id']?.toString() ?? '',
          'qty': quantity.toInt(),
          'cost_amount_including_tax': rate,
          'mrp': mrp,
          'selling_price_including_tax':
              product['selling_price']?.toString() ?? mrp.toString(),
          'godown_id': product['godown_id']?.toString() ?? '',
          'rack_id': product['rack_id']?.toString() ?? '',
          'unit_id': product['unit_id']?.toString() ?? '',
          'barcode': product['barcode']?.toString() ?? '',
          'manufactured_on_date':
              product['manufactured_on_date']?.toString() ?? '1999-01-01',
          'expiry_date': product['expiry_date']?.toString() ?? '2050-01-01',
          'purchase_date': invoiceDate,
        });
      }

      // Map payment status to API format
      String apiPaymentStatus;
      switch (widget.paymentStatus.toLowerCase()) {
        case 'paid':
          apiPaymentStatus = 'PAID';
          break;
        case 'partially paid':
          apiPaymentStatus = 'PARTIAL';
          break;
        default:
          apiPaymentStatus = 'UNPAID';
      }

      // Call the API
      final result = await StoreOwnerApiService.createPurchaseEntry(
        storeId: storeId,
        purchasedFromStoreId: purchasedFromStoreId,
        supplierInvoiceId: supplierInvoiceId,
        date: invoiceDate,
        items: items,
        paymentStatus: apiPaymentStatus,
        amountPaid: apiPaymentStatus == 'PAID' ? _totalAmount : 0,
      );

      if (mounted) {
        if (result.isNotEmpty && result['status'] == 200) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase entry created successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back to the first screen (purchase list)
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          // Show error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message']?.toString() ??
                    'Failed to create purchase entry',
              ),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final response = widget.data['response'] ?? {};
    final supplierData = response['supplier_details'] ?? {};
    final productsList = response['product_data'] as List<dynamic>? ?? [];

    // Extract supplier information with correct field names
    final supplierName = supplierData['supplier_name'] ?? 'N/A';
    final supplierGst = supplierData['supplier_gst_in'] ?? 'N/A';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Column(
        children: [
          // Black Header
          Container(
            color: Colors.black,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 16,
              left: 20,
              right: 20,
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review & Confirm',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Review all details before submitting',
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
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
                  _buildProgressChip('Upload Invoice', true, false),
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  _buildProgressChip('Supplier Details', true, false),
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  _buildProgressChip('Product Data Mapping', true, false),
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  _buildProgressChip('Payment Information', true, false),
                  const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                  _buildProgressChip('Confirmation', true, true),
                ],
              ),
            ),
          ),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Header Section with Back and Submit buttons
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
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
                    child: Row(
                      children: [
                        // Back Button
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: const BorderSide(color: Colors.black),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_back,
                                  color: Colors.black,
                                  size: 18,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Back',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Center Text
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              const Text(
                                'Review & Confirm',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Verify details',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Submit Button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : _submitPurchaseEntry,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.auto_awesome, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'Submit',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Success Icon and Title
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(32),
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
                      children: [
                        // Green checkmark
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Review Your Purchase Order',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please verify all details before submitting',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Supplier Information Section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
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
                        const Text(
                          'Supplier Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Name',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              supplierName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'GST IN',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              supplierGst,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Products Section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
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
                        Text(
                          'Products ($_totalProducts)',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...productsList.map((product) {
                          return _buildProductItem(
                            product['product_name'] ?? 'Unknown Product',
                            product['quantity']?.toString() ?? '0',
                            product['rate']?.toString() ?? '0',
                          );
                        }).toList(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Payment Information Section
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
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
                        const Text(
                          'Payment Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Status',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: widget.paymentStatus == 'Paid'
                                    ? Colors.green[50]
                                    : widget.paymentStatus == 'Partially Paid'
                                    ? Colors.orange[50]
                                    : Colors.red[50],
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.paymentStatus.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: widget.paymentStatus == 'Paid'
                                      ? Colors.green[700]
                                      : widget.paymentStatus == 'Partially Paid'
                                      ? Colors.orange[700]
                                      : Colors.red[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₹${_totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        if (widget.transactionId != null &&
                            widget.transactionId!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Transaction ID',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                widget.transactionId!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (widget.dueDate != null &&
                            widget.dueDate!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Due Date',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                widget.dueDate!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(String name, String quantity, String cost) {
    final qty = double.tryParse(quantity) ?? 0.0;
    final price = double.tryParse(cost) ?? 0.0;
    final total = qty * price;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Qty: ${qty.toStringAsFixed(0)} | Cost: ₹${total.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Exists',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.green[700],
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
}
