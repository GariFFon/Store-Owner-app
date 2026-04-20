import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/models/financial_year.dart';
import 'package:exanor/screens/financial_year_detail_screen.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class FinancialYearsScreen extends StatefulWidget {
  final String storeId;

  const FinancialYearsScreen({super.key, required this.storeId});

  @override
  State<FinancialYearsScreen> createState() => _FinancialYearsScreenState();
}

class _FinancialYearsScreenState extends State<FinancialYearsScreen> {
  bool _isLoading = true;
  List<FinancialYear> _financialYears = [];
  int _totalCount = 0;
  String _selectedFilter = 'All'; // Filter state

  @override
  void initState() {
    super.initState();
    _fetchFinancialYears();
  }

  Map<String, dynamic>? _buildQueryFromFilter() {
    switch (_selectedFilter) {
      case 'Active':
        return {'is_active': true};
      case 'Inactive':
        return {'is_active': false};
      case 'Locked':
        return {'is_locked': true};
      case 'Unlocked':
        return {'is_locked': false};
      case 'All':
      default:
        return {};
    }
  }

  Future<void> _fetchFinancialYears() async {
    setState(() => _isLoading = true);
    try {
      final query = _buildQueryFromFilter();
      final response = await StoreOwnerApiService.getFinancialYears(
        widget.storeId,
        query: query,
      );
      if (mounted) {
        final List<dynamic> list = response['response'] ?? [];
        setState(() {
          _financialYears = list.map((e) => FinancialYear.fromJson(e)).toList();
          _totalCount = response['count'] ?? list.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  int get _activeCount => _financialYears.where((fy) => fy.isActive).length;
  int get _lockedCount => _financialYears.where((fy) => fy.isLocked).length;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            _buildTopBanner(context),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchFinancialYears,
                      child: CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.all(20),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  _buildStatsGrid(isDesktop),
                                  const SizedBox(height: 24),
                                  _buildFilterBar(),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),
                          if (isDesktop)
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: _buildDesktopTable(),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) =>
                                      _buildMobileCard(_financialYears[index]),
                                  childCount: _financialYears.length,
                                ),
                              ),
                            ),
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 80),
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

  Widget _buildTopBanner(BuildContext context) {
    const lightBlueBg = Color(0xFFEFF6FF);
    const watermarkColor = Color(0xFFDBEAFE);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: lightBlueBg,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -20,
              child: Transform.rotate(
                angle: -math.pi / 6,
                child: Icon(
                  Icons.calendar_month_rounded,
                  size: 180,
                  color: watermarkColor.withOpacity(0.8),
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
                          color: Colors.transparent,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Financial Years',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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
                            child: const Text(
                              'FISCAL PERIODS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563EB),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _showCreateFinancialYearSheet,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("New"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(bool isDesktop) {
    final cards = [
      _buildStatCard(
        "Total Periods",
        _totalCount.toString(),
        Icons.list_alt_rounded,
        Colors.blue,
      ),
      _buildStatCard(
        "Active Year",
        _activeCount.toString(),
        Icons.check_circle_outline_rounded,
        Colors.green,
      ),
      _buildStatCard(
        "Locked Years",
        _lockedCount.toString(),
        Icons.lock_outline_rounded,
        Colors.orange,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 16),
          Expanded(child: cards[1]),
          const SizedBox(width: 16),
          Expanded(child: cards[2]),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 12),
        cards[2],
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ['All', 'Active', 'Inactive', 'Locked', 'Unlocked'].map((
          filter,
        ) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                setState(() => _selectedFilter = filter);
                _fetchFinancialYears();
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2563EB) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2), // Period Check
          1: FlexColumnWidth(1.5), // Start
          2: FlexColumnWidth(1.5), // End
          3: FlexColumnWidth(1), // Duration
          4: FlexColumnWidth(1), // Status
          5: FlexColumnWidth(1), // Lock
          6: FlexColumnWidth(1.5), // Created At
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9), // Painted title background
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            children: [
              for (var h in [
                "Period Name",
                "Start Date",
                "End Date",
                "Duration",
                "Status",
                "Locked",
                "Created At",
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Text(
                    h,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          ..._financialYears.map((fy) {
            final dateFormat = DateFormat('MMM dd, yyyy');
            return TableRow(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[100]!)),
              ),
              children: [
                _tableCell(
                  fy.displayName,
                  isBold: true,
                  icon: fy.isActive ? Icons.star_rounded : Icons.calendar_today,
                  iconColor: fy.isActive ? Colors.amber : Colors.grey,
                ),
                _tableCell(dateFormat.format(DateTime.parse(fy.startDate))),
                _tableCell(dateFormat.format(DateTime.parse(fy.endDate))),
                _tableCell(fy.durationText),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _statusBadge(fy.isActive),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _lockBadge(fy.isLocked),
                ),
                _tableCell(dateFormat.format(DateTime.parse(fy.createdAt))),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _tableCell(
    String text, {
    bool isBold = false,
    IconData? icon,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCard(FinancialYear fy) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FinancialYearDetailScreen(
              storeId: widget.storeId,
              financialYear: fy.toJson(),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: fy.isActive ? Colors.blue.withOpacity(0.02) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: fy.isActive ? Colors.blue.withOpacity(0.3) : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_statusBadge(fy.isActive), _lockBadge(fy.isLocked)],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fy.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${dateFormat.format(DateTime.parse(fy.startDate))} - ${dateFormat.format(DateTime.parse(fy.endDate))}",
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFFCBD5E1),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Duration",
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                Text(
                  fy.durationText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Created At",
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                Text(
                  dateFormat.format(DateTime.parse(fy.createdAt)),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive
              ? Colors.green.withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.circle_outlined,
            size: 12,
            color: isActive ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.green[700] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lockBadge(bool isLocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isLocked ? Colors.red[50] : Colors.blue[50], // Blue for unlocked
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isLocked
              ? Colors.red.withOpacity(0.2)
              : Colors.blue.withOpacity(0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLocked ? Icons.lock : Icons.lock_open,
            size: 12,
            color: isLocked ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 6),
          Text(
            isLocked ? 'Locked' : 'Unlocked',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isLocked ? Colors.red[700] : Colors.blue[700],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateFinancialYearSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateFinancialYearSheet(
        storeId: widget.storeId,
        onSuccess: _fetchFinancialYears,
      ),
    );
  }
}

class _CreateFinancialYearSheet extends StatefulWidget {
  final String storeId;
  final VoidCallback onSuccess;

  const _CreateFinancialYearSheet({
    required this.storeId,
    required this.onSuccess,
  });

  @override
  State<_CreateFinancialYearSheet> createState() =>
      _CreateFinancialYearSheetState();
}

class _CreateFinancialYearSheetState extends State<_CreateFinancialYearSheet> {
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = true;
  bool _isLocked = false;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? DateTime.now())
          : (_endDate ??
                (_startDate?.add(const Duration(days: 365)) ?? DateTime.now())),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB), // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Colors.black, // Body text color
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (mounted) {
        setState(() {
          if (isStart) {
            _startDate = picked;
            if (_endDate == null) {
              if (picked.month == 4 && picked.day == 1) {
                _endDate = DateTime(picked.year + 1, 3, 31);
              } else {
                _endDate = picked.add(const Duration(days: 364));
              }
              _endDateController.text = DateFormat(
                'MM/dd/yyyy',
              ).format(_endDate!);
            }
            _startDateController.text = DateFormat('MM/dd/yyyy').format(picked);
          } else {
            _endDate = picked;
            _endDateController.text = DateFormat('MM/dd/yyyy').format(picked);
          }
        });
      }
    }
  }

  Future<void> _createFinancialYear() async {
    if (_startDate == null || _endDate == null) return;
    setState(() => _isCreating = true);

    try {
      final response = await StoreOwnerApiService.createFinancialYear(
        storeId: widget.storeId,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
        isActive: _isActive,
        isLocked: _isLocked,
      );

      if (!mounted) return;

      if (response['status'] == 200 && response['response'] != null) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Financial Year Created Successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['response'] ?? 'Failed to create'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildSheetHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                24,
                0,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                children: [
                  _buildPreviewCard(),
                  const SizedBox(height: 24),
                  _buildFormSection(),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createFinancialYear,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        shadowColor: const Color(0xFF2563EB).withOpacity(0.4),
                      ),
                      child: _isCreating
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Create Financial Year",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "New Year",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                "Define fiscal period",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 20, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final hasDates = _startDate != null && _endDate != null;
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "PREVIEW",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white60,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          if (hasDates) ...[
            Text(
              "FY ${DateFormat('yyyy').format(_startDate!)} - ${DateFormat('yy').format(_endDate!)}",
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${dateFormat.format(_startDate!)}  —  ${dateFormat.format(_endDate!)}",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ] else
            const Column(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white30,
                  size: 40,
                ),
                SizedBox(height: 12),
                Text(
                  "Select dates to preview",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Column(
      children: [
        _buildDateField(
          "Start Date",
          _startDateController,
          () => _selectDate(true),
        ),
        const SizedBox(height: 16),
        _buildDateField(
          "End Date",
          _endDateController,
          () => _selectDate(false),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: [
              _buildSwitch(
                "Active Status",
                "Mark as current fiscal year",
                _isActive,
                (v) => setState(() => _isActive = v),
              ),
              const Divider(height: 32),
              _buildSwitch(
                "Lock Period",
                "Prevent changes to data",
                _isLocked,
                (v) => setState(() => _isLocked = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(
    String label,
    TextEditingController controller,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
            prefixIcon: const Icon(
              Icons.date_range_rounded,
              color: Color(0xFF64748B),
            ),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2563EB)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildSwitch(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF2563EB),
        ),
      ],
    );
  }
}
