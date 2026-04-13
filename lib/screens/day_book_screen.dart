import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'dart:math' as math;

class DayBookScreen extends StatefulWidget {
  final String storeId;

  const DayBookScreen({super.key, required this.storeId});

  @override
  State<DayBookScreen> createState() => _DayBookScreenState();
}

class _DayBookScreenState extends State<DayBookScreen> {
  // ── Filters ────────────────────────────────────────────────────────────────
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  String _selectedPeriod = 'month'; // week | month | year | custom
  String? _selectedVoucherType; // null = All Types

  // ── Data ───────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _vouchers = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  // ── Pagination ─────────────────────────────────────────────────────────────
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  bool _hasNext = false;
  bool _hasPrev = false;
  static const int _pageSize = 25;

  final ScrollController _scrollController = ScrollController();

  static const List<Map<String, String>> _voucherTypeOptions = [
    {'value': '', 'label': 'All Types'},
    {'value': 'SALES', 'label': 'Sales'},
    {'value': 'PURCHASE', 'label': 'Purchase'},
    {'value': 'RECEIPT', 'label': 'Receipt'},
    {'value': 'PAYMENT', 'label': 'Payment'},
    {'value': 'JOURNAL', 'label': 'Journal'},
    {'value': 'STOCK_JRNL', 'label': 'Stock Journal'},
    {'value': 'CREDIT_NOTE', 'label': 'Credit Note'},
    {'value': 'DEBIT_NOTE', 'label': 'Debit Note'},
  ];

  static const Map<String, Color> _typeColors = {
    'SALES': Color(0xFF2563EB),
    'PURCHASE': Color(0xFF7C3AED),
    'RECEIPT': Color(0xFF059669),
    'PAYMENT': Color(0xFFDC2626),
    'JOURNAL': Color(0xFFD97706),
    'STOCK_JRNL': Color(0xFF0891B2),
    'CREDIT_NOTE': Color(0xFF16A34A),
    'DEBIT_NOTE': Color(0xFFEA580C),
  };

  @override
  void initState() {
    super.initState();
    _fetchVouchers();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── API call ───────────────────────────────────────────────────────────────
  Future<void> _fetchVouchers({int page = 1}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final List<String>? types =
          (_selectedVoucherType != null && _selectedVoucherType!.isNotEmpty)
          ? [_selectedVoucherType!]
          : null;

      final response = await StoreOwnerApiService.getVoucherRegister(
        storeId: widget.storeId,
        voucherTypes: types,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate),
        isCancelled: false,
        search: null,
        page: page,
        pageSize: _pageSize,
        includeLines: false,
      );

      if (mounted) {
        if (response.isNotEmpty) {
          setState(() {
            _vouchers = List<Map<String, dynamic>>.from(
              response['vouchers'] ?? [],
            );
            _summary = Map<String, dynamic>.from(response['summary'] ?? {});
            _currentPage = response['page'] ?? 1;
            _totalPages = response['total_pages'] ?? 1;
            _totalCount = response['count'] ?? 0;
            _hasNext = response['has_next'] ?? false;
            _hasPrev = response['has_prev'] ?? false;
          });
        } else {
          setState(() {
            _vouchers = [];
            _summary = {};
            _currentPage = 1;
            _totalPages = 1;
            _totalCount = 0;
            _hasNext = false;
            _hasPrev = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2563EB),
            onPrimary: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _setPeriod(String period) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    switch (period) {
      case 'week':
        // Monday of the current week
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'month':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'year':
        // Financial-year start: 1 Apr of current or last year
        start = now.month >= 4
            ? DateTime(now.year, 4, 1)
            : DateTime(now.year - 1, 4, 1);
        break;
      default: // custom — keep existing dates, just open picker
        setState(() => _selectedPeriod = period);
        return;
    }

    setState(() {
      _selectedPeriod = period;
      _startDate = start;
      _endDate = end;
    });
    _refresh();
  }

  void _refresh() {
    _currentPage = 1;
    _fetchVouchers(page: 1);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _fmtDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final d = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(d);
    } catch (_) {
      return dateStr;
    }
  }

  Color _typeColor(String? type) =>
      _typeColors[type] ?? const Color(0xFF64748B);

  String _typeLabel(String? type) {
    if (type == null) return '-';
    return _voucherTypeOptions.firstWhere(
      (m) => m['value'] == type,
      orElse: () => {'label': type},
    )['label']!;
  }

  // Overall totals from the API-level summary object (covers ALL pages).
  double get _overallTaxable =>
      double.tryParse(_summary['total_taxable']?.toString() ?? '0') ?? 0;

  double get _overallTax {
    final cgst =
        double.tryParse(_summary['total_cgst']?.toString() ?? '0') ?? 0;
    final sgst =
        double.tryParse(_summary['total_sgst']?.toString() ?? '0') ?? 0;
    final igst =
        double.tryParse(_summary['total_igst']?.toString() ?? '0') ?? 0;
    final cess =
        double.tryParse(_summary['total_cess']?.toString() ?? '0') ?? 0;
    return cgst + sgst + igst + cess;
  }

  double get _overallGrandTotal =>
      double.tryParse(_summary['grand_total']?.toString() ?? '0') ?? 0;

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            _buildHeader(context),
            _buildFilterBar(),
            if (_hasError) _buildErrorBanner(),
            if (!_isLoading && !_hasError && _vouchers.isNotEmpty)
              _buildSummaryCards(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2563EB),
                      ),
                    )
                  : _hasError
                  ? _buildErrorBody()
                  : _vouchers.isEmpty
                  ? _buildEmptyState()
                  : _buildVoucherList(),
            ),
            if (!_isLoading && !_hasError && _totalPages > 1)
              _buildPaginationBar(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    const bg = Color(0xFFEFF6FF);
    const watermark = Color(0xFFDBEAFE);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -10,
              child: Transform.rotate(
                angle: -math.pi / 8,
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 160,
                  color: watermark.withOpacity(0.9),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.blueGrey.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.only(right: 2),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.blueGrey,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Day Book',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _totalCount > 0
                                ? '$_totalCount VOUCHER${_totalCount == 1 ? '' : 'S'}'
                                : 'VOUCHER REGISTER',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: _isLoading ? null : _refresh,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _isLoading
                            ? const Center(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white,
                                size: 20,
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
    );
  }

  // ── Filter bar ─────────────────────────────────────────────────────────────
  Widget _buildFilterBar() {
    final isCustom = _selectedPeriod == 'custom';
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Period selector + Voucher Type
          Row(
            children: [
              Expanded(flex: 3, child: _buildPeriodDropdown()),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _buildTypeDropdown()),
            ],
          ),
          // Row 2: visible only in Custom mode
          if (isCustom) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDateChip('Start Date', _startDate, true),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildDateChip('End Date', _endDate, false),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _refresh,
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text(
                        'Apply',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodDropdown() {
    const options = [
      {'value': 'week', 'label': 'This Week'},
      {'value': 'month', 'label': 'This Month'},
      {'value': 'year', 'label': 'This Year'},
      {'value': 'custom', 'label': 'Custom Range'},
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriod,
          isExpanded: true,
          isDense: true,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2563EB),
          ),
          dropdownColor: Colors.white,
          icon: const Icon(
            Icons.expand_more_rounded,
            size: 16,
            color: Color(0xFF2563EB),
          ),
          items: options.map((opt) {
            return DropdownMenuItem<String>(
              value: opt['value'],
              child: Text(
                opt['label']!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF1E293B)),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) _setPeriod(val);
          },
        ),
      ),
    );
  }

  Widget _buildDateChip(String label, DateTime date, bool isStart) {
    return InkWell(
      onTap: () => _selectDate(isStart),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 12,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedVoucherType ?? '',
          isExpanded: true,
          isDense: true,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
          icon: const Icon(
            Icons.expand_more_rounded,
            size: 16,
            color: Color(0xFF64748B),
          ),
          items: _voucherTypeOptions.map((opt) {
            return DropdownMenuItem<String>(
              value: opt['value'],
              child: Text(opt['label']!, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) {
            setState(
              () => _selectedVoucherType = val?.isEmpty == true ? null : val,
            );
          },
        ),
      ),
    );
  }


  // ── Summary cards ──────────────────────────────────────────────────────────
  Widget _buildSummaryCards() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              'TOTAL TAXABLE',
              _overallTaxable,
              const Color(0xFF2563EB),
              Icons.account_balance_wallet_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'TOTAL TAX',
              _overallTax,
              const Color(0xFFD97706),
              Icons.percent_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              'GRAND TOTAL',
              _overallGrandTotal,
              const Color(0xFF059669),
              Icons.currency_rupee_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    double value,
    Color color,
    IconData icon,
  ) {
    final fmtVal =
        '₹${value.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color.withOpacity(0.8),
                    letterSpacing: 0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            fmtVal,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Voucher list ───────────────────────────────────────────────────────────
  Widget _buildVoucherList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _vouchers.length,
      itemBuilder: (context, index) => _buildVoucherCard(_vouchers[index]),
    );
  }

  Widget _buildVoucherCard(Map<String, dynamic> voucher) {
    final type = voucher['voucher_type'] as String?;
    final color = _typeColor(type);
    final typeLabel = _typeLabel(type);
    final party = voucher['party'] as Map? ?? {};
    final totals = voucher['totals'] as Map? ?? {};
    final grandTotal =
        double.tryParse(totals['grand_total']?.toString() ?? '0') ?? 0;
    final bool isCancelled = voucher['is_cancelled'] == true;
    final double cgst = double.tryParse(totals['cgst']?.toString() ?? '0') ?? 0;
    final double sgst = double.tryParse(totals['sgst']?.toString() ?? '0') ?? 0;
    final double igst = double.tryParse(totals['igst']?.toString() ?? '0') ?? 0;
    final double totalGst = cgst + sgst + igst;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Type Badge
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  typeLabel.length > 2
                      ? typeLabel.substring(0, 2).toUpperCase()
                      : typeLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Main info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '#${voucher['voucher_number'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      if (isCancelled) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'CANCELLED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fmtDate(voucher['date'] as String?),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if ((party['name'] as String?)?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      party['name'] as String,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if ((voucher['narration'] as String?)?.isNotEmpty ==
                      true) ...[
                    const SizedBox(height: 2),
                    Text(
                      voucher['narration'] as String,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Amount column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${grandTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: grandTotal == 0
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF1E293B),
                  ),
                ),
                if (totalGst > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'GST: ₹${totalGst.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Pagination bar ─────────────────────────────────────────────────────────
  Widget _buildPaginationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Page $_currentPage of $_totalPages  ($_totalCount entries)',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              _buildPageBtn(
                icon: Icons.chevron_left_rounded,
                enabled: _hasPrev,
                onTap: () => _fetchVouchers(page: _currentPage - 1),
              ),
              const SizedBox(width: 8),
              _buildPageBtn(
                icon: Icons.chevron_right_rounded,
                enabled: _hasNext,
                onTap: () => _fetchVouchers(page: _currentPage + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFF2563EB).withOpacity(0.1)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1),
        ),
      ),
    );
  }

  // ── Empty / Error states ───────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Vouchers Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting the date range or filters.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: Colors.red.shade600,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: Colors.red.shade400,
              size: 18,
            ),
            onPressed: () => setState(() => _hasError = false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 40,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Failed to load Day Book',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
