import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/api_service.dart';
import 'package:intl/intl.dart';

class StockSummaryScreen extends StatefulWidget {
  final String storeId;
  final String financialYearId;
  final String fyLabel;

  const StockSummaryScreen({
    super.key,
    required this.storeId,
    required this.financialYearId,
    required this.fyLabel,
  });

  @override
  State<StockSummaryScreen> createState() => _StockSummaryScreenState();
}

class _StockSummaryScreenState extends State<StockSummaryScreen> {
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
        '/reports/stock-summary/',
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
            _error = data?['message'] ?? 'Failed to load Stock Summary';
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
      final clean = raw.replaceAll('+', '');
      final val = double.parse(clean);
      final f = NumberFormat('#,##,##0.00', 'en_IN');
      return val < 0 ? '−${f.format(val.abs())}' : f.format(val);
    } catch (_) {
      return raw;
    }
  }

  String _fmtRaw(String? raw) {
    // keep +/- prefix as-is for appreciation display
    if (raw == null) return '0.00';
    final isNeg = raw.startsWith('-');
    final isPos = raw.startsWith('+');
    try {
      final clean = raw.replaceAll('+', '').replaceAll('-', '');
      final val = double.parse(clean);
      final f = NumberFormat('#,##,##0.00', 'en_IN');
      if (isNeg) return '−${f.format(val)}';
      if (isPos) return '+${f.format(val)}';
      return f.format(val);
    } catch (_) {
      return raw;
    }
  }

  Color _appreciationColor(String? raw) {
    if (raw == null) return const Color(0xFF1E293B);
    if (raw.startsWith('-')) return const Color(0xFFDC2626);
    return const Color(0xFF059669);
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
                        color: Color(0xFF8B5CF6),
                      ),
                    )
                  : _error != null
                      ? _buildErrorState()
                      : RefreshIndicator(
                          onRefresh: _fetch,
                          color: const Color(0xFF8B5CF6),
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
                      'Stock Summary',
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
              'Failed to load Stock Summary',
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
                backgroundColor: const Color(0xFF8B5CF6),
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
    final asOf = _data!['as_of'] ?? '';
    final summary = _data!['summary'] as Map<String, dynamic>? ?? {};
    final items = _data!['items'] as List<dynamic>? ?? [];

    final totalItems = summary['total_items']?.toString() ?? '0';
    final totalValue = summary['closing_stock_value']?.toString() ?? '0.00';
    final appreciation = summary['stock_appreciation']?.toString() ?? '+0.00';
    final openingValue = summary['opening_stock_value']?.toString() ?? '0.00';

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Title card ─────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inventory Stock Summary',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$storeName • Real-time WAC Valuation',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (asOf.isNotEmpty || fyLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (fyLabel.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            fyLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                      if (asOf.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          'As of $asOf',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),

        // ── Summary stat cards ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                // Total closing value
                Expanded(
                  child: _statCard(
                    label: 'TOTAL CLOSING VALUE',
                    value: _fmt(totalValue),
                    valueColor: const Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 12),
                // Appreciation
                Expanded(
                  child: _statCard(
                    label: 'STOCK APPRECIATION/CONSUMPTION',
                    value: _fmtRaw(appreciation),
                    valueColor: _appreciationColor(appreciation),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Stats row: items | qty | opening ──────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                _miniStatCard(
                  icon: Icons.inventory_2_rounded,
                  label: 'Items',
                  value: totalItems,
                  color: const Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 10),
                _miniStatCard(
                  icon: Icons.scale_rounded,
                  label: 'Opening Stock',
                  value: '₹${_fmt(openingValue)}',
                  color: const Color(0xFF0EA5E9),
                ),
                const SizedBox(width: 10),
                _miniStatCard(
                  icon: Icons.trending_up_rounded,
                  label: 'Closing Stock',
                  value: '₹${_fmt(totalValue)}',
                  color: const Color(0xFF059669),
                ),
              ],
            ),
          ),
        ),

        // ── Table header ───────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    'PRODUCT NAME',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[500],
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'RATE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[500],
                      letterSpacing: 0.6,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'QTY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[500],
                      letterSpacing: 0.6,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'VALUE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey[500],
                      letterSpacing: 0.6,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Item rows ─────────────────────────────────────────────────────
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index] as Map<String, dynamic>;
              final isLast = index == items.length - 1;
              return _buildItemRow(item, isLast: isLast);
            },
            childCount: items.length,
          ),
        ),

        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  // ── Item row ──────────────────────────────────────────────────────────────

  Widget _buildItemRow(Map<String, dynamic> item, {bool isLast = false}) {
    final name = item['product_name']?.toString() ?? '';
    final unit = item['unit']?.toString() ?? '';
    final qty = item['quantity']?.toString() ?? '0.00';
    final avgRate = item['avg_rate']?.toString() ?? '0.00';
    final totalVal = item['total_value']?.toString() ?? '0.00';
    final movement = item['movement'] as Map<String, dynamic>? ?? {};
    final purchased = movement['purchased']?.toString() ?? '0.00';
    final sold = movement['sold']?.toString() ?? '0.00';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: product name (left) + movement chips (right) ────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+ ${_fmt(purchased)} In',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '- ${_fmt(sold)} Out',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Thin inner divider ─────────────────────────────────────────
            Container(height: 1, color: const Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            // ── Row 2: rate | qty+unit | value ─────────────────────────────
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Avg Rate',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fmt(avgRate),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Closing Qty',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_fmt(qty)} $unit',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2563EB),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total Value',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey[400],
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fmt(totalVal),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6366F1),
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  Widget _statCard({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
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
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.grey[500],
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          // FittedBox prevents overflow on smaller screens
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: valueColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
