import 'dart:math' as math;
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

    // Use a lighter/white background for modern look
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildTopBanner(context, theme),
          Expanded(child: _buildBody(theme)),
        ],
      ),
    );
  }

  Widget _buildTopBanner(BuildContext context, ThemeData theme) {
    const lightBlueBg = Color(0xFFEFF6FF);
    const watermarkColor = Color(0xFFDBEAFE);

    final partyName = receipt['party_name'] ?? 'Unknown Party';

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
                            partyName,
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
                              'RECEIPT DETAILS',
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
                          _buildPartyInfoCard(theme),
                          const SizedBox(height: 16),
                          if (receipt['narration'] != null &&
                              receipt['narration'].toString().isNotEmpty)
                            _buildSectionCard(
                              theme,
                              title: 'Narration',
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Removed dashed divider
                                  Text(
                                    receipt['narration']!,
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
                          _buildSummaryCard(theme),
                          const SizedBox(height: 16),
                          _buildLedgerEntriesCard(theme),
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
                  _buildPartyInfoCard(theme),
                  const SizedBox(height: 16),
                  _buildSummaryCard(theme),
                  const SizedBox(height: 16),
                  _buildLedgerEntriesCard(theme),
                  if (receipt['narration'] != null &&
                      receipt['narration'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      theme,
                      title: 'Narration',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Removed dashed divider
                          Text(
                            receipt['narration']!,
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

  Widget _buildPartyInfoCard(ThemeData theme) {
    return _buildSectionCard(
      theme,
      title: 'Party Information',
      child: Column(
        children: [
          _buildInfoRow(
            theme,
            'Name',
            receipt['party_name'] ?? 'Unknown',
            Icons.person_outline_rounded,
          ),
          Divider(
            color: theme.colorScheme.outline.withOpacity(0.08),
            height: 24,
            thickness: 1,
          ),
          _buildInfoRow(
            theme,
            'Type',
            'USER', // Assuming fixed as per original code
            Icons.category_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return _buildSectionCard(
      theme,
      title: 'Receipt Summary',
      child: Column(
        children: [
          _buildInfoRow(
            theme,
            'Voucher Number',
            receipt['voucher_number'] ?? '',
            Icons.receipt_rounded,
          ),
          Divider(
            color: theme.colorScheme.outline.withOpacity(0.08),
            height: 24,
            thickness: 1,
          ),
          _buildInfoRow(
            theme,
            'Amount',
            _formatCurrency(receipt['amount']),
            Icons.attach_money_rounded,
            valueColor: Colors.green,
            isBold: true,
          ),
          Divider(
            color: theme.colorScheme.outline.withOpacity(0.08),
            height: 24,
            thickness: 1,
          ),
          _buildInfoRow(
            theme,
            'Date',
            _formatDate(receipt['date']),
            Icons.calendar_today_rounded,
          ),
          Divider(
            color: theme.colorScheme.outline.withOpacity(0.08),
            height: 24,
            thickness: 1,
          ),
          _buildInfoRow(
            theme,
            'Financial Year',
            _getFinancialYear(receipt['date']),
            Icons.event_note_rounded,
          ),
          Divider(
            color: theme.colorScheme.outline.withOpacity(0.08),
            height: 24,
            thickness: 1,
          ),
          _buildInfoRow(
            theme,
            'Status',
            receipt['is_posted'] == true ? 'Posted' : 'Unposted',
            Icons.check_circle_outline_rounded,
            valueColor: receipt['is_posted'] == true
                ? Colors.green
                : Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerEntriesCard(ThemeData theme) {
    return _buildSectionCard(
      theme,
      title: 'Ledger Entries',
      child: Column(
        children: [
          // Header with painted background
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // Slate 100
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'ACCOUNT',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B), // Slate 500
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'DEBIT',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'CREDIT',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Row 1 (Cash/Bank - Debit)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    receipt['receipt_account'] ?? 'Unknown Account',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155), // Slate 700
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _formatCurrency(receipt['amount']),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFFDC2626), // Red 600
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '-',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.withOpacity(0.1), height: 1, thickness: 1),
          // Row 2 (Customer - Credit)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customer',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF334155),
                        ),
                      ),
                      if (receipt['party_name'] != null)
                        Text(
                          receipt['party_name'] ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    '-',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      _formatCurrency(receipt['amount']),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF16A34A), // Green 600
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
}
