import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class SupplierReportScreen extends StatefulWidget {
  final String storeId;
  final Map<String, dynamic> supplier;

  const SupplierReportScreen({
    super.key,
    required this.storeId,
    required this.supplier,
  });

  @override
  State<SupplierReportScreen> createState() => _SupplierReportScreenState();
}

class _SupplierReportScreenState extends State<SupplierReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // State
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _reportData;
  Map<String, dynamic>? _ledgerReport;
  Map<String, dynamic>? _agingReport;

  // Date Filters
  late DateTime _startDate;
  late DateTime _endDate;

  // Design tokens
  final Color primaryColor = const Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Listen to tab changes to rebuild the body (switch slivers)
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) setState(() {});
    });

    // Default: Last 30 days
    _endDate = DateTime.now();
    _startDate = DateTime.now().subtract(const Duration(days: 30));

    _fetchReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
        filter: 'suppliers',
        searchQuery: widget.supplier['id'],
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
                  : CustomScrollView(
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
                  Icons.store_rounded,
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
                            widget.supplier['name'] ?? "Details",
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
                              'SUPPLIER REPORT',
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
    final data = _reportData ?? widget.supplier;

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
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  size: 18,
                  color: Colors.orange,
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
          if (data['city'] != null)
            Text(
              "${data['city']}",
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          if (data['phone_number'] == null && data['city'] == null)
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

  // --- Ledger Report Slivers ---
  List<Widget> _buildLedgerSlivers(bool isDesktop) {
    if (_ledgerReport == null) {
      return [
        const SliverToBoxAdapter(
          child: Center(child: Text("No ledger data found")),
        ),
      ];
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

      // 2. Transactions
      if (isDesktop)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _buildDesktopLedgerTable(_ledgerReport!['transactions']),
          ),
        )
      else
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final txns = _ledgerReport!['transactions'] as List;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildMobileTransactionCard(txns[index]),
            );
          }, childCount: (_ledgerReport!['transactions'] as List).length),
        ),
    ];
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
    final isCredit = txn['credit'] != "0.00";
    final amount = isCredit ? txn['credit'] : txn['debit'];
    final color = isCredit ? Colors.green : Colors.red;

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
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Amount",
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                  Text(
                    _formatCurrency(amount),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontSize: 16,
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
    if (type == 'PURCHASE') {
      bg = Colors.blue[50]!;
      text = Colors.blue[700]!;
    }
    if (type == 'PAYMENT') {
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
        const SliverToBoxAdapter(child: Center(child: Text("No aging data"))),
      ];
    }

    final buckets = [
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
