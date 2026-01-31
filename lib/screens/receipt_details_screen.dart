import 'package:exanor/components/translation_widget.dart';
import 'package:flutter/material.dart';

class ReceiptDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> receipt;

  const ReceiptDetailsScreen({super.key, required this.receipt});

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '₹0.00';
    return '₹${double.tryParse(amount.toString())?.toStringAsFixed(2) ?? amount}';
  }

  String _formatDate(String? date) {
    if (date == null) return '';
    try {
      final parts = date.split('-');
      if (parts.length == 3) {
        // Assume yyyy-MM-dd
        return '${parts[2]} ${_getMonth(parts[1])}, ${parts[0]}';
      }
    } catch (_) {}
    return date;
  }

  String _getMonth(String month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final index = int.tryParse(month);
    if (index != null && index >= 1 && index <= 12) {
      return months[index - 1];
    }
    return month;
  }

  String _getFinancialYear(String? date) {
    if (date == null) return '';
    try {
      final parts = date.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      if (month >= 4) {
        return 'FY $year-${year + 1}';
      } else {
        return 'FY ${year - 1}-$year';
      }
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final voucherNumber = receipt['voucher_number'] ?? '';
    final date = receipt['date'];
    final formattedDate = _formatDate(date);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              voucherNumber,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (formattedDate.isNotEmpty)
              Text(
                formattedDate,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Party Information
            _buildSectionCard(
              theme,
              title: 'Party Information',
              child: Column(
                children: [
                  _buildLabelValueRow(
                    theme,
                    'Name:',
                    receipt['party_name'] ?? 'Unknown',
                  ),
                  const SizedBox(height: 12),
                  _buildLabelValueRow(theme, 'Type:', 'USER'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Receipt Summary
            _buildSectionCard(
              theme,
              title: 'Receipt Summary',
              child: Column(
                children: [
                  _buildLabelValueRow(
                    theme,
                    'Amount:',
                    _formatCurrency(receipt['amount']),
                    valueColor: Colors.green,
                    isBoldValue: true,
                  ),
                  const SizedBox(height: 12),
                  _buildLabelValueRow(
                    theme,
                    'Status:',
                    receipt['is_posted'] == true ? 'Posted' : 'Unposted',
                    isStatus: true,
                    statusColor: receipt['is_posted'] == true
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildLabelValueRow(
                    theme,
                    'Financial Year:',
                    _getFinancialYear(date),
                  ),
                  const SizedBox(height: 12),
                  _buildLabelValueRow(theme, 'Voucher Type:', 'RECEIPT'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Narration
            _buildSectionCard(
              theme,
              title: 'Narration',
              child: Text(
                receipt['narration'] ?? 'No narration',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),

            // Ledger Entries
            _buildSectionCard(
              theme,
              title: 'Ledger Entries',
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'ACCOUNT',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'DEBIT',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            'CREDIT',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // Row 1 (Cash/Bank - Debit)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            receipt['receipt_account'] ?? 'Unknown Account',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            _formatCurrency(receipt['amount']),
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors
                                  .red, // Usually debits are standard, but image showed red maybe? Image showed red for debit amount 150.00
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            '-',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Row 2 (Customer - Credit)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Customer - ${receipt['party_name']}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            '-',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            _formatCurrency(receipt['amount']),
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors
                                  .green, // Credit usually green or standard
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    ThemeData theme, {
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildLabelValueRow(
    ThemeData theme,
    String label,
    String value, {
    Color? valueColor,
    bool isBoldValue = false,
    bool isStatus = false,
    Color? statusColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
        ),
        if (isStatus)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: (statusColor ?? Colors.grey).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor ?? Colors.grey),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (statusColor == Colors.green)
                  const Icon(Icons.check, size: 14, color: Colors.green),
                if (statusColor == Colors.green) const SizedBox(width: 4),
                Text(
                  value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: valueColor,
              fontWeight: isBoldValue ? FontWeight.bold : FontWeight.normal,
            ),
          ),
      ],
    );
  }
}
