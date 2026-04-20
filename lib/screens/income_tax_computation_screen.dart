import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/api_service.dart';
import 'package:intl/intl.dart';

class IncomeTaxComputationScreen extends StatefulWidget {
  final String storeId;
  final String financialYearId;
  final String fyLabel;

  const IncomeTaxComputationScreen({
    super.key,
    required this.storeId,
    required this.financialYearId,
    required this.fyLabel,
  });

  @override
  State<IncomeTaxComputationScreen> createState() =>
      _IncomeTaxComputationScreenState();
}

class _IncomeTaxComputationScreenState
    extends State<IncomeTaxComputationScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;

  static const _accent = Color(0xFF7C3AED);

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
        '/reports/tax-computation/',
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
            _data = data['response'] as Map<String, dynamic>?;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data?['message'] ?? 'Failed to load Tax Computation';
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

  String _fmt(String? raw) {
    if (raw == null) return '0.00';
    try {
      final val = double.parse(raw);
      final f = NumberFormat('#,##,##0.00', 'en_IN');
      return val < 0 ? '−${f.format(val.abs())}' : f.format(val);
    } catch (_) {
      return raw;
    }
  }

  bool _isZero(String? raw) {
    try {
      return double.parse(raw ?? '0') == 0;
    } catch (_) {
      return true;
    }
  }

  // ── build ────────────────────────────────────────────────────────────────────
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
                      child: CircularProgressIndicator(color: _accent),
                    )
                  : _error != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _fetch,
                          color: _accent,
                          child: _buildContent(),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────────
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
                      'Income Tax Computation',
                      style: TextStyle(
                        fontSize: 16,
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
                    child: Icon(Icons.refresh_rounded,
                        color: Color(0xFF64748B), size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Error state ──────────────────────────────────────────────────────────────
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
              child: const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFDC2626), size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load Tax Computation',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
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
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main content ──────────────────────────────────────────────────────────────
  Widget _buildContent() {
    if (_data == null) return const SizedBox.shrink();

    final fyLabel       = _data!['fy_label']?.toString() ?? widget.fyLabel;
    final assessYear    = _data!['assessment_year']?.toString() ?? '';
    final entityType    = _data!['entity_type']?.toString() ?? '';
    final taxRegime     = _data!['tax_regime']?.toString() ?? '';
    final computation   = _data!['computation'] as Map<String, dynamic>? ?? {};
    final taxCalc       = _data!['tax_calculation'] as Map<String, dynamic>? ?? {};
    final matCheck      = _data!['mat_check'] as Map<String, dynamic>? ?? {};
    final advanceSched  = _data!['advance_tax_schedule'] as List<dynamic>? ?? [];

    // Computation fields
    final netProfit         = computation['net_profit_as_per_pnl']?.toString() ?? '0.00';
    final addBacks          = computation['add_backs'] as Map<String, dynamic>? ?? {};
    final grossTotal        = computation['gross_total_income']?.toString() ?? '0.00';
    final deductions        = computation['deductions'] as Map<String, dynamic>? ?? {};
    final netTaxable        = computation['net_taxable_income']?.toString() ?? '0.00';
    final roundedTaxable    = computation['rounded_taxable_income']?.toString() ?? '0.00';

    // Add-backs
    final depBooks      = addBacks['depreciation_books']?.toString() ?? '0.00';
    final personalExp   = addBacks['personal_expenses']?.toString() ?? '0.00';
    final provisionDbt  = addBacks['provision_dbt']?.toString() ?? '0.00';
    final otherAddBack  = addBacks['other']?.toString() ?? '0.00';
    final totalAddBacks = addBacks['total_add_backs']?.toString() ?? '0.00';

    // Deductions
    final depItAct      = deductions['depreciation_it_act']?.toString() ?? '0.00';
    final sec80ic       = deductions['section_80ic']?.toString() ?? '0.00';
    final otherDed      = deductions['other_deductions']?.toString() ?? '0.00';
    final totalDed      = deductions['total_deductions']?.toString() ?? '0.00';

    // Tax calculation
    final basicTaxRate  = taxCalc['basic_tax_rate']?.toString() ?? '';
    final basicTax      = taxCalc['basic_tax']?.toString() ?? '0.00';
    final surchargeRate = taxCalc['surcharge_rate']?.toString() ?? '';
    final surcharge     = taxCalc['surcharge']?.toString() ?? '0.00';
    final cessRate      = taxCalc['health_education_cess']?.toString() ?? '';
    final cessAmount    = taxCalc['cess_amount']?.toString() ?? '0.00';
    final totalTax      = taxCalc['total_tax']?.toString() ?? '0.00';
    final effectiveRate = taxCalc['effective_rate']?.toString() ?? '';

    // MAT
    final matRate       = matCheck['mat_rate']?.toString() ?? '';
    final bookProfit    = matCheck['book_profit']?.toString() ?? '0.00';
    final matTax        = matCheck['mat_tax']?.toString() ?? '0.00';
    final normalTax     = matCheck['normal_tax']?.toString() ?? '0.00';
    final matApplicable = matCheck['mat_applicable'] as bool? ?? false;
    final matNote       = matCheck['note']?.toString() ?? '';

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Page title ─────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Income Tax Computation',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      assessYear.isNotEmpty
                          ? '$assessYear ($fyLabel)'
                          : fyLabel,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (taxRegime.isNotEmpty) ...[
                      const Text(
                        '  •  ',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                      Text(
                        '$taxRegime Regime',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                if (entityType.isNotEmpty) const SizedBox(height: 10),
                if (entityType.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: _accent.withOpacity(0.2)),
                    ),
                    child: Text(
                      entityType,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Computation waterfall card ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
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
              child: Column(
                children: [
                  // Net Profit
                  _computationRow(
                    label: 'Net Profit as per P&L',
                    value: netProfit,
                    isBold: true,
                    isFirst: true,
                  ),

                  // Add-backs section
                  _sectionLabel('ADD: INADMISSIBLE EXPENSES'),
                  _subRow('depreciation_books', depBooks),
                  _subRow('personal_expenses', personalExp),
                  _subRow('provision_dbt', provisionDbt),
                  _subRow('other', otherAddBack),
                  _totalRow('Total Add-backs', totalAddBacks,
                      color: const Color(0xFF059669)),

                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Gross Total Income
                  _computationRow(
                    label: 'Gross Total Income',
                    value: grossTotal,
                    isBold: true,
                  ),

                  // Deductions section
                  _sectionLabel('LESS: DEDUCTIONS'),
                  _subRow('Depreciation (IT Act)', depItAct),
                  _subRow('Section 80-IC', sec80ic),
                  _subRow('Other Deductions', otherDed),
                  _totalRow('Total Deductions', totalDed,
                      color: const Color(0xFFDC2626)),

                  const Divider(height: 1, color: Color(0xFFE2E8F0)),

                  // Net Taxable Income
                  _computationRow(
                    label: 'Net Taxable Income',
                    value: netTaxable,
                    isBold: true,
                    valueColor: _accent,
                  ),

                  // Rounded
                  if (roundedTaxable != netTaxable)
                    _computationRow(
                      label: 'Rounded Taxable Income',
                      value: roundedTaxable,
                      isBold: false,
                      isLast: true,
                    )
                  else
                    const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ),

        // ── Tax Calculation card ───────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _accent.withOpacity(0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Text(
                      'Final Tax Liability',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE8E3FF)),
                  _taxRow(
                    'Basic Tax ($basicTaxRate)',
                    basicTax,
                    color: const Color(0xFF1E293B),
                  ),
                  _taxRow(
                    'Surcharge ($surchargeRate)',
                    surcharge,
                    color: _isZero(surcharge)
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF1E293B),
                  ),
                  _taxRow(
                    'Health & Education Cess ($cessRate)',
                    cessAmount,
                    color: const Color(0xFF1E293B),
                  ),
                  const Divider(height: 1, color: Color(0xFFE8E3FF)),
                  // Total row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Total Tax Payable',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        Text(
                          '₹${_fmt(totalTax)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _accent,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Effective rate badge
                  if (effectiveRate.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Effective Rate: $effectiveRate',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _accent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // ── MAT Check card ─────────────────────────────────────────────────────
        if (matCheck.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Row(
                        children: [
                          const Text(
                            'MAT Check',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: matApplicable
                                  ? const Color(0xFFFEF2F2)
                                  : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              matApplicable ? 'MAT APPLICABLE' : 'NOT APPLICABLE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: matApplicable
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF059669),
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    _taxRow('MAT Rate', matRate, isRate: true),
                    _taxRow('Book Profit', bookProfit),
                    _taxRow('MAT Tax', matTax),
                    _taxRow('Normal Tax', normalTax),
                    if (matNote.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.info_outline_rounded,
                                  color: Color(0xFFD97706), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  matNote,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF92400E),
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

        // ── Advance Tax Schedule ───────────────────────────────────────────────
        if (advanceSched.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
                      child: Text(
                        'Advance Tax Schedule',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          _hCell('INSTALMENT', flex: 3),
                          _hCell('DUE DATE'),
                          _hCell('% DUE'),
                          _hCell('AMOUNT', align: TextAlign.right),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    ...advanceSched.asMap().entries.map((e) {
                      final isLast = e.key == advanceSched.length - 1;
                      final row = e.value as Map<String, dynamic>;
                      return _advanceRow(row, isLast: isLast);
                    }),
                  ],
                ),
              ),
            ),
          ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  // ── Computation waterfall helpers ─────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _computationRow({
    required String label,
    required String value,
    bool isBold = false,
    bool isFirst = false,
    bool isLast = false,
    Color? valueColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: isFirst
            ? const BorderRadius.vertical(top: Radius.circular(16))
            : isLast
                ? const BorderRadius.vertical(bottom: Radius.circular(16))
                : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isBold ? 15 : 13,
                fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ),
          Text(
            _fmt(value),
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: FontWeight.w800,
              color: valueColor ??
                  (isBold ? const Color(0xFF1E293B) : const Color(0xFF475569)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            _fmt(value),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _isZero(value)
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {required Color color}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ),
          Text(
            _fmt(value),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _isZero(value) ? const Color(0xFF94A3B8) : color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tax row helper ────────────────────────────────────────────────────────────
  Widget _taxRow(String label, String value,
      {Color color = const Color(0xFF1E293B), bool isRate = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            isRate ? value : '₹${_fmt(value)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _isZero(isRate ? '0' : value)
                  ? const Color(0xFF94A3B8)
                  : color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Advance tax schedule helpers ──────────────────────────────────────────────
  Widget _hCell(String text,
      {int flex = 2, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF94A3B8),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _advanceRow(Map<String, dynamic> row, {bool isLast = false}) {
    final instalment = row['instalment']?.toString() ?? '';
    final dueDate    = row['due_date']?.toString() ?? '';
    final percent    = row['percentage']?.toString() ?? row['percent']?.toString() ?? '';
    final amount     = row['amount']?.toString() ?? '0.00';

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9))),
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(16))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              instalment,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              dueDate,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              percent.isNotEmpty ? '$percent%' : '–',
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '₹${_fmt(amount)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
