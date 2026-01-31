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
    // Optional: Implement refresh logic here if needed,
    // but for now we rely on the passed data.
    setState(() {
      _purchaseData = widget.purchaseData;
      _isLoading = false;
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'PARTIAL':
        return Colors.blue;
      case 'CREDIT':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '₹0';
    return '₹${double.tryParse(amount.toString())?.toStringAsFixed(2).replaceAll(RegExp(r"([.]*0+)(?!.*\d)"), "") ?? amount}';
  }

  // To format larger numbers with commas if needed, but keeping it simple for now as per request.
  // Using basic logic to match formatting style in image (e.g., ₹1,00,000) requires NumberFormat
  // but I'll stick to a simple formatted string or improve if I add intl package import.
  // Actually, I should use NumberFormat for better aesthetics.
  // Let's rely on basic string manipulation or standard intl if available.
  // I updated to use RegExp to trim trailing zeros for a clean look, or keep 2 decimals if non-zero.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TranslatedText(
              'Purchase Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              _purchaseData?['voucher_number']?.toString() ?? '',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        centerTitle: false,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        automaticallyImplyLeading:
            false, // Using close button instead of back arrow
      ),
      body: _buildBody(theme, isDark),
    );
  }

  Widget _buildBody(ThemeData theme, bool isDark) {
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

    final data = _purchaseData!;
    final supplier = data['supplier'] ?? {};
    final paymentInfo = data['payment_info'] ?? {};
    final taxBreakdown = data['tax_breakdown'] ?? {};
    final items = data['items'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  theme,
                  'Date',
                  data['date'] != null
                      ? data['date']
                            .toString()
                            .split('-')
                            .reversed
                            .join('-') // formatting as DD-MM-YYYY roughly
                      // Ideally use DateFormat('MMM d, yyyy').format(DateTime.parse(data['date']))
                      // Assuming data['date'] is YYYY-MM-DD
                      : '',
                  isHighlight: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  theme,
                  'Total Amount',
                  _formatCurrency(data['total_amount']),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  theme,
                  'Tax',
                  _formatCurrency(taxBreakdown['total_tax']),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  theme,
                  'Grand Total',
                  _formatCurrency(data['grand_total']),
                  textColor: Colors.orange,
                  isBold: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Supplier Info Card
          _buildSectionCard(
            theme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildLabelValue(
                        theme,
                        'Supplier',
                        supplier['name'] ?? 'Unknown',
                        titleStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: _buildLabelValue(
                        theme,
                        'Invoice Number',
                        data['supplier_invoice_number'] ?? '',
                        titleStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TranslatedText(
                            'Payment Status',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildStatusPill(
                            theme,
                            paymentInfo['payment_status'] ?? 'UNKNOWN',
                            _getStatusColor(
                              paymentInfo['payment_status'] ?? '',
                            ),
                            isSolid: true,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TranslatedText(
                            'Voucher Status',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildStatusPill(
                            theme,
                            data['status'] ?? 'UNKNOWN',
                            Colors.grey,
                            isSolid: false,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TranslatedText(
                            'Posted',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildStatusPill(
                            theme,
                            data['is_posted'] == true ? 'Yes' : 'No',
                            data['is_posted'] == true
                                ? Colors.green
                                : Colors.red,
                            isSolid: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Payment Information
          _buildSectionCard(
            theme,
            title: 'Payment Information',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildLabelValue(
                    theme,
                    'Amount Paid',
                    _formatCurrency(paymentInfo['amount_paid']),
                    valueColor: Colors.green,
                    isBold: true,
                  ),
                ),
                Expanded(
                  child: _buildLabelValue(
                    theme,
                    'Amount Due',
                    _formatCurrency(paymentInfo['amount_due']),
                    valueColor: Colors.red,
                    isBold: true,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TranslatedText(
                        'Status',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        paymentInfo['payment_status'] ?? '',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Tax Breakdown
          _buildSectionCard(
            theme,
            title: 'Tax Breakdown',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildLabelValue(
                    theme,
                    'CGST',
                    _formatCurrency(taxBreakdown['total_cgst']),
                  ),
                ),
                Expanded(
                  child: _buildLabelValue(
                    theme,
                    'SGST',
                    _formatCurrency(taxBreakdown['total_sgst']),
                  ),
                ),
                Expanded(
                  child: _buildLabelValue(
                    theme,
                    'IGST',
                    _formatCurrency(taxBreakdown['total_igst']),
                  ),
                ),
                Expanded(
                  child: _buildLabelValue(
                    theme,
                    'CESS',
                    _formatCurrency(taxBreakdown['total_cess']),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Items List
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(
                  'Items (${items.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildTableHeader(theme, 'Product'),
                      ),
                      Expanded(flex: 2, child: _buildTableHeader(theme, 'Qty')),
                      Expanded(
                        flex: 2,
                        child: _buildTableHeader(theme, 'Rate'),
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildTableHeader(theme, 'Amount'),
                      ),
                      Expanded(flex: 2, child: _buildTableHeader(theme, 'HSN')),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ...items
                    .map(
                      (item) => Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12.0,
                              horizontal: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['product']?['name'] ?? 'Unknown',
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                      Text(
                                        item['product']?['brand'] ?? '',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.5),
                                              fontSize: 10,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${item['quantity']} ${item['unit']?['name'] ?? 'units'}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatCurrency(item['rate']),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    _formatCurrency(item['amount']),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item['hsn_code'] ??
                                        item['inventory']?['hsn_code'] ??
                                        item['product']?['hsn_code'] ??
                                        '-',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(
                            height: 1,
                            color: theme.dividerColor.withOpacity(0.1),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Narration
          _buildSectionCard(
            theme,
            title: 'Narration',
            child: Text(
              data['narration'] ?? '-',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    ThemeData theme,
    String label,
    String value, {
    Color? textColor,
    bool isBold = false,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlight
            ? theme.primaryColor.withOpacity(0.05)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: isBold || isHighlight
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: textColor ?? theme.colorScheme.onSurface,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    ThemeData theme, {
    String? title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            TranslatedText(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }

  Widget _buildLabelValue(
    ThemeData theme,
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
    TextStyle? titleStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TranslatedText(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style:
              titleStyle ??
              theme.textTheme.titleMedium?.copyWith(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: valueColor ?? theme.colorScheme.onSurface,
              ),
        ),
      ],
    );
  }

  Widget _buildStatusPill(
    ThemeData theme,
    String status,
    Color color, {
    bool isSolid = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isSolid ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: isSolid ? Colors.white : color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTableHeader(ThemeData theme, String text) {
    return Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface.withOpacity(0.7),
      ),
    );
  }
}
