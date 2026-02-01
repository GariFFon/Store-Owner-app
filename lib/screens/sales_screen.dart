import 'package:exanor/models/sales_models.dart';
import 'package:exanor/services/sales_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalesScreen extends StatefulWidget {
  final String storeId;

  const SalesScreen({super.key, required this.storeId});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  bool _isLoading = true;
  List<Voucher> _vouchers = [];
  int _totalCount = 0;

  // Summary stats (calculated from fetched data or just defaults if not available globally)
  double _totalRevenue = 0.0;
  double _totalTax = 0.0;
  int _postedCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchSales();
  }

  Future<void> _fetchSales() async {
    setState(() => _isLoading = true);
    try {
      final response = await SalesService.fetchSales(storeId: widget.storeId);
      setState(() {
        _vouchers = response.vouchers;
        _totalCount = response.count;

        // Calculate summaries from the visible batch (or approximations)
        // Ideally these should come from the API if they represent global totals
        _totalRevenue = _vouchers.fold(0.0, (sum, v) => sum + v.grandTotal);
        _totalTax = _vouchers.fold(
          0.0,
          (sum, v) => sum + (v.taxBreakdown?.totalTax ?? 0.0),
        );
        _postedCount = _vouchers.where((v) => v.isPosted).length;

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDetails(Voucher voucher) {
    showDialog(
      context: context,
      builder: (context) => SalesDetailsDialog(voucher: voucher),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Sales',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchSales,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'View and manage sales entries',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Sales',
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Revenue',
                            '₹${_totalRevenue.toStringAsFixed(2)}',
                            Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildSummaryCard(
                            'Total Tax',
                            '₹${_totalTax.toStringAsFixed(2)}',
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Search & Filters row (Visual only for now)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search by voucher number...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.filter_list),
                          label: const Text("Filters"),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.sort),
                          label: const Text("Sort"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

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
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Text(
                              "VOUCHER",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "DATE",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "CUSTOMER",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              "AMOUNT",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
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

                    // Vouchers List
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _vouchers.length,
                      itemBuilder: (context, index) {
                        final v = _vouchers[index];
                        return InkWell(
                          onTap: () => _showDetails(v),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFF1F5F9)),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    v.voucherNumber,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    v.date,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
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
                                          v.customer?.name ?? 'Unknown',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '₹${v.grandTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: v.isPosted
                                          ? Colors.green.withOpacity(0.1)
                                          : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      v.isPosted ? 'Posted' : 'Draft',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: v.isPosted
                                            ? Colors.green
                                            : Colors.orange,
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
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
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
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class SalesDetailsDialog extends StatelessWidget {
  final Voucher voucher;

  const SalesDetailsDialog({super.key, required this.voucher});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        // Removed fixed width for responsiveness
        constraints: BoxConstraints(
          maxWidth: 500, // Max width instead of fixed width
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  voucher.voucherNumber,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Text(
              DateFormat.yMMMd().format(DateTime.parse(voucher.date)),
              style: const TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Info Row - Stacked for better mobile support
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: _buildSection('Customer Information', [
                            _buildInfoRow(
                              'Name:',
                              voucher.customer?.name ?? 'N/A',
                            ),
                            _buildInfoRow(
                              'Type:',
                              voucher.customer?.partyType ?? 'N/A',
                            ),
                          ]),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: _buildSection('Amount Summary', [
                            _buildInfoRow(
                              'Subtotal:',
                              '₹${voucher.totalAmount.toStringAsFixed(2)}',
                            ),
                            _buildInfoRow(
                              'Tax:',
                              '₹${(voucher.taxBreakdown?.totalTax ?? 0).toStringAsFixed(2)}',
                            ),
                            const Divider(),
                            _buildInfoRow(
                              'Grand Total:',
                              '₹${voucher.grandTotal.toStringAsFixed(2)}',
                              isBold: true,
                              color: Colors.green,
                            ),
                          ]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Tax Breakdown
                    _buildSection('Tax Breakdown', [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildTaxCol(
                              'CGST',
                              voucher.taxBreakdown?.totalCgst ?? 0,
                            ),
                            const SizedBox(width: 12),
                            _buildTaxCol(
                              'SGST',
                              voucher.taxBreakdown?.totalSgst ?? 0,
                            ),
                            const SizedBox(width: 12),
                            _buildTaxCol(
                              'IGST',
                              voucher.taxBreakdown?.totalIgst ?? 0,
                            ),
                            const SizedBox(width: 12),
                            _buildTaxCol(
                              'CESS',
                              voucher.taxBreakdown?.totalCess ?? 0,
                            ),
                            const SizedBox(width: 12),
                            _buildTaxCol(
                              'Total Tax',
                              voucher.taxBreakdown?.totalTax ?? 0,
                              color: Colors.purple,
                            ),
                          ],
                        ),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // Items
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Items",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...voucher.items.map(
                      (item) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.productName ?? 'Unknown Product',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '₹${item.amount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Qty: ${item.quantity.toInt()} ${item.unitName ?? ''}   Rate: ₹${item.rate.toStringAsFixed(2)}   HSN: ${item.inventory?.hsnCode ?? item.taxDetails?.hsnCode ?? ''}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if ((item.taxDetails?.cgstAmount ?? 0) > 0)
                                  Text(
                                    "CGST: ${(item.taxDetails?.cgstRate ?? 0)}% (₹${item.taxDetails?.cgstAmount})  ",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                if ((item.taxDetails?.sgstAmount ?? 0) > 0)
                                  Text(
                                    "SGST: ${(item.taxDetails?.sgstRate ?? 0)}% (₹${item.taxDetails?.sgstAmount})  ",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                if ((item.taxDetails?.igstAmount ?? 0) > 0)
                                  Text(
                                    "IGST: ${(item.taxDetails?.igstRate ?? 0)}% (₹${item.taxDetails?.igstAmount})",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    if (voucher.narration != null)
                      _buildSection('Narration', [
                        Text(
                          voucher.narration!,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ]),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black,
                  elevation: 0,
                ),
                child: const Text("Close"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxCol(String label, double amount, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
