import 'package:exanor/models/payment_models.dart';
import 'package:exanor/services/payment_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PaymentScreen extends StatefulWidget {
  final String storeId;

  const PaymentScreen({super.key, required this.storeId});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = true;
  List<PaymentVoucher> _vouchers = [];
  int _totalCount = 0;

  // Filters
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _partyId;
  String _postedStatus = 'All'; // 'All', 'Posted', 'Not Posted'
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _partyIdController = TextEditingController();
  bool _showFilters = false;

  // Summary
  int _postedCount = 0;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _partyIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchPayments() async {
    setState(() => _isLoading = true);

    // Convert status dropdown to boolean or null
    bool? isPosted;
    if (_postedStatus == 'Posted') isPosted = true;
    if (_postedStatus == 'Not Posted') isPosted = false;

    // Dates
    String? fromStr = _fromDate != null
        ? DateFormat('yyyy-MM-dd').format(_fromDate!)
        : null;
    String? toStr = _toDate != null
        ? DateFormat('yyyy-MM-dd').format(_toDate!)
        : null;

    try {
      final response = await PaymentService.fetchPayments(
        storeId: widget.storeId,
        page:
            1, // Pagination not fully implemented in UI scrolling yet, sticking to page 1
        pageSize: 50,
        fromDate: fromStr,
        toDate: toStr,
        isPosted: isPosted,
        partyId: _partyId,
        searchQuery: _searchController.text,
      );

      setState(() {
        _vouchers = response.vouchers;
        _totalCount = response.totalItems;

        // Calculate visual summaries based on fetched data
        // (Note: In a real app with pagination, these should come from API summary fields)
        _postedCount = _vouchers.where((v) => v.isPosted).length;
        _totalAmount = _vouchers.fold(0.0, (sum, v) => sum + v.amount);

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _fetchPayments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payments',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const Text(
              'View and manage payment entries',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPayments,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _fetchPayments(),
                    decoration: InputDecoration(
                      hintText: 'Search by voucher number...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      suffixIcon: GestureDetector(
                        onTap: () {
                          setState(() {
                            _showFilters = !_showFilters;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _showFilters
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            Icons.filter_list,
                            color: _showFilters
                                ? Colors.blue.shade800
                                : Colors.blue,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Filters Row
                  if (_showFilters)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildFilterField(
                                  label: "Date From",
                                  child: InkWell(
                                    onTap: () => _selectDate(context, true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _fromDate != null
                                                ? DateFormat(
                                                    'MM/dd/yyyy',
                                                  ).format(_fromDate!)
                                                : 'MM/DD/YYYY',
                                            style: TextStyle(
                                              color: _fromDate != null
                                                  ? Colors.black
                                                  : Colors.grey,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildFilterField(
                                  label: "Date To",
                                  child: InkWell(
                                    onTap: () => _selectDate(context, false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            _toDate != null
                                                ? DateFormat(
                                                    'MM/dd/yyyy',
                                                  ).format(_toDate!)
                                                : 'MM/DD/YYYY',
                                            style: TextStyle(
                                              color: _toDate != null
                                                  ? Colors.black
                                                  : Colors.grey,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFilterField(
                                  label: "Party ID",
                                  child: TextField(
                                    controller: _partyIdController,
                                    onSubmitted: (val) {
                                      _partyId = val.isEmpty ? null : val;
                                      _fetchPayments();
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Enter party ID',
                                      hintStyle: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildFilterField(
                                  label: "Posted Status",
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _postedStatus,
                                        isExpanded: true,
                                        items: ['All', 'Posted', 'Not Posted']
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e,
                                                child: Text(e),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => _postedStatus = val);
                                            _fetchPayments();
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Summary Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Payments',
                          '$_totalCount',
                          Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          'Posted',
                          '$_postedCount',
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          'Total Amount',
                          '₹${_totalAmount.toStringAsFixed(2)}',
                          Colors.black,
                          isLarge: true,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Horizontally scrollable table
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      children: [
                        // List Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(
                                  "VOUCHER",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  "DATE",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                child: Text(
                                  "PARTY",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  "AMOUNT",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 150,
                                child: Text(
                                  "PAYMENT ACCOUNT",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 100,
                                child: Text(
                                  "STATUS",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // List Items
                        SizedBox(
                          width: 722, // Total width (690) + Padding (32)
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _vouchers.length,
                            itemBuilder: (context, index) {
                              final v = _vouchers[index];
                              return InkWell(
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) =>
                                      PaymentDetailsDialog(voucher: v),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 16,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Color(0xFFF1F5F9),
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 120,
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.receipt_long_outlined,
                                              size: 14,
                                              color: Colors.blue,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                v.voucherNumber,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 100,
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 12,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              DateFormat(
                                                'MMM d, y',
                                              ).format(DateTime.parse(v.date)),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 120,
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.person_outline,
                                              size: 14,
                                              color: Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                v.partyName,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(
                                        width: 100,
                                        child: Text(
                                          '₹${v.amount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          v.paymentAccount,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 100,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: v.isPosted
                                                  ? Colors.green.withOpacity(
                                                      0.1,
                                                    )
                                                  : Colors.orange.withOpacity(
                                                      0.1,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (v.isPosted)
                                                  const Icon(
                                                    Icons.check,
                                                    size: 10,
                                                    color: Colors.green,
                                                  ),
                                                if (v.isPosted)
                                                  const SizedBox(width: 2),
                                                Text(
                                                  v.isPosted
                                                      ? 'Posted'
                                                      : 'Draft',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: v.isPosted
                                                        ? Colors.green
                                                        : Colors.orange,
                                                  ),
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
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    Color color, {
    bool isLarge = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: isLarge ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentDetailsDialog extends StatelessWidget {
  final PaymentVoucher voucher;

  const PaymentDetailsDialog({super.key, required this.voucher});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFF1F5F9), // Light grey bg as per image
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voucher.voucherNumber,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat(
                          'MMM d, y',
                        ).format(DateTime.parse(voucher.date)),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Top Cards - Stacked Vertically
              Column(
                children: [
                  _buildInfoCard('Party Information', [
                    _buildDetailRow('Name:', voucher.partyName),
                    _buildDetailRow(
                      'Type:',
                      voucher.partyType ?? 'USER',
                    ), // Mocked default
                  ]),
                  const SizedBox(height: 16),
                  _buildInfoCard('Payment Summary', [
                    _buildDetailRow(
                      'Amount:',
                      '₹${voucher.amount.toStringAsFixed(2)}',
                      valueColor: Colors.green,
                      isBold: true,
                    ),
                    _buildDetailRow(
                      'Status:',
                      '',
                      customValue: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              voucher.isPosted ? "Posted" : "Draft",
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildDetailRow('Voucher Type:', 'PAYMENT'),
                    _buildDetailRow(
                      'Financial Year:',
                      'FY ${DateTime.parse(voucher.date).year}-${DateTime.parse(voucher.date).year + 1}',
                    ), // Basic mock
                  ]),
                ],
              ),

              const SizedBox(height: 16),

              // Narration
              if (voucher.narration != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Narration",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        voucher.narration!,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Ledger Entries Header
              const Text(
                "Ledger Entries",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Ledger Entries Table
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              "ACCOUNT",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "DEBIT",
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "CREDIT",
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Entry 1: Party (Debit)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              "Debtors (${voucher.partyName})",
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "₹${voucher.amount.toStringAsFixed(2)}",
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const Expanded(
                            flex: 1,
                            child: Text(
                              "-",
                              textAlign: TextAlign.right,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Entry 2: Payment Account (Credit)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              voucher.paymentAccount,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const Expanded(
                            flex: 1,
                            child: Text(
                              "-",
                              textAlign: TextAlign.right,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Text(
                              "₹${voucher.amount.toStringAsFixed(2)}",
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
    Widget? customValue,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          customValue ??
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.black,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
        ],
      ),
    );
  }
}
