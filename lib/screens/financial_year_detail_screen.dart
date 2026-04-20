import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:exanor/screens/balance_sheet_screen.dart';
import 'package:exanor/screens/profit_loss_screen.dart';
import 'package:exanor/screens/cash_flow_screen.dart';
import 'package:exanor/screens/stock_summary_screen.dart';
import 'package:exanor/screens/outstanding_screen.dart';

class FinancialYearDetailScreen extends StatelessWidget {
  final String storeId;
  final Map<String, dynamic> financialYear;

  const FinancialYearDetailScreen({
    super.key,
    required this.storeId,
    required this.financialYear,
  });

  @override
  Widget build(BuildContext context) {
    final label = financialYear['label'] ?? 'FY Period';
    final startDate = financialYear['start_date'] ?? '';
    final endDate = financialYear['end_date'] ?? '';
    final isActive = financialYear['is_active'] == true;
    final isLocked = financialYear['is_locked'] == true;
    final fyId = financialYear['id'] ?? '';

    String dateRange = '';
    try {
      if (startDate.isNotEmpty && endDate.isNotEmpty) {
        final fmt = DateFormat('dd MMM yyyy');
        dateRange =
            '${fmt.format(DateTime.parse(startDate))} – ${fmt.format(DateTime.parse(endDate))}';
      }
    } catch (_) {}

    final List<_ReportCard> reports = [
      _ReportCard(
        id: 'balance_sheet',
        title: 'Balance Sheet',
        description:
            'Schedule III vertical balance sheet showing Assets, Equity & Liabilities.',
        icon: Icons.account_balance_wallet_rounded,
        iconBg: const Color(0xFFEEF2FF),
        iconColor: const Color(0xFF6366F1),
        accentColor: const Color(0xFF6366F1),
      ),
      _ReportCard(
        id: 'profit_loss',
        title: 'Profit & Loss Account',
        description:
            'Income statement displaying revenue, expenses, and PAT.',
        icon: Icons.trending_up_rounded,
        iconBg: const Color(0xFFECFDF5),
        iconColor: const Color(0xFF10B981),
        accentColor: const Color(0xFF10B981),
      ),
      _ReportCard(
        id: 'cash_flow',
        title: 'Cash Flow Statement',
        description:
            'Direct / Indirect cash flows broken down by Operating, Investing, Financing.',
        icon: Icons.receipt_long_rounded,
        iconBg: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF3B82F6),
        accentColor: const Color(0xFF3B82F6),
      ),
      _ReportCard(
        id: 'outstanding',
        title: 'Outstanding Analysis',
        description:
            'Receivables and Payables with 30-day interval aging buckets.',
        icon: Icons.bar_chart_rounded,
        iconBg: const Color(0xFFFFF7ED),
        iconColor: const Color(0xFFF97316),
        accentColor: const Color(0xFFF97316),
      ),
      _ReportCard(
        id: 'stock_summary',
        title: 'Stock Summary',
        description:
            'WAC Inventory valuation generated dynamically from product batches.',
        icon: Icons.inventory_2_rounded,
        iconBg: const Color(0xFFF5F3FF),
        iconColor: const Color(0xFF8B5CF6),
        accentColor: const Color(0xFF8B5CF6),
      ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _buildHeader(context, label, dateRange, isActive, isLocked),
            ),

            // ── Section title ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                child: Row(
                  children: [
                    const Text(
                      'Financial Statements',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Schedule III compliant',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
                child: Text(
                  'Comprehensive reporting complying with Schedule III constraints.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // ── Report Cards List ─────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildReportCard(
                    context,
                    reports[index],
                    storeId,
                    fyId,
                  ),
                  childCount: reports.length,
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String label,
    String dateRange,
    bool isActive,
    bool isLocked,
  ) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Back button
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Padding(
                          padding: EdgeInsets.only(right: 2),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.5,
                          ),
                        ),
                        if (dateRange.isNotEmpty)
                          Text(
                            dateRange,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Status badges
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _badge(
                        isActive ? 'Active' : 'Inactive',
                        isActive
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF94A3B8),
                        isActive
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFF8FAFC),
                      ),
                      if (isLocked) ...[
                        const SizedBox(height: 4),
                        _badge(
                          'Locked',
                          const Color(0xFFDC2626),
                          const Color(0xFFFEF2F2),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    _ReportCard report,
    String storeId,
    String fyId,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _onReportTap(context, report, storeId, fyId),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: colored icon box
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: report.iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(report.icon, size: 28, color: report.iconColor),
                ),
                const SizedBox(width: 16),
                // Middle: title + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        report.description,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // View Report link
                      Row(
                        children: [
                          Text(
                            'VIEW REPORT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: report.accentColor,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: report.accentColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Right: chevron
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: report.iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: report.iconColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onReportTap(
    BuildContext context,
    _ReportCard report,
    String storeId,
    String fyId,
  ) {
    switch (report.id) {
      case 'balance_sheet':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BalanceSheetScreen(
              storeId: storeId,
              financialYearId: fyId,
              fyLabel: financialYear['label'] ?? '',
            ),
          ),
        );
        break;
      case 'profit_loss':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProfitLossScreen(
              storeId: storeId,
              financialYearId: fyId,
              fyLabel: financialYear['label'] ?? '',
            ),
          ),
        );
        break;
      case 'cash_flow':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CashFlowScreen(
              storeId: storeId,
              financialYearId: fyId,
              fyLabel: financialYear['label'] ?? '',
            ),
          ),
        );
        break;
      case 'stock_summary':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StockSummaryScreen(
              storeId: storeId,
              financialYearId: fyId,
              fyLabel: financialYear['label'] ?? '',
            ),
          ),
        );
        break;
      case 'outstanding':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OutstandingScreen(
              storeId: storeId,
              financialYearId: fyId,
              fyLabel: financialYear['label'] ?? '',
            ),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${report.title} — Coming Soon'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }
}

class _ReportCard {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color accentColor;

  const _ReportCard({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.accentColor,
  });
}
