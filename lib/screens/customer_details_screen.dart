import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class CustomerDetailsScreen extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic> customer;

  const CustomerDetailsScreen({
    super.key,
    required this.storeId,
    required this.customer,
  });

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _reportData;
  Map<String, dynamic>? _ledgerReport;
  Map<String, dynamic>? _agingReport;

  // Date Filters
  late DateTime _startDate;
  late DateTime _endDate;

  // Transaction Filters
  String _txnSearchQuery = "";
  String _txnVoucherType = "All Voucher Types";
  String _txnSortOption = "Sort by Date";

  // --- Ledger Report Slivers ---
  List<Widget> _buildLedgerSlivers(bool isDesktop) {
    if (_ledgerReport == null) {
      return [
        const SliverToBoxAdapter(
          child: Center(child: Text("No ledger data found")),
        ),
      ];
    }

    // Filter Logic
    List transactions = List.from(_ledgerReport!['transactions'] ?? []);

    // 1. Search
    if (_txnSearchQuery.isNotEmpty) {
      final q = _txnSearchQuery.toLowerCase();
      transactions = transactions.where((t) {
        final voucher = (t['voucher_number'] ?? "").toString().toLowerCase();
        final type = (t['voucher_type'] ?? "").toString().toLowerCase();
        return voucher.contains(q) || type.contains(q);
      }).toList();
    }

    // 2. Voucher Type
    if (_txnVoucherType != "All Voucher Types") {
      transactions = transactions.where((t) {
        // Map UI string to backend type if needed, or just match direct string
        // Assuming backend types like 'Sales', 'Receipt' etc match or contain the string
        // For now, let's assume exact match or contains
        return (t['voucher_type'] ?? "").toString() == _txnVoucherType;
      }).toList();
    }

    // 3. Sort
    if (_txnSortOption == "Sort by Date") {
      // Sort by date descending (newest first)
      transactions.sort((a, b) {
        final d1 = DateTime.tryParse(a['date'] ?? "") ?? DateTime(1900);
        final d2 = DateTime.tryParse(b['date'] ?? "") ?? DateTime(1900);
        return d2.compareTo(d1);
      });
    } else if (_txnSortOption == "Sort by Voucher") {
      // Sort by voucher number
      transactions.sort((a, b) {
        final v1 = a['voucher_number'] ?? "";
        final v2 = b['voucher_number'] ?? "";
        return v1.toString().compareTo(v2.toString());
      });
    } else if (_txnSortOption == "Amount: High to Low") {
      // Sort by amount descending (highest first)
      transactions.sort((a, b) {
        final amtA =
            double.tryParse(
              (a['debit'] == '0.00' ? a['credit'] : a['debit']).toString(),
            ) ??
            0;
        final amtB =
            double.tryParse(
              (b['debit'] == '0.00' ? b['credit'] : b['debit']).toString(),
            ) ??
            0;
        return amtB.compareTo(amtA);
      });
    } else if (_txnSortOption == "Amount: Low to High") {
      // Sort by amount ascending (lowest first)
      transactions.sort((a, b) {
        final amtA =
            double.tryParse(
              (a['debit'] == '0.00' ? a['credit'] : a['debit']).toString(),
            ) ??
            0;
        final amtB =
            double.tryParse(
              (b['debit'] == '0.00' ? b['credit'] : b['debit']).toString(),
            ) ??
            0;
        return amtA.compareTo(amtB);
      });
    }

    return [
      // 1. Ledger Summary Stats (Opening, Debit, Credit, Closing)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              final tiles = [
                _buildSummaryTile(
                  "Opening Balance",
                  _formatCurrency(_ledgerReport!['opening_balance']),
                  isBold: true,
                ),
                _buildSummaryTile(
                  "Total Debit",
                  _formatCurrency(_ledgerReport!['total_debit']),
                  color: Colors.red[50],
                  textColor: Colors.red[700],
                ),
                _buildSummaryTile(
                  "Total Credit",
                  _formatCurrency(_ledgerReport!['total_credit']),
                  color: Colors.green[50],
                  textColor: Colors.green[700],
                ),
                _buildSummaryTile(
                  "Closing Balance",
                  _formatCurrency(_ledgerReport!['closing_balance']),
                  isBold: true,
                ),
              ];

              if (isWide) {
                return Row(
                  children: [
                    Expanded(child: tiles[0]),
                    const SizedBox(width: 12),
                    Expanded(child: tiles[1]),
                    const SizedBox(width: 12),
                    Expanded(child: tiles[2]),
                    const SizedBox(width: 12),
                    Expanded(child: tiles[3]),
                  ],
                );
              }
              // Mobile Grid 2x2
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: tiles[0]),
                      const SizedBox(width: 12),
                      Expanded(child: tiles[3]),
                    ],
                  ), // Opening & Closing top
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: tiles[1]),
                      const SizedBox(width: 12),
                      Expanded(child: tiles[2]),
                    ],
                  ), // Debit & Credit below
                ],
              );
            },
          ),
        ),
      ),

      // 2. Filters Toolbar
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: _buildTransactionFilters(isDesktop),
        ),
      ),

      // 3. Transactions
      if (isDesktop)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildDesktopLedgerTable(transactions),
          ),
        )
      else
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildMobileTransactionCard(transactions[index]),
            );
          }, childCount: transactions.length),
        ),
    ];
  }

  Widget _buildTransactionFilters(bool isDesktop) {
    if (!isDesktop) {
      // Mobile Layout: Stacked or scrollable
      return Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _txnSearchQuery = v),
            decoration: InputDecoration(
              hintText: "Search By Voucher No...",
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: Colors.grey,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterDropdown(
                  value: _txnVoucherType,
                  items: [
                    "All Voucher Types",
                    "RECEIPT",
                    "SALES",
                    "CN",
                    "PAYMENT",
                  ],
                  onChanged: (v) => setState(() => _txnVoucherType = v!),
                ),
                const SizedBox(width: 12),
                _buildFilterDropdown(
                  value: _txnSortOption,
                  items: [
                    "Sort by Date",
                    "Sort by Voucher",
                    "Amount: High to Low",
                    "Amount: Low to High",
                  ],
                  onChanged: (v) => setState(() => _txnSortOption = v!),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Desktop Layout
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            onChanged: (v) => setState(() => _txnSearchQuery = v),
            decoration: InputDecoration(
              hintText: "Search transactions...",
              prefixIcon: const Icon(
                Icons.search,
                size: 20,
                color: Colors.grey,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 0,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 16),
        _buildFilterDropdown(
          value: _txnVoucherType,
          items: ["All Voucher Types", "RECEIPT", "SALES", "CN", "PAYMENT"],
          onChanged: (v) => setState(() => _txnVoucherType = v!),
        ),
        const SizedBox(width: 16),
        _buildFilterDropdown(
          value: _txnSortOption,
          items: [
            "Sort by Date",
            "Sort by Voucher",
            "Amount: High to Low",
            "Amount: Low to High",
          ],
          onChanged: (v) => setState(() => _txnSortOption = v!),
        ),
        const SizedBox(width: 16),
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: IconButton(
            icon: const Icon(Icons.tune_rounded),
            color: Colors.grey[600],
            onPressed: () {
              // Additional filters if needed
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged, // Correct type here
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.grey,
          ),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(e, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Listen to tab changes to rebuild the body (switch slivers)
    _tabController.addListener(() {
      setState(() {});
    });

    // Default: Last 30 days
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));

    _fetchReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dateFormat = DateFormat('yyyy-MM-dd');
      final result = await StoreOwnerApiService.getParties(
        widget.storeId,
        page: 1,
        pageSize: 50,
        filter: 'customers',
        searchQuery: widget.customer['id'],
        includeAgingReport: true,
        includeLedgerReport: true,
        ledgerStartDate: dateFormat.format(_startDate),
        ledgerEndDate: dateFormat.format(_endDate),
        asOfDate: dateFormat.format(DateTime.now()),
      );

      final body = result['body'] ?? {};
      final parties = body['parties'] as List<dynamic>? ?? [];

      if (parties.isNotEmpty) {
        final data = parties.first;
        if (mounted) {
          setState(() {
            _reportData = data;
            _ledgerReport = data['ledger_report'];
            _agingReport = data['aging_report'];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load report";
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '₹0.00';
    final val = double.tryParse(amount.toString()) ?? 0.0;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    return formatter.format(val);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(dateStr));
    } catch (e) {
      return dateStr;
    }
  }

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
            _buildHeader(context),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(child: Text(_errorMessage!))
                  : RefreshIndicator(
                      onRefresh: _fetchReport,
                      child: CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  _buildProfileSection(isDesktop),
                                  const SizedBox(height: 24),
                                  _buildTabSwitcher(),
                                ],
                              ),
                            ),
                          ),
                          if (_tabController.index == 0)
                            ..._buildLedgerSlivers(isDesktop)
                          else
                            ..._buildAgingSlivers(isDesktop),

                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 40),
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

  Widget _buildHeader(BuildContext context) {
    const lightBlueBg = Color(0xFFEFF6FF);
    const watermarkColor = Color(0xFFDBEAFE);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: lightBlueBg,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.2), // Softer shadow
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRect(
        child: Stack(
          children: [
            // Watermark
            Positioned(
              right: -20,
              top: -10,
              child: Transform.rotate(
                angle: -math.pi / 6,
                child: Icon(
                  Icons.account_circle_rounded,
                  size: 160,
                  color: watermarkColor.withOpacity(0.8),
                ),
              ),
            ),

            // Content
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back Button
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

                    // Title Area
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.customer['name'] ?? "Details",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B), // Slate-800
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
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
                              'CUSTOMER REPORT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2563EB), // Blue-600
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
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

  // --- Profile Section (Innovative Dashboard) ---
  Widget _buildProfileSection(bool isDesktop) {
    final data = _reportData ?? widget.customer;

    // Main "Hero" Card for Outstanding
    final outstandingWidget = Container(
      padding: const EdgeInsets.all(24),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  size: 18,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "TOTAL OUTSTANDING",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _formatCurrency(data['total_outstanding']),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );

    // Contact & GST Small Cards
    Widget buildSmallCard(
      String title,
      IconData icon,
      Color color,
      Widget content,
    ) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      );
    }

    final contactWidget = buildSmallCard(
      "CONTACT INFO",
      Icons.contact_phone,
      Colors.blue,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data['phone_number'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                "${data['phone_number']}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          if (data['email'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                "${data['email']}",
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
          if (data['city'] != null || data['state'] != null)
            Text(
              [
                data['city'],
                data['state'],
              ].where((e) => e != null && e.toString().isNotEmpty).join(', '),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          if (data['phone_number'] == null &&
              data['email'] == null &&
              data['city'] == null &&
              data['state'] == null)
            Text(
              "N/A",
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
        ],
      ),
    );

    final taxWidget = buildSmallCard(
      "TAX INFO",
      Icons.receipt_long,
      Colors.purple,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "GSTIN",
            style: TextStyle(fontSize: 10, color: Colors.grey[400]),
          ),
          Text(
            data['gstin'] ?? 'N/A',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (data['state_code'] != null) ...[
            const SizedBox(height: 8),
            Text(
              "State Code",
              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
            ),
            Text(
              data['state_code'] ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: contactWidget),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: outstandingWidget),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: taxWidget),
        ],
      );
    }

    return Column(
      children: [
        outstandingWidget,
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: contactWidget),
            const SizedBox(width: 16),
            Expanded(child: taxWidget),
          ],
        ),
      ],
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        labelColor: const Color(0xFF0F172A),
        unselectedLabelColor: Colors.grey[500],
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        tabs: const [
          Tab(text: "Ledger Report"),
          Tab(text: "Aging Report"),
        ],
      ),
    );
  }

  Widget _buildSummaryTile(
    String title,
    String value, {
    Color? color,
    Color? textColor,
    bool isBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: textColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLedgerTable(List transactions) {
    if (transactions.isEmpty)
      return const Center(child: Text("No transactions"));
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.5), // Date
          1: FlexColumnWidth(2), // Voucher
          2: FlexColumnWidth(1), // Type
          3: FlexColumnWidth(1.5), // Debit
          4: FlexColumnWidth(1.5), // Credit
          5: FlexColumnWidth(1.5), // Balance
        },
        children: [
          // Header
          TableRow(
            decoration: BoxDecoration(color: Colors.grey[50]),
            children: [
              for (var h in [
                "Date",
                "Voucher",
                "Type",
                "Debit",
                "Credit",
                "Balance",
              ])
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    h,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          // Rows
          ...transactions.map((txn) {
            return TableRow(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[100]!)),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _formatDate(txn['date']),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    txn['voucher_number'] ?? '-',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildTypeBadge(txn['voucher_type']),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    txn['debit'] != '0.00'
                        ? _formatCurrency(txn['debit'])
                        : '-',
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    txn['credit'] != '0.00'
                        ? _formatCurrency(txn['credit'])
                        : '-',
                    style: const TextStyle(color: Colors.green, fontSize: 13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _formatCurrency(txn['running_balance']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMobileTransactionCard(dynamic txn) {
    final debit = txn['debit'] ?? "0.00";
    final credit = txn['credit'] ?? "0.00";
    final balance = txn['running_balance'] ?? "0.00";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(txn['date']),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              _buildTypeBadge(txn['voucher_type']),
            ],
          ),
          const Divider(height: 24),
          Column(
            children: [
              // Voucher Number Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Voucher No",
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  Text(
                    txn['voucher_number'] ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Debit, Credit, Balance Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Debit",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          debit != "0.00" ? _formatCurrency(debit) : "-",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: debit != "0.00"
                                ? Colors.red
                                : Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Credit",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          credit != "0.00" ? _formatCurrency(credit) : "-",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: credit != "0.00"
                                ? Colors.green
                                : Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Balance",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(balance),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                      ],
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

  Widget _buildTypeBadge(String? type) {
    Color bg = Colors.grey[100]!;
    Color text = Colors.grey[600]!;
    if (type == 'SALES') {
      bg = Colors.blue[50]!;
      text = Colors.blue[700]!;
    }
    if (type == 'RECEIPT') {
      bg = Colors.green[50]!;
      text = Colors.green[700]!;
    }
    if (type == 'CN' || type == 'PAYMENT') {
      bg = Colors.purple[50]!;
      text = Colors.purple[700]!;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type ?? 'UNKNOWN',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }

  // --- Aging Report Slivers ---
  List<Widget> _buildAgingSlivers(bool isDesktop) {
    if (_agingReport == null) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text("No aging data available")),
        ),
      ];
    }

    final buckets = [
      {
        'key': 'total_outstanding',
        'label': 'Total Outstanding',
        'bg': Colors.blue[50]!,
        'text': Colors.blue[900]!,
      },
      {
        'key': '0_30',
        'label': '0-30 Days',
        'bg': Colors.green[50]!,
        'text': Colors.green[900]!,
      },
      {
        'key': '31_60',
        'label': '31-60 Days',
        'bg': Colors.yellow[50]!,
        'text': Colors.orange[900]!,
      },
      {
        'key': '61_90',
        'label': '61-90 Days',
        'bg': Colors.orange[50]!,
        'text': Colors.orange[900]!,
      },
      {
        'key': '91_120',
        'label': '91-120 Days',
        'bg': Colors.deepOrange[50]!,
        'text': Colors.deepOrange[900]!,
      },
      {
        'key': '121_180',
        'label': '121-180 Days',
        'bg': Colors.red[50]!,
        'text': Colors.red[900]!,
      },
      {
        'key': 'above_180',
        'label': '180+ Days',
        'bg': Colors.red[100]!,
        'text': Colors.red[900]!,
      },
    ];

    if (isDesktop) {
      // Grid for Tablet/Desktop
      return [
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildAgingCard(buckets[index]),
              childCount: buckets.length,
            ),
          ),
        ),
      ];
    } else {
      // List of Cards for Phone
      return [
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAgingCard(buckets[index]),
              ),
              childCount: buckets.length,
            ),
          ),
        ),
      ];
    }
  }

  Widget _buildAgingCard(Map<String, dynamic> bucket) {
    final val = _agingReport![bucket['key']] ?? '0.00';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bucket['bg'],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (bucket['bg'] as Color).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            bucket['label'],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: (bucket['text'] as Color).withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatCurrency(val),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: bucket['text'],
            ),
          ),
        ],
      ),
    );
  }
}
