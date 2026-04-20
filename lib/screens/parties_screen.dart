import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/screens/account_ledger_screen.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PartiesScreen — lists all parties
// ─────────────────────────────────────────────────────────────────────────────
class PartiesScreen extends StatefulWidget {
  final String storeId;
  final String financialYearId;
  final String fyLabel;

  const PartiesScreen({
    super.key,
    required this.storeId,
    required this.financialYearId,
    required this.fyLabel,
  });

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _parties = [];

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
      final res = await ApiService.post(
        '/parties/',
        body: {'action': 'list', 'store_id': widget.storeId},
        useBearerToken: true,
      );
      final data = res['data'];
      if (mounted) {
        if (data != null && data['status'] == 200) {
          setState(() {
            _parties =
                List<Map<String, dynamic>>.from(data['response'] ?? []);
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data?['message'] ?? 'Failed to load parties';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
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
                  ? const Center(child: CircularProgressIndicator(color: _accent))
                  : _error != null
                      ? _buildError()
                      : RefreshIndicator(
                          onRefresh: _fetch,
                          color: _accent,
                          child: _buildList(),
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
                  width: 40, height: 40,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Parties Master',
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B), letterSpacing: -0.3,
                        )),
                    if (widget.fyLabel.isNotEmpty)
                      Text(widget.fyLabel,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              InkWell(
                onTap: _fetch,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 40, height: 40,
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

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFDC2626), size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Failed to load parties',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text(_error ?? '', style: const TextStyle(
                fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_parties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.people_outline_rounded,
                  color: _accent, size: 28),
            ),
            const SizedBox(height: 12),
            const Text('No parties found',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header row
        Container(
          color: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: const Row(
            children: [
              Expanded(
                flex: 6,
                child: Text('Party Name',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B), letterSpacing: 0.2)),
              ),
              SizedBox(
                width: 90,
                child: Text('Type', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B), letterSpacing: 0.2)),
              ),
              SizedBox(
                width: 70,
                child: Text('GSTIN', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B), letterSpacing: 0.2)),
              ),
              SizedBox(
                width: 80,
                child: Text('Credit Limit', textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                        color: Color(0xFF64748B), letterSpacing: 0.2)),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),
        Expanded(
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _parties.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
            itemBuilder: (ctx, i) => _buildRow(_parties[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(Map<String, dynamic> p) {
    final name        = p['name']?.toString() ?? '';
    final accountName = p['account_name']?.toString() ?? '';
    final isCustomer  = p['is_customer'] == true;
    final gstin       = p['gstin']?.toString() ?? '';
    final credit      = p['credit_limit']?.toString() ?? '0.00';
    final partyId     = p['party_id']?.toString() ?? '';

    return InkWell(
      onTap: partyId.isNotEmpty
          ? () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PartyDetailScreen(
                  storeId: widget.storeId,
                  financialYearId: widget.financialYearId,
                  partyId: partyId,
                  partyName: name,
                ),
              ))
          : null,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Name + account name
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (accountName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(accountName,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w400),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            // Type badge
            SizedBox(
              width: 90,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCustomer
                        ? const Color(0xFFEFF6FF)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isCustomer ? 'CUSTOMER' : 'VENDOR',
                    style: TextStyle(
                      fontSize: 9.5, fontWeight: FontWeight.w800,
                      color: isCustomer
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFDC2626),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
            // GSTIN
            SizedBox(
              width: 70,
              child: Text(
                gstin.isEmpty ? '–' : gstin,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500),
              ),
            ),
            // Credit limit
            SizedBox(
              width: 80,
              child: Text(
                _fmtNum(credit),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtNum(String? raw) {
    try {
      final v = double.parse(raw ?? '0');
      return NumberFormat('#,##,##0.00', 'en_IN').format(v);
    } catch (_) { return raw ?? '0.00'; }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PartyDetailScreen — party detail + ledger
// ─────────────────────────────────────────────────────────────────────────────
class PartyDetailScreen extends StatefulWidget {
  final String storeId;
  final String financialYearId;
  final String partyId;
  final String partyName;

  const PartyDetailScreen({
    super.key,
    required this.storeId,
    required this.financialYearId,
    required this.partyId,
    required this.partyName,
  });

  @override
  State<PartyDetailScreen> createState() => _PartyDetailScreenState();
}

class _PartyDetailScreenState extends State<PartyDetailScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _detail;

  static const _accent = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await ApiService.post(
        '/party-detail/',
        body: {
          'action': 'detail',
          'store_id': widget.storeId,
          'financial_year_id': widget.financialYearId,
          'party_id': widget.partyId,
        },
        useBearerToken: true,
      );
      final data = res['data'];
      if (mounted) {
        if (data != null && data['status'] == 200) {
          setState(() {
            _detail = data['response'] as Map<String, dynamic>?;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data?['message'] ?? 'Failed to load party detail';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ── Formatters ─────────────────────────────────────────────────────────────
  String _fmt(String? raw) {
    try {
      final v = double.parse(raw ?? '0');
      return NumberFormat('#,##,##0.00', 'en_IN').format(v.abs());
    } catch (_) { return raw ?? '0.00'; }
  }

  bool _isZero(String? raw) {
    try { return double.parse(raw ?? '0') == 0; } catch (_) { return true; }
  }

  String _fmtDate(String? raw) {
    if (raw == null || raw.isEmpty) return '–';
    try { return DateFormat('dd MMM yyyy').format(DateTime.parse(raw)); }
    catch (_) { return raw; }
  }

  Color _voucherColor(String? type) {
    switch ((type ?? '').toUpperCase()) {
      case 'SALES': return const Color(0xFF059669);
      case 'CN':    return const Color(0xFFDC2626);
      case 'PURCHASE': return const Color(0xFF7C3AED);
      case 'RECEIPT':  return const Color(0xFF2563EB);
      case 'PAYMENT':  return const Color(0xFFF97316);
      default:         return const Color(0xFF64748B);
    }
  }

  Color _voucherBg(String? type) {
    switch ((type ?? '').toUpperCase()) {
      case 'SALES': return const Color(0xFFF0FDF4);
      case 'CN':    return const Color(0xFFFEF2F2);
      case 'PURCHASE': return const Color(0xFFF5F3FF);
      case 'RECEIPT':  return const Color(0xFFEFF6FF);
      case 'PAYMENT':  return const Color(0xFFFFF7ED);
      default:         return const Color(0xFFF1F5F9);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────
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
                  ? const Center(child: CircularProgressIndicator(color: _accent))
                  : _error != null
                      ? _buildError()
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
                  width: 40, height: 40,
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
                child: Text(widget.partyName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B), letterSpacing: -0.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              InkWell(
                onTap: _fetch,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 40, height: 40,
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

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFDC2626), size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Failed to load party detail',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text(_error ?? '',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetch,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_detail == null) return const SizedBox.shrink();

    final name        = _detail!['name']?.toString() ?? widget.partyName;
    final gstin       = _detail!['gstin']?.toString() ?? '';
    final partyType   = _detail!['party_type']?.toString() ?? '';
    final accountId   = _detail!['account_id']?.toString() ?? '';

    final outstanding = _detail!['outstanding'] as Map<String, dynamic>?;
    final outAmt      = outstanding?['net_payable_or_receivable']?.toString() ?? '0.00';
    final direction   = outstanding?['direction']?.toString() ?? '';
    final closingBal  = outstanding?['closing_balance']?.toString() ?? '0.00';
    final closingType = outstanding?['closing_balance_type']?.toString() ?? 'DR';

    final ledger = _detail!['ledger'] as List<dynamic>? ?? [];

    final isCr = closingType.toUpperCase() == 'CR';
    final balColor = isCr ? const Color(0xFFDC2626) : const Color(0xFF059669);
    final isPayable = direction.toUpperCase() == 'PAYABLE';
    final outColor  = isPayable ? const Color(0xFFDC2626) : const Color(0xFF059669);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Header ─────────────────────────────────────────────────────────
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
                      Text(name,
                          style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B), letterSpacing: -0.5,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        'GSTIN: ${gstin.isEmpty ? 'N/A' : gstin}  •  $partyType',
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('CLOSING BALANCE',
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800,
                            color: Color(0xFF94A3B8), letterSpacing: 0.7)),
                    const SizedBox(height: 3),
                    Text('${_fmt(closingBal)} $closingType',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900,
                            color: balColor, letterSpacing: -0.4)),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── View Linked Account button ──────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: OutlinedButton.icon(
              onPressed: accountId.isNotEmpty
                  ? () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AccountLedgerScreen(
                          storeId: widget.storeId,
                          financialYearId: widget.financialYearId,
                          accountId: accountId,
                          accountName: name,
                        ),
                      ))
                  : null,
              icon: const Icon(Icons.account_balance_rounded, size: 18),
              label: const Text('View Linked Account Profile',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: const BorderSide(color: _accent, width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),

        // ── Current Outstanding card ────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Column(
                children: [
                  const Text('CURRENT OUTSTANDING',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                          color: Color(0xFF94A3B8), letterSpacing: 0.8)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(_fmt(outAmt),
                          style: TextStyle(
                              fontSize: 40, fontWeight: FontWeight.w900,
                              color: outColor, letterSpacing: -1.5)),
                      const SizedBox(width: 8),
                      Text(direction.toUpperCase(),
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800,
                              color: outColor)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Ledger label ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text('ACCOUNT LEDGER',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                    color: Colors.grey[500], letterSpacing: 0.8)),
          ),
        ),

        // ── Ledger table ────────────────────────────────────────────────────
        if (ledger.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8, offset: const Offset(0, 3))],
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
                        _hCell('DEBIT', flex: 2, align: TextAlign.right),
                        _hCell('CREDIT', flex: 2, align: TextAlign.right),
                        _hCell('RUNNING', flex: 3, align: TextAlign.right),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  ...ledger.asMap().entries.map((e) =>
                      _txRow(e.value as Map<String, dynamic>,
                          isLast: e.key == ledger.length - 1)),
                ],
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.receipt_long_rounded,
                      color: _accent, size: 28),
                  SizedBox(height: 10),
                  Text('No transactions yet',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B))),
                ],
              ),
            ),
          ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  Widget _txRow(Map<String, dynamic> tx, {bool isLast = false}) {
    final date        = tx['date']?.toString() ?? '';
    final voucherNo   = tx['voucher_number']?.toString() ?? '';
    final voucherType = tx['voucher_type']?.toString() ?? '';
    final debit       = tx['debit']?.toString() ?? '0.00';
    final credit      = tx['credit']?.toString() ?? '0.00';
    final runBal      = tx['running_balance']?.toString() ?? '0.00';
    final runType     = tx['running_balance_type']?.toString() ?? 'DR';

    final hasDebit  = !_isZero(debit);
    final hasCredit = !_isZero(credit);
    final runIsCr   = runType.toUpperCase() == 'CR';
    final runColor  = runIsCr ? const Color(0xFFDC2626) : const Color(0xFF059669);

    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : const Border(
            bottom: BorderSide(color: Color(0xFFF1F5F9))),
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(14))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(_fmtDate(date),
                style: const TextStyle(fontSize: 12,
                    color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(voucherNo,
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                if (voucherType.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: _voucherBg(voucherType),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(voucherType.toUpperCase(),
                        style: TextStyle(fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: _voucherColor(voucherType),
                            letterSpacing: 0.3)),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(hasDebit ? _fmt(debit) : '',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700, color: Color(0xFF059669))),
          ),
          Expanded(
            flex: 2,
            child: Text(hasCredit ? _fmt(credit) : '',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
          ),
          Expanded(
            flex: 3,
            child: Text('${_fmt(runBal)} $runType',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w800, color: runColor)),
          ),
        ],
      ),
    );
  }

  Widget _hCell(String text,
      {int flex = 2, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(text, textAlign: align,
          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8), letterSpacing: 0.6)),
    );
  }
}
