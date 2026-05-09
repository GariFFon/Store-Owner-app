import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/screens/financial_year_detail_screen.dart';
import 'package:exanor/screens/tax_compliance_detail_screen.dart';
import 'package:exanor/screens/account_groups_screen.dart';
import 'package:exanor/screens/accounts_screen.dart';
import 'package:exanor/screens/parties_screen.dart';
import 'package:exanor/screens/opening_balances_screen.dart';
import 'package:exanor/screens/ob_operations_screen.dart';
import 'package:intl/intl.dart';

class AccountingProScreen extends StatefulWidget {
  final String storeId;
  final List<Map<String, dynamic>> financialYears;

  const AccountingProScreen({
    super.key,
    required this.storeId,
    required this.financialYears,
  });

  @override
  State<AccountingProScreen> createState() => _AccountingProScreenState();
}

class _AccountingProScreenState extends State<AccountingProScreen>
    with SingleTickerProviderStateMixin {
  bool _isRefreshing = false;
  List<Map<String, dynamic>> _financialYears = [];

  // Master Data categories
  final List<_MasterCategory> _masterCategories = const [
    _MasterCategory(
      id: 'financial_years',
      title: 'Financial Reports',
      subtitle: 'P&L, Balance Sheet & Cash Flow',
      icon: Icons.bar_chart_rounded,
      color: Color(0xFF2563EB),
    ),
    _MasterCategory(
      id: 'tax_compliance',
      title: 'Tax & Compliance',
      subtitle: 'GST / VAT configurations',
      icon: Icons.verified_user_rounded,
      color: Color(0xFF7C3AED),
    ),
    _MasterCategory(
      id: 'gst_reports',
      title: 'GST Reports',
      subtitle: 'GSTR filing & summary',
      icon: Icons.receipt_long_rounded,
      color: Color(0xFF059669),
    ),
    _MasterCategory(
      id: 'account_groups',
      title: 'Account Groups',
      subtitle: 'Classification groupings',
      icon: Icons.folder_open_rounded,
      color: Color(0xFFEA580C),
    ),
    _MasterCategory(
      id: 'accounts',
      title: 'Accounts',
      subtitle: 'Ledger account listing',
      icon: Icons.list_alt_rounded,
      color: Color(0xFF0891B2),
    ),
    _MasterCategory(
      id: 'parties',
      title: 'Parties',
      subtitle: 'Customers & vendors',
      icon: Icons.people_alt_rounded,
      color: Color(0xFF0D9488),
    ),
    _MasterCategory(
      id: 'opening_balances',
      title: 'Opening Balances',
      subtitle: 'Initial balance setup',
      icon: Icons.account_balance_rounded,
      color: Color(0xFF0284C7),
    ),
    _MasterCategory(
      id: 'ob_operations',
      title: 'OB Operations',
      subtitle: 'Opening balance operations',
      icon: Icons.tune_rounded,
      color: Color(0xFF9333EA),
    ),
  ];



  @override
  void initState() {
    super.initState();
    _financialYears = List<Map<String, dynamic>>.from(widget.financialYears);
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final response = await ApiService.post(
        '/financial-years/',
        body: {'store_id': widget.storeId},
        useBearerToken: true,
      );
      if (mounted && response['data'] != null) {
        final data = response['data'];
        if (data['status'] == 200 && data['response'] != null) {
          setState(() {
            _financialYears =
                List<Map<String, dynamic>>.from(data['response']);
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
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
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF2563EB),
          child: CustomScrollView(
            slivers: [
              // ── Top Banner ──────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildTopBanner(context)),

              // ── Financial Years Panel ────────────────────────────────────
              if (_financialYears.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: _buildFinancialYearsPanel(),
                  ),
                ),

              // ── Section Header: Master Data ──────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Master Data',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_masterCategories.length} categories',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Categories List View ─────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildCategoryListItem(
                      _masterCategories[index],
                      isLast: index == _masterCategories.length - 1,
                    ),
                    childCount: _masterCategories.length,
                  ),
                ),
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────────

  Widget _buildTopBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            // Watermark icon
            Positioned(
              right: -20,
              top: -30,
              child: Transform.rotate(
                angle: -math.pi / 8,
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: 200,
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -20,
              child: Transform.rotate(
                angle: math.pi / 6,
                child: Icon(
                  Icons.account_balance_rounded,
                  size: 150,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back + Title row
                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: const Center(
                              child: Padding(
                                padding: EdgeInsets.only(right: 2),
                                child: Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // PRO badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                margin: const EdgeInsets.only(bottom: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFBBF24),
                                      Color(0xFFF59E0B),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'PRO',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Text(
                                'Accounting PRO',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Refresh button
                        InkWell(
                          onTap: _refresh,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: _isRefreshing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.refresh_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Stats row
                    Row(
                      children: [
                        _buildStatChip(
                          Icons.calendar_month_rounded,
                          '${_financialYears.length} FY Periods',
                        ),
                        const SizedBox(width: 10),
                        _buildStatChip(
                          Icons.check_circle_outline_rounded,
                          '${_financialYears.where((fy) => fy['is_active'] == true).length} Active',
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
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialYearsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 16,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Financial Years',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_financialYears.length} total',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _financialYears.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFF8FAFC)),
            itemBuilder: (context, index) {
              final fy = _financialYears[index];
              return _buildFyListTile(fy);
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildFyListTile(Map<String, dynamic> fy) {
    final isActive = fy['is_active'] == true;
    final isLocked = fy['is_locked'] == true;
    final label = fy['label'] ?? 'FY Period';
    final startDate = fy['start_date'] ?? '';
    final endDate = fy['end_date'] ?? '';

    String dateRange = '';
    try {
      if (startDate.isNotEmpty && endDate.isNotEmpty) {
        final fmt = DateFormat('MMM yyyy');
        dateRange =
            '${fmt.format(DateTime.parse(startDate))} – ${fmt.format(DateTime.parse(endDate))}';
      }
    } catch (_) {}

    // Display-only — no tap, no navigation
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Year icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF2563EB).withOpacity(0.08)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? const Color(0xFF2563EB).withOpacity(0.2)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Icon(
              isActive ? Icons.star_rounded : Icons.calendar_today_rounded,
              size: 20,
              color: isActive ? const Color(0xFF2563EB) : Colors.grey[400],
            ),
          ),
          const SizedBox(width: 12),
          // Label + date range
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (dateRange.isNotEmpty)
                  Text(
                    dateRange,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _badge(
                isActive ? 'Active' : 'Inactive',
                isActive ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                isActive
                    ? const Color(0xFFF0FDF4)
                    : const Color(0xFFF8FAFC),
              ),
              if (isLocked) ...[
                const SizedBox(height: 4),
                _badge(
                  'Locked',
                  const Color(0xFFDC2626),
                  const Color(0xFFFEF2F2),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildCategoryListItem(_MasterCategory cat, {bool isLast = false}) {
    // Determine if it's an expandable category with financial years
    final bool isFyCategory = cat.id == 'financial_years';

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            if (cat.id == 'financial_years') {
              _showFyPickerSheet(context, destination: _FyDestination.financialReports);
            } else if (cat.id == 'tax_compliance') {
              _showFyPickerSheet(context, destination: _FyDestination.taxCompliance);
            } else if (cat.id == 'account_groups') {
              // Get the active (or first) financial year for detail calls
              final activeFy = _financialYears.firstWhere(
                (fy) => fy['is_active'] == true,
                orElse: () => _financialYears.isNotEmpty ? _financialYears.first : {},
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AccountGroupsScreen(
                    storeId: widget.storeId,
                    financialYearId: activeFy['id']?.toString() ?? '',
                    fyLabel: activeFy['label']?.toString() ?? '',
                  ),
                ),
              );
            } else if (cat.id == 'accounts') {
              final activeFy = _financialYears.firstWhere(
                (fy) => fy['is_active'] == true,
                orElse: () =>
                    _financialYears.isNotEmpty ? _financialYears.first : {},
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AccountsScreen(
                    storeId: widget.storeId,
                    financialYearId: activeFy['id']?.toString() ?? '',
                    fyLabel: activeFy['label']?.toString() ?? '',
                  ),
                ),
              );
            } else if (cat.id == 'parties') {
              final activeFy = _financialYears.firstWhere(
                (fy) => fy['is_active'] == true,
                orElse: () =>
                    _financialYears.isNotEmpty ? _financialYears.first : {},
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PartiesScreen(
                    storeId: widget.storeId,
                    financialYearId: activeFy['id']?.toString() ?? '',
                    fyLabel: activeFy['label']?.toString() ?? '',
                  ),
                ),
              );
            } else if (cat.id == 'opening_balances') {
              final activeFy = _financialYears.firstWhere(
                (fy) => fy['is_active'] == true,
                orElse: () =>
                    _financialYears.isNotEmpty ? _financialYears.first : {},
              );
              final fys = _financialYears
                  .map((e) => e as Map<String, dynamic>)
                  .toList();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OpeningBalancesScreen(
                    storeId: widget.storeId,
                    financialYears: fys,
                    initialFyId: activeFy['id']?.toString() ?? '',
                    initialFyLabel: activeFy['label']?.toString() ?? '',
                  ),
                ),
              );
            } else if (cat.id == 'ob_operations') {
              final activeFy = _financialYears.firstWhere(
                (fy) => fy['is_active'] == true,
                orElse: () =>
                    _financialYears.isNotEmpty ? _financialYears.first : {},
              );
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OBOperationsScreen(
                    storeId: widget.storeId,
                    financialYearId: activeFy['id']?.toString() ?? '',
                    fyLabel: activeFy['label']?.toString() ?? '',
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${cat.title} — Coming Soon'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon box
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: cat.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(cat.icon, size: 22, color: cat.color),
                ),
                const SizedBox(width: 14),
                // Title & subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Count badge for FY
                if (isFyCategory && _financialYears.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cat.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_financialYears.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: cat.color,
                      ),
                    ),
                  ),
                // Arrow
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Colors.grey[300],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── FY Picker Bottom Sheet ────────────────────────────────────────────────

  void _showFyPickerSheet(BuildContext context,
      {_FyDestination destination = _FyDestination.financialReports}) {
    if (_financialYears.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No Financial Years found. Pull down to refresh.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FyPickerSheet(
        financialYears: _financialYears,
        storeId: widget.storeId,
        destination: destination,
      ),
    );
  }
}

// ── Data class for master categories ─────────────────────────────────────────

class _MasterCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MasterCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

// ── Destination enum ─────────────────────────────────────────────────────────

enum _FyDestination { financialReports, taxCompliance }

// ── FY Picker Bottom Sheet Widget ─────────────────────────────────────────────

class _FyPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> financialYears;
  final String storeId;
  final _FyDestination destination;

  const _FyPickerSheet({
    required this.financialYears,
    required this.storeId,
    this.destination = _FyDestination.financialReports,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 0),
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Financial Year',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Choose a period to view reports',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // FY List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: financialYears.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFF8FAFC), indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final fy = financialYears[index];
              final isActive = fy['is_active'] == true;
              final isLocked = fy['is_locked'] == true;
              final label = fy['label'] ?? 'FY Period';
              final startDate = fy['start_date'] ?? '';
              final endDate = fy['end_date'] ?? '';

              String dateRange = '';
              try {
                if (startDate.isNotEmpty && endDate.isNotEmpty) {
                  final fmt = DateFormat('MMM yyyy');
                  dateRange =
                      '${fmt.format(DateTime.parse(startDate))} – ${fmt.format(DateTime.parse(endDate))}';
                }
              } catch (_) {}

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    if (destination == _FyDestination.taxCompliance) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TaxComplianceDetailScreen(
                            storeId: storeId,
                            financialYear: fy,
                          ),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FinancialYearDetailScreen(
                            storeId: storeId,
                            financialYear: fy,
                          ),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF2563EB).withOpacity(0.08)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isActive
                                  ? const Color(0xFF2563EB).withOpacity(0.15)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Icon(
                            isActive
                                ? Icons.star_rounded
                                : Icons.calendar_today_rounded,
                            size: 20,
                            color: isActive
                                ? const Color(0xFF2563EB)
                                : Colors.grey[400],
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Label & date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              if (dateRange.isNotEmpty)
                                Text(
                                  dateRange,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Badges
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _fyBadge(
                              isActive ? 'Active' : 'Inactive',
                              isActive
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF94A3B8),
                              isActive
                                  ? const Color(0xFFF0FDF4)
                                  : const Color(0xFFF8FAFC),
                            ),
                            if (isLocked) ...[
                              const SizedBox(height: 4),
                              _fyBadge(
                                'Locked',
                                const Color(0xFFDC2626),
                                const Color(0xFFFEF2F2),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Safe area bottom padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }

  Widget _fyBadge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
