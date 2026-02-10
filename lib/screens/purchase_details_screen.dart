import 'dart:math' as math;
import 'package:exanor/components/translation_widget.dart';
import 'package:flutter/material.dart';

class PurchaseDetailsScreen extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic> purchaseData;

  const PurchaseDetailsScreen({
    super.key,
    required this.storeId,
    required this.purchaseData,
  });

  @override
  State<PurchaseDetailsScreen> createState() => _PurchaseDetailsScreenState();
}

class _PurchaseDetailsScreenState extends State<PurchaseDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _purchaseData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _purchaseData = widget.purchaseData;
    _isLoading = false;
  }

  Future<void> _fetchPurchaseDetails() async {
    setState(() {
      _purchaseData = widget.purchaseData;
      _isLoading = false;
    });
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '₹0';
    return '₹${double.tryParse(amount.toString())?.toStringAsFixed(2).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "") ?? amount}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use a lighter/white background for modern look
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background
      body: Column(
        children: [
          _buildTopBanner(theme),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildTopBanner(ThemeData theme) {
    const lightBlueBg = Color(0xFFEFF6FF);
    const watermarkColor = Color(0xFFDBEAFE);

    final supplierName = _purchaseData?['supplier'] != null
        ? _purchaseData!['supplier']['name']
        : 'Unknown Supplier';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: lightBlueBg,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRect(
        child: Stack(
          children: [
            // Watermark
            Positioned(
              right: -30,
              top: -10,
              child: Transform.rotate(
                angle: -math.pi / 6,
                child: Icon(
                  Icons.receipt_long_rounded,
                  size: 180,
                  color: watermarkColor.withOpacity(0.6),
                ),
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                16 + MediaQuery.of(context).padding.top,
                12,
                16,
              ),
              child: SizedBox(
                height: 64, // Same height as Order Details
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Back Button
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.blueGrey.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.only(right: 2),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.blueGrey,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TranslatedText(
                            supplierName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B), // Slate 800
                              letterSpacing: -0.5,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.2),
                              ),
                            ),
                            child: const TranslatedText(
                              'PURCHASE DETAILS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1565C0),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchPurchaseDetails,
              child: const TranslatedText('Retry'),
            ),
          ],
        ),
      );
    }

    if (_purchaseData == null) {
      return const Center(child: TranslatedText('No data available'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        if (isWide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LEFT COLUMN
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _buildInformationCard(theme),
                          const SizedBox(height: 16),
                          _buildPaymentInfoCard(theme),
                          const SizedBox(height: 16),
                          if (_purchaseData!['narration'] != null &&
                              _purchaseData!['narration'].toString().isNotEmpty)
                            _buildSectionCard(
                              theme,
                              title: 'Narration',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDashedDivider(),
                                  Text(
                                    _purchaseData!['narration'],
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // RIGHT COLUMN
                    Expanded(
                      flex: 6,
                      child: Column(
                        children: [
                          _buildItemsList(theme),
                          const SizedBox(height: 16),
                          _buildPriceBreakdownCard(theme),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Mobile Layout
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInformationCard(theme),
                  const SizedBox(height: 16),
                  _buildItemsList(theme),
                  const SizedBox(height: 16),
                  _buildPaymentInfoCard(theme),
                  const SizedBox(height: 16),
                  _buildPriceBreakdownCard(theme),
                  if (_purchaseData!['narration'] != null &&
                      _purchaseData!['narration'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      theme,
                      title: 'Narration',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDashedDivider(),
                          Text(
                            _purchaseData!['narration'],
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionCard(
    ThemeData theme, {
    String? title,
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
            color: Colors.black.withOpacity(0.25), // Strong/Darker Shadow
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                TranslatedText(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildInformationCard(ThemeData theme) {
    return _buildSectionCard(
      theme,
      title: 'Purchase Information',
      child: Column(
        children: [
          // Added dashed divider above the first item (Voucher Number) as requested
          _buildDashedDivider(),
          _buildInfoRow(
            theme,
            'Voucher Number',
            _purchaseData!['voucher_number'] ?? '-',
            Icons.receipt_rounded,
          ),
          _buildDashedDivider(),
          _buildInfoRow(
            theme,
            'Supplier Invoice',
            _purchaseData!['supplier_invoice_number'] ?? '-',
            Icons.description_outlined,
          ),
          _buildDashedDivider(),
          _buildInfoRow(
            theme,
            'Date',
            _purchaseData!['date'] ?? '-',
            Icons.calendar_today_rounded,
          ),
          _buildDashedDivider(),
          _buildInfoRow(
            theme,
            'Voucher Status',
            _purchaseData!['is_posted'] == true ? 'Posted' : 'Draft',
            Icons.check_circle_outline_rounded,
            valueColor: _purchaseData!['is_posted'] == true
                ? Colors.green
                : Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoCard(ThemeData theme) {
    final paymentInfo =
        _purchaseData!['payment_info'] as Map<String, dynamic>? ?? {};
    return _buildSectionCard(
      theme,
      title: 'Payment Status',
      child: Column(
        children: [
          _buildDashedDivider(),
          _buildInfoRow(
            theme,
            'Status',
            paymentInfo['payment_status'] ?? 'UNKNOWN',
            Icons.payment_rounded,
            isBold: true,
          ),
          _buildDashedDivider(),
          _buildInfoRow(
            theme,
            'Amount Paid',
            _formatCurrency(paymentInfo['amount_paid']),
            Icons.add_circle_outline_rounded,
            valueColor: Colors.green,
          ),
          _buildDashedDivider(),
          _buildInfoRow(
            theme,
            'Amount Due',
            _formatCurrency(paymentInfo['amount_due']),
            Icons.remove_circle_outline_rounded,
            valueColor: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(ThemeData theme) {
    final items = _purchaseData!['items'] as List<dynamic>? ?? [];

    return _buildSectionCard(
      theme,
      title: 'Items Purchased (${items.length})',
      child: items.isEmpty
          ? const Center(child: Text('No items'))
          : Column(
              children: items.map((item) {
                return Column(
                  children: [
                    if (item == items.first) _buildDashedDivider(),
                    _buildItemRow(theme, item),
                    if (item != items.last) _buildDashedDivider(),
                  ],
                );
              }).toList(),
            ),
    );
  }

  Widget _buildItemRow(ThemeData theme, Map<String, dynamic> item) {
    final unitName = item['unit']?['name'] ?? '';
    final quantity = item['quantity'] ?? 0;
    final rate = _formatCurrency(item['rate']);
    final amount = _formatCurrency(item['amount']);
    final productName = item['product']?['name'] ?? 'Unknown Item';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Name - Prominent at top
          Text(
            productName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          // Rate per unit - Subtle info row
          Row(
            children: [
              Icon(
                Icons.sell_outlined,
                size: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 6),
              Text(
                '$rate${unitName.isNotEmpty ? ' per $unitName' : ' each'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              // HSN Code
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'HSN: ${item['inventory']?['hsn_code'] ?? item['product']?['hsn_code'] ?? item['product']?['hsn'] ?? 'N/A'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Quantity and Total - Two equal columns
          Row(
            children: [
              // Quantity Column
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'QTY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary.withOpacity(0.7),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$quantity${unitName.isNotEmpty ? ' $unitName' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Total Column
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700.withOpacity(0.7),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        amount,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownCard(ThemeData theme) {
    final taxBreakdown =
        _purchaseData!['tax_breakdown'] as Map<String, dynamic>? ?? {};

    return _buildSectionCard(
      theme,
      title: 'Price Breakdown',
      child: Column(
        children: [
          _buildDashedDivider(),
          _buildSummaryRow(
            theme,
            'Total Amount',
            _formatCurrency(_purchaseData!['total_amount']),
          ),
          const SizedBox(height: 8),
          if (taxBreakdown.isNotEmpty) ...[
            _buildSummaryRow(
              theme,
              'Total Tax',
              _formatCurrency(taxBreakdown['total_tax']),
            ),
            const SizedBox(height: 4),
            _buildSummaryRow(
              theme,
              'Total CESS',
              _formatCurrency(taxBreakdown['total_cess']),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'CGST: ${_formatCurrency(taxBreakdown['total_cgst'])} | SGST: ${_formatCurrency(taxBreakdown['total_sgst'])} | IGST: ${_formatCurrency(taxBreakdown['total_igst'])} | CESS: ${_formatCurrency(taxBreakdown['total_cess'])}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          _buildDashedDivider(),
          _buildSummaryRow(
            theme,
            'Grand Total',
            _formatCurrency(_purchaseData!['grand_total']),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    ThemeData theme,
    String label,
    String value, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TranslatedText(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 16 : 14,
            color: isTotal
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 18 : 14,
            color: isTotal ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TranslatedText(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 11,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: valueColor ?? theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Flex(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            direction: Axis.horizontal,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: dashHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.grey[300]),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
