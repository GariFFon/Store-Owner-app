import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/api_service.dart';
import 'package:intl/intl.dart';

class OpeningBalancesScreen extends StatefulWidget {
  final String storeId;
  final List<Map<String, dynamic>> financialYears;
  final String initialFyId;
  final String initialFyLabel;

  const OpeningBalancesScreen({
    super.key,
    required this.storeId,
    required this.financialYears,
    required this.initialFyId,
    required this.initialFyLabel,
  });

  @override
  State<OpeningBalancesScreen> createState() => _OpeningBalancesScreenState();
}

class _OpeningBalancesScreenState extends State<OpeningBalancesScreen> {
  bool _isLoading = true;
  String? _error;

  late String _selectedFyId;
  late String _selectedFyLabel;

  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic> _summary = {};

  static const _accent = Color(0xFF2563EB);
  final _numFmt = NumberFormat('#,##,##0.00', 'en_IN');

  @override
  void initState() {
    super.initState();
    _selectedFyId    = widget.initialFyId;
    _selectedFyLabel = widget.initialFyLabel;
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await ApiService.post(
        '/opening-balances-master/',
        body: {
          'store_id': widget.storeId,
          'financial_year_id': _selectedFyId,
        },
        useBearerToken: true,
      );
      final data = res['data'];
      if (mounted) {
        if (data != null && data['status'] == 200) {
          final resp = data['response'] as Map<String, dynamic>;
          setState(() {
            _records = List<Map<String, dynamic>>.from(resp['records'] ?? []);
            _summary = (resp['summary'] as Map<String, dynamic>?) ?? {};
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = data?['message'] ?? 'Failed to load opening balances';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted)
        setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  String _fmt(String? raw) {
    try { return _numFmt.format(double.parse(raw ?? '0').abs()); }
    catch (_) { return raw ?? '0.00'; }
  }

  // ── FY picker dialog ────────────────────────────────────────────────────────
  void _showFyPicker() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Financial Year',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B), letterSpacing: -0.4)),
              const SizedBox(height: 16),
              ...widget.financialYears.map((fy) {
                final id    = fy['id']?.toString() ?? '';
                final label = fy['label']?.toString() ?? id;
                final isActive   = fy['is_active'] == true;
                final isSelected = id == _selectedFyId;
                return InkWell(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    if (id != _selectedFyId) {
                      setState(() {
                        _selectedFyId    = id;
                        _selectedFyLabel = label;
                      });
                      _fetch();
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _accent.withOpacity(0.08)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isSelected
                              ? _accent.withOpacity(0.3)
                              : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(label,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? _accent
                                      : const Color(0xFF1E293B))),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(6)),
                            child: const Text('Active',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF059669))),
                          ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle_rounded,
                              color: _accent, size: 18),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(
                          fontSize: 14, color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                  ? const Center(
                      child: CircularProgressIndicator(color: _accent))
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Opening Balances',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B), letterSpacing: -0.3)),
                    if (_selectedFyLabel.isNotEmpty)
                      Text(_selectedFyLabel,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              // Refresh
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
              const SizedBox(width: 10),
              // FY picker button
              GestureDetector(
                onTap: _showFyPicker,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 15, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: Color(0xFF64748B)),
                    ],
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
              decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFDC2626), size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Failed to load opening balances',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B)),
                textAlign: TextAlign.center),
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
    final totalDebit  = _summary['total_debit']?.toString() ?? '0.00';
    final totalCredit = _summary['total_credit']?.toString() ?? '0.00';
    final gap         = _summary['gap']?.toString() ?? '0.00';
    final isBalanced  = _summary['is_balanced'] == true;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Title row ────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Opening Balances ($_selectedFyLabel)',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B), letterSpacing: -0.4),
                  ),
                ),
                if (isBalanced)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFF059669).withOpacity(0.3))),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            size: 14, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Text('Balanced',
                            style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669))),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFDC2626).withOpacity(0.3))),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 14, color: Color(0xFFDC2626)),
                        SizedBox(width: 4),
                        Text('Unbalanced',
                            style: TextStyle(fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ── Summary cards ────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(child: _summaryCard(
                  label: 'TOTAL DEBIT',
                  value: _fmt(totalDebit),
                  color: const Color(0xFF059669),
                  bg: const Color(0xFFF0FDF4),
                )),
                const SizedBox(width: 10),
                Expanded(child: _summaryCard(
                  label: 'TOTAL CREDIT',
                  value: _fmt(totalCredit),
                  color: const Color(0xFFDC2626),
                  bg: const Color(0xFFFEF2F2),
                )),
                const SizedBox(width: 10),
                Expanded(child: _summaryCard(
                  label: 'GAP',
                  value: _fmt(gap),
                  color: const Color(0xFF64748B),
                  bg: const Color(0xFFF1F5F9),
                )),
              ],
            ),
          ),
        ),

        // ── Records table or empty state ──────────────────────────────────
        if (_records.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.account_balance_wallet_outlined,
                          color: _accent, size: 28),
                    ),
                    const SizedBox(height: 14),
                    const Text('No opening balance records',
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B))),
                    const SizedBox(height: 6),
                    const Text(
                        'Opening balances have not been set for this financial year.',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF94A3B8)),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          )
        else ...[
          // Table header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(14)),
                  border: Border(
                    top: BorderSide(color: Color(0xFFE2E8F0)),
                    left: BorderSide(color: Color(0xFFE2E8F0)),
                    right: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text('ENTITY',
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.6)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text('TYPE',
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.6)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('DEBIT',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.6)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('CREDIT',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Table rows
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _buildRecordRow(
                    _records[i], i == _records.length - 1),
                childCount: _records.length,
              ),
            ),
          ),
        ],

        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  Widget _summaryCard({
    required String label,
    required String value,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 9.5, fontWeight: FontWeight.w800,
                  color: color.withOpacity(0.7), letterSpacing: 0.5)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w900,
                    color: color, letterSpacing: -0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordRow(Map<String, dynamic> rec, bool isLast) {
    final name    = rec['name']?.toString() ?? rec['account_name']?.toString() ?? '–';
    final type    = rec['type']?.toString() ?? rec['balance_type']?.toString() ?? '–';
    final debit   = rec['debit']?.toString();
    final credit  = rec['credit']?.toString();
    final amount  = rec['amount']?.toString();
    final balType = rec['balance_entry_type']?.toString().toUpperCase() ?? type.toUpperCase();

    // Determine debit / credit columns from data
    final drVal = debit ?? (balType == 'DR' ? amount : null);
    final crVal = credit ?? (balType == 'CR' ? amount : null);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          left: const BorderSide(color: Color(0xFFE2E8F0)),
          right: const BorderSide(color: Color(0xFFE2E8F0)),
          bottom: BorderSide(
              color: const Color(0xFFE2E8F0),
              width: isLast ? 1 : 0.5),
        ),
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(14))
            : BorderRadius.zero,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(name,
                style: const TextStyle(fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 3,
            child: Text(type,
                style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B))),
          ),
          Expanded(
            flex: 2,
            child: Text(
              drVal != null ? _fmt(drVal) : '–',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: drVal != null
                      ? const Color(0xFF059669)
                      : const Color(0xFFCBD5E1)),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              crVal != null ? _fmt(crVal) : '–',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: crVal != null
                      ? const Color(0xFFDC2626)
                      : const Color(0xFFCBD5E1)),
            ),
          ),
        ],
      ),
    );
  }
}
