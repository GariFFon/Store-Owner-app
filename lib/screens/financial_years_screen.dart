import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/models/financial_year.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  String _selectedFilter = 'All'; // Filter state: All, Active, Inactive, Locked, Unlocked

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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light grey background
      appBar: AppBar(
        title: const TranslatedText('Financial Years'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchFinancialYears,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildStatsCards(),
                    const SizedBox(height: 24),
                    _buildFinancialYearsList(),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        'All $_totalCount financial years loaded',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              Icon(Icons.calendar_month, color: Colors.blue[700], size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Financial Years',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Manage financial year periods for accounting',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCreateFinancialYearSheet,
                  icon: const Icon(Icons.add, size: 18, color: Colors.white),
                  label: const Text(
                    'Create Financial Year',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    icon: Icon(Icons.filter_list, color: Colors.blue[700]),
                    items: ['All', 'Active', 'Inactive', 'Locked', 'Unlocked']
                        .map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedFilter = newValue;
                        });
                        _fetchFinancialYears();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total\nFinancial Years',
            _totalCount.toString(),
            Colors.blue[50]!,
            Colors.blue[700]!,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Active\nFinancial Years',
            _activeCount.toString(),
            Colors.green[50]!,
            Colors.green[700]!,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Locked\nFinancial Years',
            _lockedCount.toString(),
            Colors.orange[50]!,
            Colors.orange[700]!,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color bgColor,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialYearsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    _buildHeaderCell('Period', width: 150),
                    _buildHeaderCell('Start Date', width: 120),
                    _buildHeaderCell('End Date', width: 120),
                    _buildHeaderCell('Duration', width: 100),
                    _buildHeaderCell('Status', width: 100),
                    _buildHeaderCell('Lock Status', width: 120),
                    _buildHeaderCell('Created', width: 120),
                  ],
                ),
              ),
              const Divider(height: 1),
              // List Items
              _isLoading
                  ? const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _financialYears.asMap().entries.map((entry) {
                        final index = entry.key;
                        final fy = entry.value;
                        return Column(
                          children: [
                            if (index > 0) const Divider(height: 1),
                            _buildListItem(fy),
                          ],
                        );
                      }).toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {double width = 100}) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildListItem(FinancialYear fy) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              fy.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              dateFormat.format(DateTime.parse(fy.startDate)),
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              dateFormat.format(DateTime.parse(fy.endDate)),
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              fy.durationText,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ),
          SizedBox(
            width: 100,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: fy.isActive ? Colors.green[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                fy.isActive ? 'Active' : 'Inactive',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fy.isActive ? Colors.white : Colors.grey[800],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Icon(
                  fy.isLocked ? Icons.lock : Icons.lock_open,
                  size: 14,
                  color: fy.isLocked ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: fy.isLocked ? Colors.red : Colors.green,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    fy.isLocked ? 'Locked' : 'Unlocked',
                    style: TextStyle(
                      color: fy.isLocked ? Colors.red : Colors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              dateFormat.format(DateTime.parse(fy.createdAt)),
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ),
        ],
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
    );

    if (picked != null) {
      if (mounted) {
        setState(() {
          if (isStart) {
            _startDate = picked;
            // Auto-set end date to 31st March of next year if user picks April 1st
            // Or roughly 1 year ahead
            if (_endDate == null) {
              // Try to smart guess Indian FY
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
    if (_startDate == null || _endDate == null) {
      return;
    }

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
        // Success
        Navigator.pop(context);
        widget.onSuccess();

        final responseData = response['response'];
        final start = responseData['start_date'] ?? _startDate.toString();
        final end = responseData['end_date'] ?? _endDate.toString();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Financial Year Created Successfully for $start to $end',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (response.containsKey('status') &&
          response['status'] == 400 &&
          response.containsKey('response')) {
        // Error from API
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['response']),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unexpected response from server'),
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
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  String get _previewText {
    if (_startDate == null || _endDate == null)
      return 'Select dates to preview';
    final start = DateFormat('yyyy-MM-dd').format(_startDate!);
    final end = DateFormat('yyyy-MM-dd').format(_endDate!);
    return 'FY $start to $end';
  }

  String get _durationText {
    if (_startDate == null || _endDate == null) return '';
    final days = _endDate!.difference(_startDate!).inDays;
    return 'Duration: $days days';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create Financial Year',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                'Define a new financial year period for your store',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 24),
              const Text(
                'Financial Year Period',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _selectDate(true),
                child: AbsorbPointer(
                  child: TextField(
                    controller: _startDateController,
                    decoration: InputDecoration(
                      labelText: 'Start Date *',
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
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _selectDate(false),
                child: AbsorbPointer(
                  child: TextField(
                    controller: _endDateController,
                    decoration: InputDecoration(
                      labelText: 'End Date *',
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
              ),
              const SizedBox(height: 24),
              const Text(
                'Settings',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.2)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Set this as the active financial year',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isActive,
                          onChanged: (val) => setState(() => _isActive = val),
                          activeColor: Colors.blue[700],
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Locked',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Prevent modifications to this period',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isLocked,
                          onChanged: (val) => setState(() => _isLocked = val),
                          activeColor: Colors.blue[700],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _previewText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _durationText,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.grey[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createFinancialYear,
                      child: _isCreating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create Financial Year',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.blue[300],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
