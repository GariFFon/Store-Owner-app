import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/api_service.dart';
import 'package:intl/intl.dart';

class BalanceSheetScreen extends StatefulWidget {
  final String storeId;
  final String financialYearId;
  final String fyLabel;

  const BalanceSheetScreen({
    super.key,
    required this.storeId,
    required this.financialYearId,
    required this.fyLabel,
  });

  @override
  State<BalanceSheetScreen> createState() => _BalanceSheetScreenState();
}

class _BalanceSheetScreenState extends State<BalanceSheetScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _fetchBalanceSheet();
  }

  Future<void> _fetchBalanceSheet() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiService.post(
        '/reports/balance-sheet/',
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
            _error = data?['message'] ?? 'Failed to load Balance Sheet';
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
                        color: Color(0xFF2563EB),
                      ),
                    )
                  : _error != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _fetchBalanceSheet,
                          color: const Color(0xFF2563EB),
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
                      'Balance Sheet',
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
              // Refresh
              InkWell(
                onTap: _fetchBalanceSheet,
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
              'Failed to load Balance Sheet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchBalanceSheet,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
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
    final asOf = _data!['as_of'] ?? '';
    final fyLabel = _data!['fy_label'] ?? widget.fyLabel;
    final isBalanced = _data!['is_balanced'] == true;
    final difference = _data!['difference'] ?? '0.00';
    final equityLiabilities =
        _data!['equity_and_liabilities'] as Map<String, dynamic>? ?? {};
    final assets = _data!['assets'] as Map<String, dynamic>? ?? {};

    // asOf is already a readable date string from the API (e.g. 2027-03-31)

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── Main Card ──────────────────────────────────────────────────────
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
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  child: Column(
                    children: [
                      Text(
                        'BALANCE SHEET',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$storeName • As of: $asOf',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (fyLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            fyLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Column headers
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

                // ── I. EQUITY & LIABILITIES ─────────────────────────────────
                _buildSection(
                  sectionTitle: 'I. EQUITY & LIABILITIES',
                  children: [
                    ..._buildShareholdersFunds(
                      equityLiabilities['shareholders_funds']
                              as Map<String, dynamic>? ??
                          {},
                    ),
                    ..._buildNonCurrentLiabilities(
                      equityLiabilities['non_current_liabilities']
                              as Map<String, dynamic>? ??
                          {},
                    ),
                    ..._buildCurrentLiabilities(
                      equityLiabilities['current_liabilities']
                              as Map<String, dynamic>? ??
                          {},
                    ),
                  ],
                ),

                // Total Equity & Liabilities
                _buildTotalRow(
                  label: 'Total Equity & Liabilities',
                  amount: equityLiabilities['total_equity_liabilities']
                          ?.toString() ??
                      '0.00',
                ),

                const SizedBox(height: 16),

                // ── II. ASSETS ───────────────────────────────────────────────
                _buildSection(
                  sectionTitle: 'II. ASSETS',
                  children: [
                    ..._buildNonCurrentAssets(
                      assets['non_current_assets'] as Map<String, dynamic>? ??
                          {},
                    ),
                    ..._buildCurrentAssets(
                      assets['current_assets'] as Map<String, dynamic>? ?? {},
                    ),
                  ],
                ),

                // Total Assets
                _buildTotalRow(
                  label: 'Total Assets',
                  amount: assets['total_assets']?.toString() ?? '0.00',
                ),

                const SizedBox(height: 16),

                // ── Balance status ───────────────────────────────────────────
                if (!isBalanced)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFDC2626),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Error: Balance Sheet is not balanced. Difference: $difference',
                            style: const TextStyle(
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
                          'Balance Sheet is balanced.',
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

          const SizedBox(height: 16),

          // ── Audit Metadata ─────────────────────────────────────────────────
          if (_data!['audit_metadata'] != null)
            _buildAuditMetadata(
              _data!['audit_metadata'] as Map<String, dynamic>,
            ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Section builder ───────────────────────────────────────────────────────

  Widget _buildSection({
    required String sectionTitle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Text(
            sectionTitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2563EB),
              letterSpacing: 0.3,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildSubSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey[500],
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildLineItem({
    required String label,
    required String amount,
    bool isBold = false,
    bool isSubItem = false,
    bool isNetProfit = false,
    int indentLevel = 0,
  }) {
    final leftPad = 24.0 + (indentLevel * 14.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(leftPad, 6, 24, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isSubItem ? 13 : 14,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: isNetProfit
                    ? const Color(0xFF0891B2)
                    : isSubItem
                        ? const Color(0xFF64748B)
                        : const Color(0xFF1E293B),
              ),
            ),
          ),
          Text(
            _formatAmount(amount),
            style: TextStyle(
              fontSize: isSubItem ? 13 : 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isNetProfit
                  ? const Color(0xFF0891B2)
                  : isSubItem
                      ? const Color(0xFF64748B)
                      : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupItem(String groupName, String total, List<dynamic> accounts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group row
        Padding(
          padding: const EdgeInsets.fromLTRB(38, 6, 24, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  groupName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              Text(
                _formatAmount(total),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubTotal(String amount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 12),
      child: Row(
        children: [
          const Expanded(child: SizedBox()),
          Container(
            padding: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Text(
              _formatAmount(amount),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow({required String label, required String amount}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                _formatAmount(amount),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              // Double underline
              Container(
                height: 3,
                width: 120,
                margin: const EdgeInsets.only(top: 2),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF1E293B), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Equity & Liabilities builders ─────────────────────────────────────────

  List<Widget> _buildShareholdersFunds(Map<String, dynamic> data) {
    final widgets = <Widget>[];
    widgets.add(_buildSubSection('1. SHAREHOLDERS\' FUNDS'));

    // Share capital
    final shareCapital = data['share_capital'] as Map<String, dynamic>? ?? {};
    final shareCapitalTotal = shareCapital['total']?.toString() ?? '0.00';
    if (_isNonZero(shareCapitalTotal)) {
      widgets.add(_buildLineItem(
        label: '(a) Share Capital',
        amount: shareCapitalTotal,
        isBold: true,
        indentLevel: 1,
      ));
    }

    // Reserves & surplus
    final reserves = data['reserves_and_surplus'] as Map<String, dynamic>? ?? {};
    final reservesTotal = reserves['total']?.toString() ?? '0.00';
    if (_isNonZero(reservesTotal)) {
      widgets.add(_buildLineItem(
        label: '(b) Reserves & Surplus',
        amount: reservesTotal,
        isBold: true,
        indentLevel: 1,
      ));
      // Net profit
      final netProfit = reserves['net_profit_for_period']?.toString();
      if (netProfit != null && _isNonZero(netProfit)) {
        widgets.add(_buildLineItem(
          label: 'Net Profit Transferred',
          amount: netProfit,
          isSubItem: true,
          isNetProfit: true,
          indentLevel: 2,
        ));
      }
    }

    // Subtotal
    final total = data['total']?.toString() ?? '0.00';
    if (_isNonZero(total)) {
      widgets.add(_buildSubTotal(total));
    }

    return widgets;
  }

  List<Widget> _buildNonCurrentLiabilities(Map<String, dynamic> data) {
    final widgets = <Widget>[];
    widgets.add(_buildSubSection('2. NON-CURRENT LIABILITIES'));

    final subs = {
      'long_term_borrowings': '(a) Long Term Borrowings',
      'deferred_tax_liabilities': '(b) Deferred Tax Liabilities',
      'other_long_term_liabilities': '(c) Other Long Term Liabilities',
    };
    for (var entry in subs.entries) {
      final sub = data[entry.key] as Map<String, dynamic>? ?? {};
      final t = sub['total']?.toString() ?? '0.00';
      if (_isNonZero(t)) {
        widgets.add(_buildLineItem(
          label: entry.value,
          amount: t,
          isBold: true,
          indentLevel: 1,
        ));
        _addGroupRows(sub['groups'] as List<dynamic>? ?? [], widgets);
      }
    }

    final total = data['total']?.toString() ?? '0.00';
    if (_isNonZero(total)) {
      widgets.add(_buildSubTotal(total));
    }

    return widgets;
  }

  List<Widget> _buildCurrentLiabilities(Map<String, dynamic> data) {
    final widgets = <Widget>[];
    widgets.add(_buildSubSection('3. CURRENT LIABILITIES'));

    final subs = {
      'short_term_borrowings': '(a) Short Term Borrowings',
      'trade_payables': '(b) Trade Payables',
      'duties_and_taxes': '(c) Duties & Taxes',
      'provisions': '(d) Provisions',
      'other_current_liabilities': '(e) Other Current Liabilities',
    };

    for (var entry in subs.entries) {
      final sub = data[entry.key] as Map<String, dynamic>? ?? {};
      final t = sub['total']?.toString() ?? '0.00';
      if (_isNonZero(t)) {
        widgets.add(_buildLineItem(
          label: entry.value,
          amount: t,
          isBold: true,
          indentLevel: 1,
        ));
        _addGroupRows(sub['groups'] as List<dynamic>? ?? [], widgets);
      }
    }

    final total = data['total']?.toString() ?? '0.00';
    if (_isNonZero(total)) {
      widgets.add(_buildSubTotal(total));
    }

    return widgets;
  }

  // ── Asset builders ────────────────────────────────────────────────────────

  List<Widget> _buildNonCurrentAssets(Map<String, dynamic> data) {
    final widgets = <Widget>[];
    widgets.add(_buildSubSection('1. NON-CURRENT ASSETS'));

    final subs = {
      'tangible_fixed_assets': '(a) Tangible Fixed Assets',
      'intangible_assets': '(b) Intangible Assets',
      'capital_work_in_progress': '(c) Capital Work in Progress',
      'non_current_investments': '(d) Non-Current Investments',
      'long_term_loans_and_advances': '(e) Long Term Loans & Advances',
      'other_non_current_assets': '(f) Other Non-Current Assets',
    };

    bool hasAny = false;
    for (var entry in subs.entries) {
      final sub = data[entry.key] as Map<String, dynamic>? ?? {};
      final t = sub['total']?.toString() ?? '0.00';
      if (_isNonZero(t)) {
        hasAny = true;
        widgets.add(_buildLineItem(
          label: entry.value,
          amount: t,
          isBold: true,
          indentLevel: 1,
        ));
        _addGroupRows(sub['groups'] as List<dynamic>? ?? [], widgets);
      }
    }

    final total = data['total']?.toString() ?? '0.00';
    if (hasAny && _isNonZero(total)) {
      widgets.add(_buildSubTotal(total));
    }

    return widgets;
  }

  List<Widget> _buildCurrentAssets(Map<String, dynamic> data) {
    final widgets = <Widget>[];
    widgets.add(_buildSubSection('2. CURRENT ASSETS'));

    // Inventories
    final inv = data['inventories'] as Map<String, dynamic>? ?? {};
    final invTotal = inv['total']?.toString() ?? '0.00';
    if (_isNonZero(invTotal)) {
      widgets.add(_buildLineItem(
        label: '(a) Inventories',
        amount: invTotal,
        isBold: true,
        indentLevel: 1,
      ));
      final closingStock = inv['closing_stock']?.toString();
      if (closingStock != null && _isNonZero(closingStock)) {
        widgets.add(_buildLineItem(
          label: 'Closing Stock',
          amount: closingStock,
          isSubItem: true,
          indentLevel: 2,
        ));
      }
    }

    // Trade receivables
    final tr = data['trade_receivables'] as Map<String, dynamic>? ?? {};
    final trTotal = tr['total']?.toString() ?? '0.00';
    if (_isNonZero(trTotal)) {
      widgets.add(_buildLineItem(
        label: '(b) Trade Receivables',
        amount: trTotal,
        isBold: true,
        indentLevel: 1,
      ));
      _addGroupRows(tr['groups'] as List<dynamic>? ?? [], widgets);
    }

    // Cash & cash equivalents
    final cash = data['cash_and_cash_equivalents'] as Map<String, dynamic>? ?? {};
    final cashTotal = cash['total']?.toString() ?? '0.00';
    if (_isNonZero(cashTotal)) {
      widgets.add(_buildLineItem(
        label: '(c) Cash & Cash Equivalents',
        amount: cashTotal,
        isBold: true,
        indentLevel: 1,
      ));
      _addGroupRows(cash['groups'] as List<dynamic>? ?? [], widgets);
    }

    // Short term loans
    final stl = data['short_term_loans_and_advances'] as Map<String, dynamic>? ?? {};
    final stlTotal = stl['total']?.toString() ?? '0.00';
    if (_isNonZero(stlTotal)) {
      widgets.add(_buildLineItem(
        label: '(d) Short Term Loans & Advances',
        amount: stlTotal,
        isBold: true,
        indentLevel: 1,
      ));
      _addGroupRows(stl['groups'] as List<dynamic>? ?? [], widgets);
    }

    // Other current assets
    final oca = data['other_current_assets'] as Map<String, dynamic>? ?? {};
    final ocaTotal = oca['total']?.toString() ?? '0.00';
    if (_isNonZero(ocaTotal)) {
      widgets.add(_buildLineItem(
        label: '(e) Other Current Assets',
        amount: ocaTotal,
        isBold: true,
        indentLevel: 1,
      ));
      _addGroupRows(oca['groups'] as List<dynamic>? ?? [], widgets);
    }

    final total = data['total']?.toString() ?? '0.00';
    if (_isNonZero(total)) {
      widgets.add(_buildSubTotal(total));
    }

    return widgets;
  }

  void _addGroupRows(List<dynamic> groups, List<Widget> widgets) {
    for (final g in groups) {
      final group = g as Map<String, dynamic>;
      final groupName = group['group']?.toString() ?? '';
      final groupTotal = group['total']?.toString() ?? '0.00';
      widgets.add(_buildGroupItem(
        groupName,
        groupTotal,
        group['accounts'] as List<dynamic>? ?? [],
      ));
    }
  }

  Widget _buildAuditMetadata(Map<String, dynamic> meta) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  size: 16,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Audit Metadata',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),
          ...meta.entries.map((e) {
            final key = e.key
                .replaceAll('_', ' ')
                .split(' ')
                .map((w) => w[0].toUpperCase() + w.substring(1))
                .join(' ');
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      key,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value?.toString() ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isNonZero(String amount) {
    try {
      return double.parse(amount) != 0.0;
    } catch (_) {
      return false;
    }
  }

  String _formatAmount(String raw) {
    try {
      final val = double.parse(raw);
      final fmt = NumberFormat('#,##,##0.00', 'en_IN');
      return fmt.format(val);
    } catch (_) {
      return raw;
    }
  }
}

