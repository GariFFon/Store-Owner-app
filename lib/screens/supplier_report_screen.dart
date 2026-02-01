import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  // State for Ledger Report
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _reportData;
  Map<String, dynamic>? _ledgerReport;
  Map<String, dynamic>? _agingReport;

  // Date Filters
  late DateTime _startDate;
  late DateTime _endDate;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Default to last 30 days for ledger
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
        pageSize:
            50, // Assuming 50 items for ledger pagination if needed, but report usually has nested list
        filter: 'suppliers',
        searchQuery: widget
            .supplier['id'], // Search by Supplier ID to get specific report
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
        if (mounted) {
          setState(() {
            _errorMessage = "No report data found.";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load report: $e";
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
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date); // Jun 30, 2026
    } catch (e) {
      return dateStr;
    }
  }

  /*
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ), // Allow future? Maybe not for ledger
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchReport();
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supplierName = widget.supplier['name'] ?? 'Unknown Supplier';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              supplierName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Text(
              'Supplier Details',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : Column(
              children: [
                _buildSummaryCards(theme),
                _buildTabBar(theme),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildLedgerTab(theme), _buildAgingTab(theme)],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme) {
    // Current showing data might be from the list item initially,
    // but ideally we use the fresh data from _reportData if available.
    final data = _reportData ?? widget.supplier;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white, // Or a very light grey background for the section
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive layout: Single column on mobile, Row on tablet/desktop
          final isWide = constraints.maxWidth > 800;

          final cards = [
            _buildInfoCard(
              title: 'Contact Information',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data['phone_number'] != null)
                    _buildIconText(Icons.phone, '${data['phone_number']}'),
                  if (data['email'] != null)
                    _buildIconText(Icons.email, '${data['email']}'),
                  if (data['city'] != null || data['state'] != null)
                    _buildIconText(
                      Icons.location_on,
                      [
                        data['city'],
                        data['state'],
                      ].where((e) => e != null).join(', '),
                    ),
                ],
              ),
              flex: 3,
            ),
            if (isWide)
              const SizedBox(width: 16)
            else
              const SizedBox(height: 12),
            _buildInfoCard(
              title: 'Total Outstanding',
              content: Text(
                _formatCurrency(data['total_outstanding']),
                style: const TextStyle(
                  color: Colors.orange, // Match design
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              flex: 4,
            ),
            if (isWide)
              const SizedBox(width: 16)
            else
              const SizedBox(height: 12),
            _buildInfoCard(
              title: 'GST Information',
              content: Text(
                data['gstin'] ?? 'N/A',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              flex: 3,
            ),
          ];

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: cards[0] as Widget),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: cards[2] as Widget), // Outstanding
                const SizedBox(width: 16),
                Expanded(flex: 3, child: cards[4] as Widget), // GST
              ],
            );
          } else {
            return Column(
              children: [
                cards[0] as Widget,
                const SizedBox(height: 12),
                cards[2] as Widget,
                const SizedBox(height: 12),
                cards[4] as Widget,
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required Widget content,
    int flex = 1,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB), // Very light grey
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildIconText(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.blue,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Colors.blue,
        indicatorWeight: 3,
        tabs: [
          const Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.description_outlined, size: 18),
                SizedBox(width: 8),
                Text('Ledger Report'),
              ],
            ),
          ),
          const Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 18),
                SizedBox(width: 8),
                Text('Aging Report'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerTab(ThemeData theme) {
    final report = _ledgerReport;
    if (report == null) return const Center(child: Text("No ledger data"));

    final transactions = report['transactions'] as List<dynamic>? ?? [];

    return Column(
      children: [
        // Controls
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Summary Row
              Row(
                children: [
                  _buildSummaryTile(
                    'Opening Balance',
                    _formatCurrency(report['opening_balance']),
                    isBold: true,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryTile(
                    'Total Debit',
                    _formatCurrency(report['total_debit']),
                    color: Colors.red[50],
                    textColor: Colors.red,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryTile(
                    'Total Credit',
                    _formatCurrency(report['total_credit']),
                    color: Colors.green[50],
                    textColor: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryTile(
                    'Closing Balance',
                    _formatCurrency(report['closing_balance']),
                    isBold: true,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.grey[50],
          child: const Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Date',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Voucher',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Type',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Debit',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Credit',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Balance',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Transaction List
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: transactions.length,
            separatorBuilder: (ctx, i) =>
                const Divider(height: 1, thickness: 0.5),
            itemBuilder: (context, index) {
              final txn = transactions[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatDate(txn['date']),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            txn['voucher_number'] ?? '-',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          // Only show narration if space permits or on tap?
                          // For now keeping clean
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildTypeBadge(txn['voucher_type']),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        txn['debit'] != "0.00"
                            ? _formatCurrency(txn['debit'])
                            : '-',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        txn['credit'] != "0.00"
                            ? _formatCurrency(txn['credit'])
                            : '-',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatCurrency(txn['running_balance']),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryTile(
    String title,
    String value, {
    Color? color,
    Color? textColor,
    bool isBold = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color ?? Colors.grey[50], // Very light background
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: textColor ?? Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String? type) {
    Color bg = Colors.grey[200]!;
    Color text = Colors.grey[800]!;

    if (type == 'PURCHASE') {
      bg = Colors.blue[50]!;
      text = Colors.blue[700]!;
    } else if (type == 'PAYMENT') {
      bg = Colors.purple[50]!;
      text = Colors.purple[700]!;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
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
      ),
    );
  }

  Widget _buildAgingTab(ThemeData theme) {
    final report = _agingReport;
    if (report == null)
      return const Center(child: Text("No aging data available"));

    final buckets = [
      {
        'key': '0_30',
        'label': '0-30 Days',
        'color': Colors.green[50],
        'text': Colors.green[800],
      },
      {
        'key': '31_60',
        'label': '31-60 Days',
        'color': Colors.yellow[50],
        'text': Colors.orange[800],
      },
      {
        'key': '61_90',
        'label': '61-90 Days',
        'color': Colors.orange[50],
        'text': Colors.orange[900],
      },
      {
        'key': '91_120',
        'label': '91-120 Days',
        'color': Colors.red[50],
        'text': Colors.red[800],
      },
      {
        'key': '121_180',
        'label': '121-180 Days',
        'color': Colors.red[50],
        'text': Colors.red[800],
      },
      {
        'key': 'above_180',
        'label': '180+ Days',
        'color': Colors.red[50],
        'text': Colors.red[800],
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Outstanding by Age",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Grid of buckets
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: buckets.length,
                    itemBuilder: (context, index) {
                      final bucket = buckets[index];
                      final val = report[bucket['key']] ?? '0.00';
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: bucket['color'] as Color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (bucket['color'] as Color).withOpacity(0.5),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              bucket['label'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: bucket['text'] as Color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCurrency(val),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: bucket['text'] as Color,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Total Footer
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Total Outstanding",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatCurrency(report['total_outstanding']),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
