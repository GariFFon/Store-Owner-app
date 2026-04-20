import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/api_service.dart';
import 'package:intl/intl.dart';

class CashFlowScreen extends StatefulWidget {
  final String storeId;
  final String financialYearId;
  final String fyLabel;

  const CashFlowScreen({
    super.key,
    required this.storeId,
    required this.financialYearId,
    required this.fyLabel,
  });

  @override
  State<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
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
        '/reports/cash-flow/',
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
            _error = data?['message'] ?? 'Failed to load Cash Flow';
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

  // ── helpers ───────────────────────────────────────────────────────────────

  String _fmt(String? raw) {
    if (raw == null) return '0.00';
    try {
      final val = double.parse(raw);
      final fmt = NumberFormat('#,##,##0.00', 'en_IN');
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
                        color: Color(0xFF3B82F6),
                      ),
                    )
                  : _error != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _fetch,
                          color: const Color(0xFF3B82F6),
                          child: _buildContent(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

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
                      'Cash Flow Statement',
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

  // ── Error state ───────────────────────────────────────────────────────────

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
              'Failed to load Cash Flow Statement',
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
                backgroundColor: const Color(0xFF3B82F6),
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

  // ── Main content ──────────────────────────────────────────────────────────

  Widget _buildContent() {
    if (_data == null) return const SizedBox.shrink();

    final storeName = _data!['store_name'] ?? '';
    final fyLabel = _data!['fy_label'] ?? widget.fyLabel;
    final period = _data!['period'] ?? '';
    final isReconciled = _data!['is_reconciled'] == true;

    final operating = _data!['operating_activities'] as Map<String, dynamic>? ?? {};
    final investing = _data!['investing_activities'] as Map<String, dynamic>? ?? {};
    final financing = _data!['financing_activities'] as Map<String, dynamic>? ?? {};

    final netChange = _data!['net_change_in_cash']?.toString() ?? '0.00';
    final openingCash = _data!['opening_cash_balance']?.toString() ?? '0.00';
    final closingCash = _data!['closing_cash_balance']?.toString() ?? '0.00';

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
                // ── Document Header ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                  child: Column(
                    children: [
                      const Text(
                        'CASH FLOW STATEMENT (INDIRECT METHOD)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: 1.2,
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
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            fyLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // ── A. Operating Activities ──────────────────────────────
                _sectionHeader('A. Cash Flow from Operating Activities'),

                _cfRow(
                  'Net Profit Before Tax',
                  operating['net_profit_before_tax']?.toString(),
                ),

                // Adjustments sub-header
                if ((operating['adjustments'] as List?)?.isNotEmpty == true) ...[
                  _miniHeader('ADJUSTMENTS FOR NON-CASH/NON-OPERATING ITEMS'),
                  for (final item
                      in (operating['adjustments'] as List<dynamic>))
                    _cfRow(
                      item['label']?.toString() ?? '',
                      item['amount']?.toString(),
                      indent: true,
                    ),
                ] else
                  _miniHeader('ADJUSTMENTS FOR NON-CASH/NON-OPERATING ITEMS'),

                // Working capital changes
                if ((operating['working_capital_changes'] as List?)?.isNotEmpty == true) ...[
                  _miniHeader('CHANGES IN WORKING CAPITAL'),
                  for (final item
                      in (operating['working_capital_changes'] as List<dynamic>))
                    _cfRow(
                      item['label']?.toString() ?? '',
                      item['amount']?.toString(),
                      indent: true,
                    ),
                ] else
                  _miniHeader('CHANGES IN WORKING CAPITAL'),

                _cfRow(
                  'Cash Generated from Operations',
                  operating['cash_generated_from_operations']?.toString(),
                ),
                _cfRow(
                  'Taxes Paid',
                  operating['taxes_paid']?.toString(),
                ),

                const SizedBox(height: 8),
                _netRow(
                  'Net Cash from Operating Activities (A)',
                  operating['net_cash_from_operations']?.toString() ?? '0.00',
                ),
                const SizedBox(height: 20),

                // ── B. Investing Activities ──────────────────────────────
                _sectionHeader('B. Cash Flow from Investing Activities'),

                if ((investing['items'] as List?)?.isNotEmpty == true)
                  for (final item in (investing['items'] as List<dynamic>))
                    _cfRow(
                      item['label']?.toString() ?? '',
                      item['amount']?.toString(),
                      indent: true,
                    ),

                const SizedBox(height: 8),
                _netRow(
                  'Net Cash from Investing Activities (B)',
                  investing['net_cash_from_investing']?.toString() ?? '0.00',
                ),
                const SizedBox(height: 20),

                // ── C. Financing Activities ──────────────────────────────
                _sectionHeader('C. Cash Flow from Financing Activities'),

                if ((financing['items'] as List?)?.isNotEmpty == true)
                  for (final item in (financing['items'] as List<dynamic>))
                    _cfRow(
                      item['label']?.toString() ?? '',
                      item['amount']?.toString(),
                      indent: true,
                    ),

                const SizedBox(height: 8),
                _netRow(
                  'Net Cash from Financing Activities (C)',
                  financing['net_cash_from_financing']?.toString() ?? '0.00',
                ),

                const SizedBox(height: 24),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                // ── Summary: Net Change + Opening + Closing ──────────────
                _cfRow(
                  'Net Increase / (Decrease) in Cash (A+B+C)',
                  netChange,
                  bold: true,
                ),
                _cfRow('Opening Cash & Cash Equivalents', openingCash),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Closing Cash & Cash Equivalents',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _fmt(closingCash),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _amtColor(closingCash),
                            ),
                          ),
                          // Double underline
                          Container(
                            height: 3,
                            width: 120,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Color(0xFF1E293B),
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

                const SizedBox(height: 16),

                // ── Reconciliation banner ────────────────────────────────
                if (!isReconciled)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFDC2626),
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Validation Error: Cash Flow closing balance does not equal physical ledger closing balance.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF16A34A),
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Cash Flow is reconciled.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A),
                          ),
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

  // ── Widget builders ───────────────────────────────────────────────────────

  /// Blue section heading e.g. "A. Cash Flow from Operating Activities"
  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF2563EB),
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  /// Small grey sub-header e.g. "ADJUSTMENTS FOR NON-CASH ITEMS"
  Widget _miniHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Colors.grey[500],
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  /// Standard data row
  Widget _cfRow(
    String label,
    String? amount, {
    bool indent = false,
    bool bold = false,
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
                fontSize: indent ? 13 : 14,
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
              fontSize: indent ? 13 : 14,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
              color: _amtColor(amt),
            ),
          ),
        ],
      ),
    );
  }

  /// Net totals row — light grey highlighted box
  Widget _netRow(String label, String amount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
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
