import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/api_service.dart';
import 'package:intl/intl.dart';

class ProfitLossScreen extends StatefulWidget {
  final String storeId;
  final String financialYearId;
  final String fyLabel;

  const ProfitLossScreen({
    super.key,
    required this.storeId,
    required this.financialYearId,
    required this.fyLabel,
  });

  @override
  State<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends State<ProfitLossScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiService.post(
        '/reports/profit-loss/',
        body: {
          'store_id': widget.storeId,
          'financial_year_id': widget.financialYearId,
        },
        useBearerToken: true,
      );
      if (mounted) {
        final data = response['data'];
        if (data != null && data['status'] == 200) {
          setState(() {
            _data = data['response'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data?['message'] ?? 'Failed to load Profit & Loss';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────────

  String _fmt(String? raw) {
    if (raw == null) return '0.00';
    try {
      final val = double.parse(raw);
      final fmt = NumberFormat('#,##,##0.00', 'en_IN');
      // prefix negative sign explicitly
      return val < 0 ? '−${fmt.format(val.abs())}' : fmt.format(val);
    } catch (_) {
      return raw;
    }
  }

  Color _amtColor(String? raw) {
    try {
      if (double.parse(raw!) < 0) return const Color(0xFFDC2626);
    } catch (_) {}
    return const Color(0xFF1E293B);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF10B981),
                      ),
                    )
                  : _error != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _fetch,
                          color: const Color(0xFF10B981),
                          child: _buildContent(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
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
                      'Profit & Loss',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (widget.fyLabel.isNotEmpty)
                      Text(
                        widget.fyLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              InkWell(
                onTap: _fetch,
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
                    child: Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF64748B),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFDC2626),
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load P&L Statement',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_data == null) return const SizedBox.shrink();

    final storeName = _data!['store_name'] ?? '';
    final fyLabel = _data!['fy_label'] ?? widget.fyLabel;
    final period = _data!['period'] ?? '';
    final isProfit = _data!['is_profit'] == true;

    final rev = _data!['revenue'] as Map<String, dynamic>? ?? {};
    final exp = _data!['expenses'] as Map<String, dynamic>? ?? {};
    final pbt = _data!['pbt']?.toString() ?? '0.00';
    final tax = _data!['tax']?.toString() ?? '0.00';
    final pat = _data!['pat']?.toString() ?? '0.00';

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    children: [
                      const Text(
                        'STATEMENT OF PROFIT & LOSS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$storeName • $period',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (fyLabel.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            fyLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Column headers ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'PARTICULARS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey[500],
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Text(
                        'AMOUNT (₹)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey[500],
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── I. Revenue from Operations ───────────────────────────
                _plRow(
                  'I. Revenue from Operations',
                  rev['revenue_from_operations']?.toString(),
                  bold: false,
                ),
                _plRow(
                  'II. Other Income',
                  rev['other_income']?.toString(),
                  bold: false,
                ),

                const SizedBox(height: 8),

                // III. Total Revenue — highlighted
                _buildHighlightRow(
                  label: 'III. Total Revenue (I + II)',
                  amount: rev['total_revenue']?.toString() ?? '0.00',
                  bgColor: const Color(0xFFF8FAFC),
                  textColor: const Color(0xFF1E293B),
                ),

                const SizedBox(height: 20),

                // ── IV. Expenses ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: const Text(
                    'IV. Expenses',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                _plRow(
                  'Cost of Materials Consumed / Purchases',
                  exp['purchases']?.toString(),
                  indent: true,
                ),
                _plRow(
                  'Changes in Inventories',
                  exp['changes_in_inventory']?.toString(),
                  indent: true,
                ),
                _plRow(
                  'Employee Benefit Expense',
                  exp['employee_benefit']?.toString(),
                  indent: true,
                ),
                _plRow(
                  'Finance Costs',
                  exp['finance_costs']?.toString(),
                  indent: true,
                ),
                _plRow(
                  'Depreciation',
                  exp['depreciation']?.toString(),
                  indent: true,
                ),
                _plRow(
                  'Other Expenses',
                  exp['other_expenses']?.toString(),
                  indent: true,
                ),

                const SizedBox(height: 8),

                // Total Expenses — highlighted
                _buildHighlightRow(
                  label: 'Total Expenses (IV)',
                  amount: exp['total_expenses']?.toString() ?? '0.00',
                  bgColor: const Color(0xFFF8FAFC),
                  textColor: const Color(0xFF1E293B),
                ),

                const SizedBox(height: 20),

                // ── V. PBT ───────────────────────────────────────────────
                _plRow('V. Profit/Loss Before Tax (III - IV)', pbt, bold: true),
                const SizedBox(height: 8),
                _plRow('VI. Tax Expense', tax, bold: false),

                const SizedBox(height: 12),

                // ── VII. PAT — green/red highlighted ─────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isProfit
                        ? const Color(0xFF10B981).withOpacity(0.08)
                        : const Color(0xFFDC2626).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isProfit
                          ? const Color(0xFF10B981).withOpacity(0.25)
                          : const Color(0xFFDC2626).withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'VII. Profit/Loss After Tax (V - VI)',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isProfit
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _fmt(pat),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isProfit
                                  ? const Color(0xFF059669)
                                  : const Color(0xFFDC2626),
                            ),
                          ),
                          // Double underline
                          Container(
                            height: 3,
                            width: 120,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isProfit
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFDC2626),
                                  width: 1.5,
                                ),
                              ),
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

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Row builders ──────────────────────────────────────────────────────────

  Widget _plRow(
    String label,
    String? amount, {
    bool bold = false,
    bool indent = false,
  }) {
    final amt = amount ?? '0.00';
    return Padding(
      padding: EdgeInsets.fromLTRB(indent ? 38 : 24, 7, 24, 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: indent ? 13.5 : 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: indent
                    ? const Color(0xFF475569)
                    : const Color(0xFF1E293B),
              ),
            ),
          ),
          Text(
            _fmt(amt),
            style: TextStyle(
              fontSize: indent ? 13.5 : 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: _amtColor(amt),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightRow({
    required String label,
    required String amount,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ),
          Text(
            _fmt(amount),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _amtColor(amount),
            ),
          ),
        ],
      ),
    );
  }
}
