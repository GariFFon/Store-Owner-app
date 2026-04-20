import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/screens/gst_itc_ledger_screen.dart';

class TaxComplianceDetailScreen extends StatelessWidget {
  final String storeId;
  final Map<String, dynamic> financialYear;

  const TaxComplianceDetailScreen({
    super.key,
    required this.storeId,
    required this.financialYear,
  });

  void _onReportTap(BuildContext context, String reportId) {
    final fyId = financialYear['id']?.toString() ?? '';
    final fyLabel = financialYear['label']?.toString() ?? '';

    switch (reportId) {
      case 'gst_itc_ledger':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GstItcLedgerScreen(
              storeId: storeId,
              financialYearId: fyId,
              fyLabel: fyLabel,
            ),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$reportId — Coming Soon'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fyLabel = financialYear['label']?.toString() ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Column(
          children: [
            _buildTopBar(context, fyLabel),
            Expanded(child: _buildContent(context)),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, String fyLabel) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
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
                    const Text(
                      'Tax & Compliance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (fyLabel.isNotEmpty)
                      Text(
                        fyLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
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

  // ── Content ───────────────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page heading
          const Text(
            'Tax & Compliance Center',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Statutory reports conforming to Income Tax Act 1961 and GST Act 2017.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // Grid of report cards
          _reportGrid(context),
        ],
      ),
    );
  }

  Widget _reportGrid(BuildContext context) {
    final reports = [
      _ReportCard(
        id: 'tds_report',
        title: 'TDS Report',
        subtitle:
            'Section-wise deduction analysis (194C, 194J, etc.) vs expected capability.',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFEC4899),
        bgColor: const Color(0xFFFDF2F8),
      ),
      _ReportCard(
        id: 'eway_bill',
        title: 'E-Way Bill Register',
        subtitle:
            'Live tracking of generated E-Way bills and expiry statuses.',
        icon: Icons.local_shipping_rounded,
        color: const Color(0xFFF97316),
        bgColor: const Color(0xFFFFF7ED),
      ),
      _ReportCard(
        id: 'gst_itc_recon',
        title: 'GST ITC Reconciliation',
        subtitle:
            'Books vs GSTR-2B discrepancy matching. Prevents ITC loss.',
        icon: Icons.compare_arrows_rounded,
        color: const Color(0xFFEC4899),
        bgColor: const Color(0xFFFDF2F8),
      ),
      _ReportCard(
        id: 'income_tax',
        title: 'Income Tax Computation',
        subtitle:
            'PBT to Taxable Income adjustments, MAT checks, and Advance Tax schedule.',
        icon: Icons.calculate_rounded,
        color: const Color(0xFF7C3AED),
        bgColor: const Color(0xFFF5F3FF),
      ),
      _ReportCard(
        id: 'gst_itc_ledger',
        title: 'GST Electronic Credit Ledger',
        subtitle:
            'Running balance of CGST/SGST/IGST dynamically cross-utilized via §49A.',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFF0D9488),
        bgColor: const Color(0xFFF0FDFA),
      ),
    ];

    // 2-column grid — last odd card spans full width
    final List<Widget> rows = [];
    for (int i = 0; i < reports.length; i += 2) {
      final left = reports[i];
      final hasRight = i + 1 < reports.length;
      final right = hasRight ? reports[i + 1] : null;

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildCard(context, left),
              ),
              const SizedBox(width: 14),
              hasRight
                  ? Expanded(child: _buildCard(context, right!))
                  : const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildCard(BuildContext context, _ReportCard report) {
    return GestureDetector(
      onTap: () => _onReportTap(context, report.id),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon bubble
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: report.bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(report.icon, size: 22, color: report.color),
            ),
            const SizedBox(height: 14),
            // Title
            Text(
              report.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            // Subtitle
            Text(
              report.subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            // CTA
            Row(
              children: [
                Text(
                  'VIEW REPORT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: report.color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: report.color,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _ReportCard {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _ReportCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}
