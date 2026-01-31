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

  @override
  void initState() {
    super.initState();
    _fetchFinancialYears();
  }

  Future<void> _fetchFinancialYears() async {
    setState(() => _isLoading = true);
    try {
      final response = await StoreOwnerApiService.getFinancialYears(
        widget.storeId,
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Create functionality not implemented yet'),
                  ),
                );
              },
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
