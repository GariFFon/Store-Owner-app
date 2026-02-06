import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:exanor/models/gst_ledger_model.dart';
import 'package:exanor/models/gst_summary_model.dart';
import 'package:exanor/models/party_wise_report_model.dart';
import 'package:exanor/services/gst_ledger_service.dart';

class GstLedgerScreen extends StatefulWidget {
  final String storeId;

  const GstLedgerScreen({super.key, required this.storeId});

  @override
  State<GstLedgerScreen> createState() => _GstLedgerScreenState();
}

class _GstLedgerScreenState extends State<GstLedgerScreen>
    with SingleTickerProviderStateMixin {
  // Tab Controller
  late TabController _tabController;
  String _activeTab = 'Ledger'; // 'Ledger', 'Summary', 'Parties'

  // Filter controllers
  late TextEditingController _searchController;
  final ScrollController _scrollController = ScrollController();

  // Filter values
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 27));
  DateTime _endDate = DateTime.now();

  // Ledger Tab Filters
  String _selectedGstType = 'all';
  String _selectedVoucherType = 'all';
  String _selectedSortBy = 'date';

  // Party Tab Filters
  String _selectedPartyGstType = 'all';

  // Data
  GstLedgerData? _ledgerData;
  GstSummaryData? _summaryData;
  PartyWiseReportData? _partyWiseData;

  bool _isLoading = false;
  bool _isSummaryLoading = false;
  bool _isPartyWiseLoading = false;

  String? _errorMessage;
  String? _summaryErrorMessage;
  String? _partyWiseErrorMessage;

  int _currentPage = 1;
  Timer? _debounce;

  // UI State
  bool _isDateExpanded = false;

  // Theme Colors
  final Color _primaryColor = const Color(0xFF2563EB); // Blue-600
  final Color _lightBg = const Color(0xFFEFF6FF); // Blue-50
  final Color _watermarkColor = const Color(0xFFDBEAFE); // Blue-100

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _fetchLedgerData();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      final tabs = ['Ledger', 'Summary', 'Parties'];
      setState(() {
        _activeTab = tabs[_tabController.index];
      });
      _refreshActiveTab();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  // ============== DATA FETCHING ==============

  Future<void> _fetchLedgerData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final request = GstLedgerRequest(
        list: true,
        storeId: widget.storeId,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate),
        gstType: _selectedGstType,
        voucherType: _selectedVoucherType == 'all'
            ? null
            : _selectedVoucherType,
        sortBy: _selectedSortBy,
        sortOrder: 'desc',
        page: _currentPage,
        hsnCode: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
      );

      final response = await GstLedgerService.getGstLedger(request);
      setState(() {
        _ledgerData = response.response;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchGstSummary() async {
    setState(() {
      _isSummaryLoading = true;
      _summaryErrorMessage = null;
    });

    try {
      final request = GstSummaryRequest(
        summary: true,
        storeId: widget.storeId,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate),
      );

      final response = await GstLedgerService.getGstSummary(request);
      setState(() {
        _summaryData = response.response;
        _isSummaryLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _summaryErrorMessage = e.toString();
          _isSummaryLoading = false;
        });
      }
    }
  }

  Future<void> _fetchPartyWiseReport() async {
    setState(() {
      _isPartyWiseLoading = true;
      _partyWiseErrorMessage = null;
    });

    try {
      final request = PartyWiseReportRequest(
        partyWise: true,
        storeId: widget.storeId,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate),
        gstType: _selectedPartyGstType,
      );

      final response = await GstLedgerService.getPartyWiseReport(request);
      setState(() {
        _partyWiseData = response.response;
        _isPartyWiseLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _partyWiseErrorMessage = e.toString();
          _isPartyWiseLoading = false;
        });
      }
    }
  }

  void _refreshActiveTab() {
    if (_activeTab == 'Ledger') _fetchLedgerData();
    if (_activeTab == 'Summary') _fetchGstSummary();
    if (_activeTab == 'Parties') _fetchPartyWiseReport();
  }

  void _refreshAllTabs() {
    // Always refresh ledger as it might be default
    _fetchLedgerData();
    if (_activeTab == 'Summary' || _summaryData != null) _fetchGstSummary();
    if (_activeTab == 'Parties' || _partyWiseData != null)
      _fetchPartyWiseReport();
  }

  // ============== DATE HANDLING ==============

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _refreshAllTabs();
    }
  }

  void _setMonthFilter(bool isThisMonth) {
    final now = DateTime.now();
    setState(() {
      if (isThisMonth) {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
      } else {
        // Last Month
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        _startDate = lastMonth;
        _endDate = DateTime(now.year, now.month, 0); // Last day of prev month
      }
    });
    _refreshAllTabs();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchLedgerData();
    });
  }

  // ============== BUILD UI ==============

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 900;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            // 1. Watermark Banner with Date Picker Removed
            _buildCleanHeader(),

            // 2. Main Scrollable Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _refreshActiveTab(),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Tab Bar "Peel"
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: _buildTabSwitcher(),
                      ),
                    ),

                    // NEW: Date Filter Dashboard Section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildDateFilterDashboard(isDesktop),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 16)),

                    // Content based on Active Tab
                    if (_activeTab == 'Ledger') ...[
                      // Explicit Search Bar in Content Area for Ledger
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSearchField(),
                              const SizedBox(height: 12),
                              _buildLedgerFilters(),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      ..._buildLedgerSlivers(isDesktop),
                    ] else if (_activeTab == 'Summary')
                      ..._buildSummarySlivers(isDesktop)
                    else ...[
                      // Party Filters
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildPartyFilters(),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      ..._buildPartiesSlivers(isDesktop),
                    ],

                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Header ---
  Widget _buildCleanHeader() {
    return Container(
      decoration: BoxDecoration(
        color: _lightBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10), // 0.04 * 255
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Watermark
          Positioned(
            right: -30,
            top: -20,
            child: Transform.rotate(
              angle: -math.pi / 6,
              child: Icon(
                Icons.description_rounded,
                size: 220,
                color: _watermarkColor.withAlpha(204),
              ),
            ),
          ),
          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 12,
              20,
              16, // Reduced padding since date is gone
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(150),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.blueGrey.withAlpha(50),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.only(right: 2),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.black87,
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
                      "GST Ledger",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      "Reports & Analysis",
                      style: TextStyle(
                        fontSize: 12,
                        color: _primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW Date Dashboard ---
  // Collapsible on Mobile, Expanded on Desktop
  Widget _buildDateFilterDashboard(bool isDesktop) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // If tight on space (Mobile), make it collapsible
        final isTight = width < 600;

        if (!isTight) {
          // DESKTOP: Always visible, Horizontal layout
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(5),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      color: _primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Date Period",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildDateInputRow("Start Date", _startDate, true),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Text(
                        "to",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: _buildDateInputRow("End Date", _endDate, false),
                    ),
                    const SizedBox(width: 20),
                    _buildQuickDateBtn("This Month", true),
                    const SizedBox(width: 8),
                    _buildQuickDateBtn("Last Month", false),
                  ],
                ),
              ],
            ),
          );
        }

        // MOBILE: Collapsible Vertical Layout
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    _isDateExpanded = !_isDateExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        color: _primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Date Period",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "${DateFormat('dd MMM yyyy').format(_startDate)} - ${DateFormat('dd MMM yyyy').format(_endDate)}",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isDateExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
              if (_isDateExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      _buildDateInputRow("Start Date", _startDate, true),
                      const SizedBox(height: 12),
                      _buildDateInputRow("End Date", _endDate, false),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickDateBtn("This Month", true),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickDateBtn("Last Month", false),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateInputRow(String label, DateTime date, bool isStart) {
    return InkWell(
      onTap: () => _selectDateRange(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy').format(date),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDateBtn(String label, bool isThisMonth) {
    return InkWell(
      onTap: () => _setMonthFilter(isThisMonth),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _lightBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _primaryColor.withAlpha(50)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: "Search by HSN or Description...",
        prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryColor),
        ),
      ),
    );
  }

  // --- "Peel" / Tabs Switcher ---
  Widget _buildTabSwitcher() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13), // 0.05 opacity
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelColor: const Color(0xFF0F172A),
        unselectedLabelColor: Colors.grey[500],
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        onTap: (index) {
          final tabs = ['Ledger', 'Summary', 'Parties'];
          setState(() {
            _activeTab = tabs[index];
          });
          _refreshActiveTab();
        },
        tabs: const [
          Tab(text: "Ledger"),
          Tab(text: "Summary"),
          Tab(text: "Party Report"),
        ],
      ),
    );
  }

  // --- Filters Widget for Ledger ---
  Widget _buildLedgerFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildDropdownChip(
            value: _selectedGstType,
            label: "GST Type",
            items: {
              'all': 'All GST',
              'input': 'Input GST',
              'output': 'Output GST',
            },
            onChanged: (val) {
              setState(() => _selectedGstType = val!);
              _fetchLedgerData();
            },
          ),
          const SizedBox(width: 10),
          _buildDropdownChip(
            value: _selectedVoucherType,
            label: "Voucher",
            items: {
              'all': 'All Vouchers',
              'PURCHASE': 'Purchase',
              'SALES': 'Sales',
              'CREDIT_NOTE': 'Credit Note',
              'DEBIT_NOTE': 'Debit Note',
            },
            onChanged: (val) {
              setState(() => _selectedVoucherType = val!);
              _fetchLedgerData();
            },
          ),
          const SizedBox(width: 10),
          _buildDropdownChip(
            value: _selectedSortBy,
            label: "Sort",
            items: {
              'date': 'Sort by Date',
              'amount': 'Sort by Amount',
              'party_name': 'Sort by Party',
            },
            onChanged: (val) {
              setState(() => _selectedSortBy = val!);
              _fetchLedgerData();
            },
          ),
        ],
      ),
    );
  }

  // --- Party Filters ---
  Widget _buildPartyFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildDropdownChip(
            value: _selectedPartyGstType,
            label: "GST Type",
            items: {
              'all': 'All Parties',
              'input': 'Input (Creditors)',
              'output': 'Output (Debtors)',
            },
            onChanged: (val) {
              setState(() => _selectedPartyGstType = val!);
              _fetchPartyWiseReport();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownChip({
    required String value,
    required String label,
    required Map<String, String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
          items: items.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ============== TAB 1: LEDGER SLIVERS ==============

  List<Widget> _buildLedgerSlivers(bool isDesktop) {
    if (_isLoading && _ledgerData == null) {
      return [
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_errorMessage != null) {
      return [
        SliverFillRemaining(
          child: _buildErrorState(_errorMessage!, _fetchLedgerData),
        ),
      ];
    }
    if (_ledgerData == null || _ledgerData!.ledger.isEmpty) {
      return [SliverFillRemaining(child: _buildEmptyState("No Entries Found"))];
    }

    return [
      SliverToBoxAdapter(child: _buildTotalsCards()),
      isDesktop
          ? SliverToBoxAdapter(
              child: _buildLedgerTableDesktop(_ledgerData!.ledger),
            )
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildLedgerEntryCard(_ledgerData!.ledger[index]),
                ),
                childCount: _ledgerData!.ledger.length,
              ),
            ),
    ];
  }

  Widget _buildLedgerTableDesktop(List<LedgerEntry> entries) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _buildHeaderCell('Date', 2),
                _buildHeaderCell('Voucher', 2),
                _buildHeaderCell('Party', 3),
                _buildHeaderCell('Item/HSN', 2),
                _buildHeaderCell('Taxable', 2, alignRight: true),
                _buildHeaderCell('CGST', 1, alignRight: true),
                _buildHeaderCell('SGST', 1, alignRight: true),
                _buildHeaderCell('Total', 2, alignRight: true),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (c, i) =>
                Divider(height: 1, color: Colors.grey[100]),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat(
                              'dd MMM',
                            ).format(DateTime.parse(entry.date)),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            DateFormat(
                              'yyyy',
                            ).format(DateTime.parse(entry.date)),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.voucherNumber,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: entry.voucherType == 'PURCHASE'
                                  ? Colors.blue[50]
                                  : Colors.green[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              entry.voucherType,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: entry.voucherType == 'PURCHASE'
                                    ? Colors.blue
                                    : Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        entry.partyName,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (entry.itemName.isNotEmpty)
                            Text(
                              entry.itemName,
                              style: const TextStyle(fontSize: 11),
                              maxLines: 1,
                            ),
                          if (entry.hsnCode.isNotEmpty)
                            Text(
                              'HSN: ${entry.hsnCode}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${entry.taxableValueDouble.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        _formatTax(entry.cgstAmountDouble),
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        _formatTax(entry.sgstAmountDouble),
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${_calculateTotal(entry).toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatTax(double val) =>
      val == 0 ? '-' : '₹${val.toStringAsFixed(0)}';

  // ============== TAB 2: SUMMARY SLIVERS ==============

  List<Widget> _buildSummarySlivers(bool isDesktop) {
    if (_isSummaryLoading && _summaryData == null) {
      return [
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_summaryErrorMessage != null) {
      return [
        SliverFillRemaining(
          child: _buildErrorState(_summaryErrorMessage!, _fetchGstSummary),
        ),
      ];
    }
    if (_summaryData == null) {
      return [SliverFillRemaining(child: _buildEmptyState("No Summary Data"))];
    }

    return [
      SliverToBoxAdapter(
        child: Column(
          children: [
            _buildGstCardSection(
              'Input GST (ITC Available)',
              _summaryData!.inputGst.total,
              Colors.blue,
              _summaryData!.inputGst,
            ),
            _buildGstCardSection(
              'Output GST (Tax Collected)',
              _summaryData!.outputGst.total,
              Colors.green,
              _summaryData!.outputGst,
            ),
            _buildNetLiabilitySection(),
            _buildHsnSummaryCard(_summaryData!.hsnSummary),
          ],
        ),
      ),
    ];
  }

  // ============== TAB 3: PARTY SLIVERS ==============

  List<Widget> _buildPartiesSlivers(bool isDesktop) {
    if (_isPartyWiseLoading && _partyWiseData == null) {
      return [
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_partyWiseErrorMessage != null) {
      return [
        SliverFillRemaining(
          child: _buildErrorState(
            _partyWiseErrorMessage!,
            _fetchPartyWiseReport,
          ),
        ),
      ];
    }
    if (_partyWiseData == null) {
      return [SliverFillRemaining(child: _buildEmptyState("No Parties Found"))];
    }

    return [
      SliverToBoxAdapter(child: _buildPartyTotalsCards()),
      isDesktop
          ? SliverToBoxAdapter(
              child: _buildPartiesTableDesktop(_partyWiseData!.parties),
            )
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPartyListCard(_partyWiseData!.parties[index]),
                ),
                childCount: _partyWiseData!.parties.length,
              ),
            ),
    ];
  }

  // --- REUSABLE WIDGETS ---

  Widget _buildTotalsCards() {
    if (_ledgerData == null) return const SizedBox.shrink();
    final t = _ledgerData!.totals;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatCard(
              "Total Taxable",
              '₹${t.totalTaxableValue.toStringAsFixed(2)}',
              Colors.black87,
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              "Total CGST",
              '₹${t.totalCgstValue.toStringAsFixed(2)}',
              Colors.blue,
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              "Total SGST",
              '₹${t.totalSgstValue.toStringAsFixed(2)}',
              Colors.green,
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              "Total IGST",
              '₹${t.totalIgstValue.toStringAsFixed(2)}',
              Colors.orange,
            ),
            const SizedBox(width: 8),
            _buildStatCard(
              "Total GST",
              '₹${t.totalGstValue.toStringAsFixed(2)}',
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minWidth: 120),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // -- Ledger Entry Card (Mobile) --
  Widget _buildLedgerEntryCard(LedgerEntry entry) {
    final isInward = entry.voucherType == 'PURCHASE';
    final color = isInward ? Colors.blue : Colors.green;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: color.withAlpha(13), // 0.05 * 255
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.voucherType,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.voucherNumber,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    DateFormat('dd MMM').format(DateTime.parse(entry.date)),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.partyName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (entry.itemName.isNotEmpty)
                    Text(
                      entry.itemName,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  const SizedBox(height: 12),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Taxable",
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          Text(
                            '₹${entry.taxableValueDouble.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "Tax",
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          Text(
                            '₹${(entry.cgstAmountDouble + entry.sgstAmountDouble + entry.igstAmountDouble).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            "Total",
                            style: TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          Text(
                            '₹${_calculateTotal(entry).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateTotal(LedgerEntry e) =>
      e.taxableValueDouble +
      e.cgstAmountDouble +
      e.sgstAmountDouble +
      e.igstAmountDouble;

  // -- Summary Cards --
  Widget _buildGstCardSection(
    String title,
    String total,
    Color color,
    TaxData item,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(51)), // 0.2 * 255
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(13), // 0.05 * 255
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.currency_rupee, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryDetailCol(
                  "Taxable Value",
                  item.taxableValue,
                ),
              ),
              Expanded(
                child: _buildSummaryDetailCol(
                  "CGST",
                  item.cgst,
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: _buildSummaryDetailCol(
                  "SGST",
                  item.sgst,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryDetailCol(
                  "IGST",
                  item.igst,
                  color: Colors.orange,
                ),
              ),
              Expanded(child: _buildSummaryDetailCol("CESS", item.cess)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Total GST",
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '₹${item.total}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryDetailCol(String label, String val, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          '₹${val}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildNetLiabilitySection() {
    if (_summaryData == null) return const SizedBox.shrink();
    final n = _summaryData!.netLiability;
    final isPayable =
        n.totalDouble <
        0; // Negative usually implies liability in some systems or vice versa. Showing as provided.
    final color = isPayable ? Colors.red : Colors.green[700]!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withAlpha(13), // 0.05 * 255
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(77)), // 0.3 * 255
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: color),
              const SizedBox(width: 8),
              const Text(
                "Net GST Refund/Carry Forward",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Positive = Tax Payable, Negative = Refund/Carry Forward",
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryDetailCol("CGST", n.cgst, color: color),
              _buildSummaryDetailCol("SGST", n.sgst, color: color),
              _buildSummaryDetailCol("IGST", n.igst, color: color),
              _buildSummaryDetailCol("Total Net", n.total, color: color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHsnSummaryCard(List<HsnSummaryItem> list) {
    if (list.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "HSN-wise Summary",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (c, i) => Divider(color: Colors.grey[100]),
            itemBuilder: (c, i) => Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    list[i].hsnCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "₹${list[i].taxableValue}",
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: Colors.grey[800]),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "₹${list[i].totalGst}",
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: _primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -- Party Widgets --
  Widget _buildPartyTotalsCards() {
    if (_partyWiseData == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              "Total Parties",
              '${_partyWiseData!.partyCount}',
              Colors.purple,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
              "Total Taxable",
              '₹${_formatAmount(_partyWiseData!.totals.totalTaxable)}',
              Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartiesTableDesktop(List<PartyItem> parties) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                _buildHeaderCell('Party Name', 3),
                _buildHeaderCell('GSTIN', 2),
                _buildHeaderCell('Trx', 1),
                _buildHeaderCell('Taxable', 2, alignRight: true),
                _buildHeaderCell('Total GST', 2, alignRight: true),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: parties.length,
            separatorBuilder: (c, i) =>
                Divider(height: 1, color: Colors.grey[100]),
            itemBuilder: (c, i) => Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      parties[i].partyName,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      parties[i].gstin,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${parties[i].transactionCount}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '₹${_formatAmount(parties[i].taxableValue)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '₹${_formatAmount(parties[i].totalGst)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
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

  Widget _buildPartyListCard(PartyItem p) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  p.partyName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${p.transactionCount} Trx',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Text(
            p.gstin,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Taxable Value",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    '₹${_formatAmount(p.taxableValue)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    "Total GST",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  Text(
                    '₹${_formatAmount(p.totalGst)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Helperes ---
  // ... (Header cell, Empty State, Error State as before)
  Widget _buildHeaderCell(String text, int flex, {bool alignRight = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(msg, style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _refreshActiveTab,
              child: const Text("Refresh"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback retry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            TextButton(onPressed: retry, child: const Text("Retry")),
          ],
        ),
      ),
    );
  }

  String _formatAmount(String amount) {
    double v = double.tryParse(amount) ?? 0.0;
    if (v >= 10000000) return '${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(2)}L';
    return v.toStringAsFixed(2);
  }
}
