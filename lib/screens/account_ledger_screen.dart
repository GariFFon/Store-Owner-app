import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/api_service.dart';
import 'package:intl/intl.dart';

class AccountLedgerScreen extends StatefulWidget {
  final String storeId;
  final String financialYearId;
  final String accountId;
  final String accountName;

  const AccountLedgerScreen({
    super.key,
    required this.storeId,
    required this.financialYearId,
    required this.accountId,
    required this.accountName,
  });

  @override
  State<AccountLedgerScreen> createState() => _AccountLedgerScreenState();
}

class _AccountLedgerScreenState extends State<AccountLedgerScreen> {
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _detail; // from /account-detail/
  Map<String, dynamic>? _ledger; // from /account-ledger/

  static const _accent = Color(0xFF2563EB);

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
      // Fire both in parallel
      final results = await Future.wait([
        ApiService.post(
          '/account-detail/',
          body: {
            'action': 'detail',
            'store_id': widget.storeId,
            'financial_year_id': widget.financialYearId,
            'account_id': widget.accountId,
          },
          useBearerToken: true,
        ),
        ApiService.post(
          '/account-ledger/',
          body: {
            'action': 'list',
            'store_id': widget.storeId,
            'financial_year_id': widget.financialYearId,
            'account_id': widget.accountId,
            'limit': 100,
          },
          useBearerToken: true,
        ),
      ]);

      if (mounted) {
        final detailData = results[0]['data'];
        final ledgerData = results[1]['data'];

        if (detailData != null && detailData['status'] == 200 &&
            ledgerData != null && ledgerData['status'] == 200) {
          setState(() {
            _detail = detailData['response'] as Map<String, dynamic>?;
            _ledger = ledgerData['response'] as Map<String, dynamic>?;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = detailData?['message'] ??
                ledgerData?['message'] ??
                'Failed to load account data';
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

  // ── Formatters ───────────────────────────────────────────────────────────────
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

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '–';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Color _voucherColor(String? type) {
    switch ((type ?? '').toUpperCase()) {
      case 'SALES':
        return const Color(0xFF059669);
      case 'CN':
        return const Color(0xFFDC2626);
      case 'PURCHASE':
        return const Color(0xFF7C3AED);
      case 'RECEIPT':
        return const Color(0xFF2563EB);
      case 'PAYMENT':
        return const Color(0xFFF97316);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _voucherBg(String? type) {
    switch ((type ?? '').toUpperCase()) {
      case 'SALES':
        return const Color(0xFFF0FDF4);
      case 'CN':
        return const Color(0xFFFEF2F2);
      case 'PURCHASE':
        return const Color(0xFFF5F3FF);
      case 'RECEIPT':
        return const Color(0xFFEFF6FF);
      case 'PAYMENT':
        return const Color(0xFFFFF7ED);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
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
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF64748B), size: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.accountName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  // ── Error ─────────────────────────────────────────────────────────────────────
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
            const Text('Failed to load account data',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B)),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown error',
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF64748B)),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
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
    if (_detail == null || _ledger == null) return const SizedBox.shrink();

    final accountName   = _detail!['name']?.toString() ?? widget.accountName;
    final groupName     = _detail!['group_name']?.toString() ?? '';
    final nature        = _detail!['nature']?.toString() ?? '';
    final closingBal    = _detail!['closing_balance']?.toString() ?? '0.00';
    final closingType   = _detail!['closing_balance_type']?.toString() ?? 'DR';
    final openingBal    = _detail!['opening_balance']?.toString() ?? '0.00';
    final openingType   = _detail!['opening_balance_type']?.toString() ?? 'DR';
    final periodDebit   = _detail!['period_debit']?.toString() ?? '0.00';
    final periodCredit  = _detail!['period_credit']?.toString() ?? '0.00';

    final transactions  = _ledger!['transactions'] as List<dynamic>? ?? [];

    final isCr = closingType.toUpperCase() == 'CR';
    final balColor = isCr ? const Color(0xFFDC2626) : const Color(0xFF059669);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Account header ───────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        accountName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (groupName.isNotEmpty) groupName,
                          if (nature.isNotEmpty) nature,
                        ].join('  •  '),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'CLOSING BALANCE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_fmt(closingBal)} $closingType',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: balColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Opening Balance + Period Movement cards ───────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                // Opening Balance
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OPENING BALANCE',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_fmt(openingBal)} $openingType',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _isZero(openingBal)
                                ? const Color(0xFF059669)
                                : openingType.toUpperCase() == 'CR'
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFF059669),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Period Movement
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PERIOD MOVEMENT',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.7,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DEBIT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFCBD5E1),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '+${_fmt(periodDebit)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF059669),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'CREDIT',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFCBD5E1),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '−${_fmt(periodCredit)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFDC2626),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Ledger section label ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'ACCOUNT LEDGER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.grey[500],
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),

        // ── Ledger table ─────────────────────────────────────────────────────
        if (transactions.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 11),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    child: Row(
                      children: [
                        _hCell('DATE', flex: 3),
                        _hCell('VOUCHER', flex: 4),
                        _hCell('DEBIT', flex: 2),
                        _hCell('CREDIT', flex: 2),
                        _hCell('RUNNING', flex: 3, align: TextAlign.right),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  // Rows
                  ...transactions.asMap().entries.map((e) {
                    final isLast = e.key == transactions.length - 1;
                    return _txRow(e.value as Map<String, dynamic>,
                        isLast: isLast);
                  }),
                ],
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: _accent, size: 26),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No transactions yet',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'No ledger entries found for this account.',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF94A3B8)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  // ── Transaction row ───────────────────────────────────────────────────────────
  Widget _txRow(Map<String, dynamic> tx, {bool isLast = false}) {
    final date         = tx['date']?.toString() ?? '';
    final voucherNo    = tx['voucher_number']?.toString() ?? '';
    final voucherType  = tx['voucher_type']?.toString() ?? '';
    final narration    = tx['narration']?.toString() ?? '';
    final debit        = tx['debit']?.toString() ?? '0.00';
    final credit       = tx['credit']?.toString() ?? '0.00';
    final runBal       = tx['running_balance']?.toString() ?? '0.00';
    final runType      = tx['running_balance_type']?.toString() ?? 'DR';

    final hasDebit  = !_isZero(debit);
    final hasCredit = !_isZero(credit);
    final runIsCr   = runType.toUpperCase() == 'CR';
    final runColor  = runIsCr ? const Color(0xFFDC2626) : const Color(0xFF059669);

    final vcColor = _voucherColor(voucherType);
    final vcBg    = _voucherBg(voucherType);

    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9))),
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(14))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date
          Expanded(
            flex: 3,
            child: Text(
              _fmtDate(date),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Voucher number + type badge
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  voucherNo,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (voucherType.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: vcBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      voucherType.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: vcColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                if (narration.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      narration,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          // Debit
          Expanded(
            flex: 2,
            child: Text(
              hasDebit ? _fmt(debit) : '',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF059669),
              ),
            ),
          ),
          // Credit
          Expanded(
            flex: 2,
            child: Text(
              hasCredit ? _fmt(credit) : '',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFDC2626),
              ),
            ),
          ),
          // Running balance
          Expanded(
            flex: 3,
            child: Text(
              '${_fmt(runBal)} $runType',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: runColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
