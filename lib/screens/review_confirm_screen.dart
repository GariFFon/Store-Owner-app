import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

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

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _calculateTotals();
  }

  void _calculateTotals() {
    final response = widget.data['response'] ?? {};
    final productsList = response['product_data'] as List<dynamic>? ?? [];

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

    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
      return dateStr;
    }

    final formats = [
      'dd-MMM-yyyy',
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'dd-MM-yyyy',
      'yyyy/MM/dd',
      'MMM dd, yyyy',
      'd-MMM-yyyy',
    ];

    for (var format in formats) {
      try {
        final date = DateFormat(format).parse(dateStr);
        return DateFormat('yyyy-MM-dd').format(date);
      } catch (e) {
        // Try next format
      }
    }
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void> _submitPurchaseEntry() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = widget.data['response'] ?? {};
      final productsList = response['product_data'] as List<dynamic>? ?? [];
      final storeId = widget.storeId;
      final purchasedFromStoreId = widget.supplierStoreId ?? '';
      final supplierInvoiceId = response['invoice_id']?.toString() ?? '';
      final rawInvoiceDate = response['invoice_date']?.toString() ?? '';
      final invoiceDate = _formatDateToISO(rawInvoiceDate);

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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase entry created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
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

    final supplierName = supplierData['supplier_name'] ?? 'N/A';
    final supplierGst = supplierData['supplier_gst_in'] ?? 'N/A';

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
            // Progress Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildStepBadge(1, 'Upload', true),
                    _buildStepConnector(true),
                    _buildStepBadge(2, 'Supplier', true),
                    _buildStepConnector(true),
                    _buildStepBadge(3, 'Products', true),
                    _buildStepConnector(true),
                    _buildStepBadge(4, 'Payment', true),
                    _buildStepConnector(true),
                    _buildStepBadge(5, 'Review', true, isActive: true),
                  ],
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 800;

                        // Verification Banner
                        final verificationBanner = Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.verified_rounded,
                                  color: Color(0xFF16A34A),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Ready to Submit',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF14532D),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Please verify all purchase details below before final submission.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: const Color(
                                          0xFF14532D,
                                        ).withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );

                        // Supplier Summary
                        final supplierCard = _buildSectionCard(
                          title: 'Supplier',
                          icon: Icons.store_mall_directory_rounded,
                          color: Colors.blue,
                          child: Column(
                            children: [
                              _buildInfoRow(
                                'Vendor Name',
                                supplierName,
                                Icons.person_rounded,
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'GSTIN',
                                supplierGst,
                                Icons.assignment_turned_in_rounded,
                              ),
                            ],
                          ),
                        );

                        // Products Summary
                        final productsCard = _buildSectionCard(
                          title: 'Products List (${productsList.length})',
                          icon: Icons.inventory_2_rounded,
                          color: Colors.orange,
                          child: Column(
                            children: productsList.asMap().entries.map((entry) {
                              final index = entry.key;
                              final product = entry.value;
                              return Column(
                                children: [
                                  _buildProductRow(product),
                                  if (index < productsList.length - 1)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Divider(
                                        height: 1,
                                        color: Colors.grey[200],
                                      ),
                                    ),
                                ],
                              );
                            }).toList(),
                          ),
                        );

                        // Payment Summary
                        final paymentCard = _buildSectionCard(
                          title: 'Payment Context',
                          icon: Icons.receipt_rounded,
                          color: Colors.teal,
                          child: Column(
                            children: [
                              _buildInfoRow(
                                'Payment Status',
                                widget.paymentStatus,
                                Icons.check_circle_outline_rounded,
                                valueColor:
                                    widget.paymentStatus.toLowerCase() == 'paid'
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              if (widget.transactionId != null &&
                                  widget.transactionId!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                  'Transaction ID',
                                  widget.transactionId!,
                                  Icons.numbers_rounded,
                                ),
                              ],
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(
                                  height: 1,
                                  color: Color(0xFFEEEEEE),
                                ),
                              ),
                              _buildTotalRow(
                                'Grand Total',
                                '₹${_totalAmount.toStringAsFixed(2)}',
                              ),
                            ],
                          ),
                        );

                        if (isWide) {
                          return Column(
                            children: [
                              verificationBanner,
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      children: [
                                        supplierCard,
                                        const SizedBox(height: 24),
                                        paymentCard,
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(flex: 6, child: productsCard),
                                ],
                              ),
                              const SizedBox(height: 100),
                            ],
                          );
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              verificationBanner,
                              supplierCard,
                              const SizedBox(height: 16),
                              productsCard,
                              const SizedBox(height: 16),
                              paymentCard,
                              const SizedBox(height: 100),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomSheet: _buildBottomBar(context),
      ),
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
                Icons.verified_user_rounded,
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
                        'Review & Confirm',
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
                              color: const Color(0xFF16A34A).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'STEP 3/3',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Finalize submission',
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

  Widget _buildStepBadge(
    int step,
    String label,
    bool isCompleted, {
    bool isActive = false,
  }) {
    Color bgColor = Colors.grey[100]!;
    Color fgColor = Colors.grey[400]!;
    Color borderColor = Colors.transparent;

    if (isActive) {
      bgColor = const Color(0xFF3B82F6);
      fgColor = Colors.white;
    } else if (isCompleted) {
      bgColor = const Color(0xFFDCFCE7);
      fgColor = const Color(0xFF16A34A);
    }

    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor),
          ),
          child: Center(
            child: isCompleted && !isActive
                ? Icon(Icons.check, size: 14, color: fgColor)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: fgColor,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive || isCompleted
                ? FontWeight.bold
                : FontWeight.w500,
            color: isActive
                ? const Color(0xFF1E293B)
                : (isCompleted ? const Color(0xFF16A34A) : Colors.grey[400]),
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(bool isActive) {
    return Container(
      width: 20,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isActive ? const Color(0xFFDCFCE7) : Colors.grey[200],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey[300],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductRow(Map<String, dynamic> product) {
    final name = product['product_name'] ?? 'Unknown';
    final qty = product['quantity']?.toString() ?? '0';
    final rate = product['rate']?.toString() ?? '0';
    final total = (double.tryParse(qty) ?? 0) * (double.tryParse(rate) ?? 0);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Center(
            child: Text(
              double.tryParse(qty)?.toInt().toString() ?? qty,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Rate: ₹$rate',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        Text(
          '₹${total.toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF047857),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
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
        onTap: _isSubmitting ? null : _submitPurchaseEntry,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF16A34A), Color(0xFF15803D)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF16A34A).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _isSubmitting
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Confirm Purchase Order',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
