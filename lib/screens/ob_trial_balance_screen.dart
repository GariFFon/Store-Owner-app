import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/api_service.dart';

class OBTrialBalanceScreen extends StatefulWidget {
  final String storeId;
  final String financialYearId;
  final String fyLabel;

  const OBTrialBalanceScreen({
    super.key,
    required this.storeId,
    required this.financialYearId,
    required this.fyLabel,
  });

  @override
  State<OBTrialBalanceScreen> createState() => _OBTrialBalanceScreenState();
}

class _OBTrialBalanceScreenState extends State<OBTrialBalanceScreen> {
  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _accounts = [];
  Map<String, dynamic> _totals = {};

  final ScrollController _hScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _hScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiService.post(
        '/trial-balance/',
        body: {
          'store_id': widget.storeId,
          'financial_year_id': widget.financialYearId,
        },
        useBearerToken: true,
      );
      if (!mounted) return;
      final data = response['data'];
      final int status = data?['status'] ?? 0;
      if (status == 200 && data?['response'] is Map) {
        final r = data['response'] as Map<String, dynamic>;
        setState(() {
          _accounts = r['accounts'] is List
              ? List<Map<String, dynamic>>.from(r['accounts'] as List)
              : [];
          _totals = r['totals'] is Map
              ? Map<String, dynamic>.from(r['totals'] as Map)
              : {};
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data?['response']?.toString() ??
              'Failed to load trial balance.';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Network error. Please try again.';
        _isLoading = false;
      });
    }
  }

  // ── Column widths ──────────────────────────────────────────────────────────
  static const double _colAccount = 210.0;
  static const double _colDr = 82.0;
  static const double _colCr = 82.0;

  double get _totalTableWidth =>
      _colAccount + (_colDr + _colCr) * 3 + 3; // 3 vertical dividers

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        body: RefreshIndicator(
          onRefresh: _fetchData,
          color: const Color(0xFF2563EB),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildTopBanner(context)),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF2563EB), strokeWidth: 2.5),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(child: _buildError())
              else ...[
                SliverToBoxAdapter(child: _buildBalancedBadge()),
                SliverToBoxAdapter(child: _buildTable()),
                const SliverPadding(
                    padding: EdgeInsets.only(bottom: 60)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Banner ─────────────────────────────────────────────────────────────

  Widget _buildTopBanner(BuildContext context) {
    final isBalanced = _totals['is_balanced'] == true;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -10,
              child: Transform.rotate(
                angle: -math.pi / 10,
                child: Icon(Icons.table_chart_rounded,
                    size: 130,
                    color: const Color(0xFF2563EB).withOpacity(0.04)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back row
                  Row(
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
                            border: Border.all(
                                color: const Color(0xFFE2E8F0), width: 1.5),
                          ),
                          child: const Center(
                            child: Padding(
                              padding: EdgeInsets.only(right: 2),
                              child: Icon(Icons.arrow_back_ios_new_rounded,
                                  color: Color(0xFF1E293B), size: 18),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Refresh
                      InkWell(
                        onTap: _fetchData,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: const Color(0xFFE2E8F0), width: 1.5),
                          ),
                          child: const Center(
                            child: Icon(Icons.refresh_rounded,
                                color: Color(0xFF1E293B), size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Title
                  const Text(
                    'TRIAL BALANCE',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Financial Year Arithmetic Accuracy Check',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // FY pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF2563EB).withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded,
                            size: 12, color: Color(0xFF2563EB)),
                        const SizedBox(width: 5),
                        Text(
                          widget.fyLabel.isNotEmpty
                              ? widget.fyLabel
                              : 'Current FY',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Balanced badge ─────────────────────────────────────────────────────────

  Widget _buildBalancedBadge() {
    final isBalanced = _totals['is_balanced'] == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isBalanced
              ? const Color(0xFFF0FDF4)
              : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isBalanced
                ? const Color(0xFF16A34A).withOpacity(0.25)
                : const Color(0xFFDC2626).withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isBalanced
                  ? Icons.check_circle_rounded
                  : Icons.warning_amber_rounded,
              color: isBalanced
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626),
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              isBalanced
                  ? 'Books are balanced ✓'
                  : 'Books are NOT balanced — Please review.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isBalanced
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Table ──────────────────────────────────────────────────────────────────

  Widget _buildTable() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _hScrollCtrl,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: _totalTableWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  if (_accounts.isEmpty)
                    _buildEmptyRow()
                  else
                    ..._accounts.asMap().entries.map((e) {
                      final isEven = e.key.isEven;
                      return _buildAccountRow(e.value, shaded: isEven);
                    }),
                  const Divider(height: 1, color: Color(0xFFCBD5E1)),
                  _buildTotalRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Row(
        children: [
          _headerCell('LEDGER ACCOUNT', _colAccount, align: TextAlign.left),
          _vDivider(),
          _headerGroup('OPENING BALANCE (DR | CR)', [
            _headerCell('DR', _colDr),
            _headerCell('CR', _colCr),
          ]),
          _vDivider(),
          _headerGroup('TRANSACTIONS (DR | CR)', [
            _headerCell('DR', _colDr),
            _headerCell('CR', _colCr),
          ]),
          _vDivider(),
          _headerGroup('CLOSING BALANCE (DR | CR)', [
            _headerCell('DR', _colDr),
            _headerCell('CR', _colCr),
          ]),
        ],
      ),
    );
  }

  Widget _headerGroup(String label, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        Row(children: children),
      ],
    );
  }

  Widget _headerCell(String label, double width,
      {TextAlign align = TextAlign.center}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 0.5,
          ),
          textAlign: align,
        ),
      ),
    );
  }

  Widget _buildAccountRow(Map<String, dynamic> acc,
      {bool shaded = false}) {
    final name = acc['account_name']?.toString() ??
        acc['name']?.toString() ??
        acc['account']?.toString() ??
        '';
    final group = acc['group']?.toString() ?? '';
    final nature = acc['nature']?.toString() ?? '';
    final subtitle =
        nature.isNotEmpty ? '$group ($nature)' : '$group ()';

    final obDr = acc['opening_balance_dr']?.toString() ?? '0.00';
    final obCr = acc['opening_balance_cr']?.toString() ?? '0.00';
    final txDr = acc['period_debit']?.toString() ?? '0.00';
    final txCr = acc['period_credit']?.toString() ?? '0.00';
    final clDr = acc['closing_balance_dr']?.toString() ?? '0.00';
    final clCr = acc['closing_balance_cr']?.toString() ?? '0.00';

    return Column(
      children: [
        Container(
          color: shaded ? const Color(0xFFF8FAFC) : Colors.white,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: _colAccount,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _vDivider(),
              _dataCell(obDr, _colDr),
              _dataCell(obCr, _colCr),
              _vDivider(),
              _dataCell(txDr, _colDr),
              _dataCell(txCr, _colCr),
              _vDivider(),
              _dataCell(clDr, _colDr),
              _dataCell(clCr, _colCr),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
      ],
    );
  }

  Widget _buildEmptyRow() {
    return Container(
      color: Colors.white,
      child: Row(
        children: [
          SizedBox(
            width: _colAccount,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Text(
                '— No accounts —',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
          _vDivider(),
          _dataCell('—', _colDr, grey: true),
          _dataCell('—', _colCr, grey: true),
          _vDivider(),
          _dataCell('—', _colDr, grey: true),
          _dataCell('—', _colCr, grey: true),
          _vDivider(),
          _dataCell('—', _colDr, grey: true),
          _dataCell('—', _colCr, grey: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow() {
    final obDr = _totals['opening_balance_dr']?.toString() ?? '0.00';
    final obCr = _totals['opening_balance_cr']?.toString() ?? '0.00';
    final txDr = _totals['period_debit']?.toString() ?? '0.00';
    final txCr = _totals['period_credit']?.toString() ?? '0.00';
    final clDr = _totals['closing_balance_dr']?.toString() ?? '0.00';
    final clCr = _totals['closing_balance_cr']?.toString() ?? '0.00';

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          SizedBox(
            width: _colAccount,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Text(
                'Grand Total',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
          _vDivider(),
          _totalCell(obDr, _colDr),
          _totalCell(obCr, _colCr),
          _vDivider(),
          _totalCell(txDr, _colDr),
          _totalCell(txCr, _colCr),
          _vDivider(),
          _totalCell(clDr, _colDr),
          _totalCell(clCr, _colCr),
        ],
      ),
    );
  }

  Widget _dataCell(String value, double width, {bool grey = false}) {
    // Zero values shown with a light blue-grey tint (matching the screenshot)
    final isZero = value == '0.00' || value == '0' || value == '—';
    final Color textColor = grey || isZero
        ? const Color(0xFFAEC6CF)  // light blue-grey for zeros
        : const Color(0xFF1E293B); // dark for non-zero values
    final FontWeight fw =
        isZero ? FontWeight.w400 : FontWeight.w600;

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: textColor,
            fontWeight: fw,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _totalCell(String value, double width) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            // Double underline via stacked containers
            Container(height: 1.5, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 1.5),
            Container(height: 1.5, color: const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        color: const Color(0xFFE2E8F0),
      );

  // ── Error state ─────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFDC2626), size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load Trial Balance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
