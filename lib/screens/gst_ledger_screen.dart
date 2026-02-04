import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:exanor/models/gst_ledger_model.dart';
import 'package:exanor/services/gst_ledger_service.dart';

class GstLedgerScreen extends StatefulWidget {
  final String storeId;

  const GstLedgerScreen({super.key, required this.storeId});

  @override
  State<GstLedgerScreen> createState() => _GstLedgerScreenState();
}

class _GstLedgerScreenState extends State<GstLedgerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Filter controllers
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  late TextEditingController _searchController;

  // Filter values
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 27));
  DateTime _endDate = DateTime.now();
  String _selectedGstType = 'all';
  String _selectedVoucherType = 'all';
  String _selectedSortBy = 'date';
  bool _showFilters = false;

  // Data
  GstLedgerData? _ledgerData;
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  Timer? _debounce;

  // Colors
  final Color _primaryColor = const Color(0xFF2C2C2C);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _startDateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(_startDate),
    );
    _endDateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(_endDate),
    );
    _searchController = TextEditingController();
    _fetchLedgerData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

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
        voucherType: _selectedVoucherType == 'all' ? null : _selectedVoucherType,
        sortBy: _selectedSortBy,
        sortOrder: 'desc',
        page: _currentPage,
        hsnCode: _searchController.text.isNotEmpty ? _searchController.text : null,
      );

      final response = await GstLedgerService.getGstLedger(request);
      setState(() {
        _ledgerData = response.response;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _setThisMonth() {
    setState(() {
      _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
      _endDate = DateTime.now();
      _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate);
      _endDateController.text = DateFormat('dd/MM/yyyy').format(_endDate);
    });
    _fetchLedgerData();
  }

  void _setLastMonth() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1, 1);
    final lastDayOfLastMonth = DateTime(now.year, now.month, 0);
    
    setState(() {
      _startDate = lastMonth;
      _endDate = lastDayOfLastMonth;
      _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate);
      _endDateController.text = DateFormat('dd/MM/yyyy').format(_endDate);
    });
    _fetchLedgerData();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          _startDateController.text = DateFormat('dd/MM/yyyy').format(picked);
        } else {
          _endDate = picked;
          _endDateController.text = DateFormat('dd/MM/yyyy').format(picked);
        }
      });
      _fetchLedgerData();
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchLedgerData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildTopBanner(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLedgerListTab(),
                _buildComingSoonTab('GST Summary'),
                _buildComingSoonTab('Party-wise Report'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GST Ledger',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Comprehensive GST transaction reporting with Input Tax Credit analysis',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    icon: Icon(
                      _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(4),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(8),
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey[600],
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(
              icon: Icon(Icons.receipt_long, size: 18),
              text: 'Ledger List',
            ),
            Tab(
              icon: Icon(Icons.summarize, size: 18),
              text: 'GST Summary',
            ),
            Tab(
              icon: Icon(Icons.people_alt, size: 18),
              text: 'Party-wise Report',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedgerListTab() {
    if (_isLoading && _ledgerData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading data',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchLedgerData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          if (_showFilters) _buildFiltersSection(),
          _buildDateRangeSection(),
          _buildTotalsCards(),
          _buildLedgerList(),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'GST Type',
                  value: _selectedGstType,
                  items: const [
                    {'value': 'all', 'label': 'All GST'},
                    {'value': 'input', 'label': 'Input GST (Purchases)'},
                    {'value': 'output', 'label': 'Output GST (Sales)'},
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGstType = value!;
                    });
                    _fetchLedgerData();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown(
                  label: 'Voucher Type',
                  value: _selectedVoucherType,
                  items: const [
                    {'value': 'all', 'label': 'All Voucher Types'},
                    {'value': 'PURCHASE', 'label': 'Purchase'},
                    {'value': 'SALES', 'label': 'Sales'},
                    {'value': 'CREDIT_NOTE', 'label': 'Credit Note'},
                    {'value': 'DEBIT_NOTE', 'label': 'Debit Note'},
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedVoucherType = value!;
                    });
                    _fetchLedgerData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by HSN code...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _fetchLedgerData();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: _onSearchChanged,
            onSubmitted: (_) => _fetchLedgerData(),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<Map<String, String>> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item['value'],
                  child: Text(
                    item['label']!,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Date Range',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
          Expanded(
            child: _buildDateField(
              label: 'Start Date',
              controller: _startDateController,
              onTap: () => _selectDate(context, true),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 20),
            child: Text('to', style: TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: _buildDateField(
              label: 'End Date',
              controller: _endDateController,
              onTap: () => _selectDate(context, false),
            ),
          ),
          const SizedBox(width: 12),
          _buildQuickDateButton('This Month', _setThisMonth),
          const SizedBox(width: 8),
          _buildQuickDateButton('Last Month', _setLastMonth),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: true,
          onTap: onTap,
          decoration: InputDecoration(
            suffixIcon: const Icon(Icons.calendar_today, size: 18),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildQuickDateButton(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        side: BorderSide(color: _primaryColor.withOpacity(0.3)),
        foregroundColor: _primaryColor,
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTotalsCards() {
    if (_ledgerData == null) return const SizedBox.shrink();

    final totals = _ledgerData!.totals;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTotalCard(
                  'Total Taxable Value',
                  '₹${totals.totalTaxableValue.toStringAsFixed(2)}',
                  Colors.black,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTotalCard(
                  'Total CGST',
                  '₹${totals.totalCgstValue.toStringAsFixed(2)}',
                  Colors.blue,
                  rate: '@${totals.totalCgstValue > 0 ? ((totals.totalCgstValue / totals.totalTaxableValue) * 100).toStringAsFixed(2) : "0.00"}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTotalCard(
                  'Total SGST',
                  '₹${totals.totalSgstValue.toStringAsFixed(2)}',
                  Colors.green,
                  rate: '@${totals.totalSgstValue > 0 ? ((totals.totalSgstValue / totals.totalTaxableValue) * 100).toStringAsFixed(2) : "0.00"}%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTotalCard(
                  'Total IGST',
                  '₹${totals.totalIgstValue.toStringAsFixed(2)}',
                  Colors.orange,
                  rate: '@${totals.totalIgstValue > 0 ? ((totals.totalIgstValue / totals.totalTaxableValue) * 100).toStringAsFixed(2) : "0.00"}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTotalCard(
            'Total GST',
            '₹${totals.totalGstValue.toStringAsFixed(2)}',
            Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(String label, String value, Color color, {String? rate}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              if (rate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    rate,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerList() {
    if (_ledgerData == null || _ledgerData!.ledger.isEmpty) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No ledger entries found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${_ledgerData!.count} entries',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sort, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 4),
                    Text(
                      _getSortLabel(),
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
                onSelected: (value) {
                  setState(() {
                    _selectedSortBy = value;
                  });
                  _fetchLedgerData();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'date', child: Text('Sort by Date')),
                  const PopupMenuItem(value: 'amount', child: Text('Sort by Amount')),
                  const PopupMenuItem(value: 'voucher', child: Text('Sort by Voucher #')),
                  const PopupMenuItem(value: 'party', child: Text('Sort by Party')),
                ],
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          itemCount: _ledgerData!.ledger.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final entry = _ledgerData!.ledger[index];
            return _buildLedgerEntryCard(entry);
          },
        ),
      ],
    );
  }

  String _getSortLabel() {
    switch (_selectedSortBy) {
      case 'date':
        return 'Sort by Date';
      case 'amount':
        return 'Sort by Amount';
      case 'voucher':
        return 'Sort by Voucher #';
      case 'party':
        return 'Sort by Party';
      default:
        return 'Sort by Date';
    }
  }

  Widget _buildLedgerEntryCard(LedgerEntry entry) {
    final isInward = entry.voucherType == 'PURCHASE';
    final voucherColor = isInward ? Colors.blue : Colors.green;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: voucherColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: voucherColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.voucherType,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.voucherNumber,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM yyyy').format(DateTime.parse(entry.date)),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${entry.taxableValueDouble.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          
          // Body
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(Icons.person_outline, 'Party', entry.partyName),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.inventory_2_outlined, 'Item', entry.itemName),
                const SizedBox(height: 12),
                _buildInfoRow(Icons.qr_code_outlined, 'HSN', entry.hsnCode),
                
                const Divider(height: 32),
                
                // Tax breakdown
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTaxInfo(
                          'CGST',
                          entry.cgstRate,
                          entry.cgstAmountDouble,
                          Colors.blue,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 50,
                        color: Colors.grey[300],
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      Expanded(
                        child: _buildTaxInfo(
                          'SGST',
                          entry.sgstRate,
                          entry.sgstAmountDouble,
                          Colors.green,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 50,
                        color: Colors.grey[300],
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      Expanded(
                        child: _buildTaxInfo(
                          'IGST',
                          entry.igstRate,
                          entry.igstAmountDouble,
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTaxInfo(String label, String rate, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '@$rate%',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildComingSoonTab(String tabName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 24),
          Text(
            '$tabName Coming Soon',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This feature is under development',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
