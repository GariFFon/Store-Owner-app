import 'package:exanor/models/gst_rate_model.dart';
import 'package:exanor/services/gst_service.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class GstRatesScreen extends StatefulWidget {
  final String storeId;

  const GstRatesScreen({super.key, required this.storeId});

  @override
  State<GstRatesScreen> createState() => _GstRatesScreenState();
}

class _GstRatesScreenState extends State<GstRatesScreen> {
  bool _isLoading = true;
  List<GstRate> _rates = [];
  int _totalCount = 0;
  int _limit = 50;
  int _offset = 0;
  String _searchQuery = '';
  // Used for debounce
  Timer? _debounce;

  // Stats
  int _activeCount = 0;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchRates() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await GstService.fetchGstRates(
        storeId: widget.storeId,
        limit: _limit,
        offset: _offset,
        searchQuery: _searchQuery,
      );

      if (mounted) {
        setState(() {
          _rates = response.rates;
          _totalCount = response.count;
          // Calculate active count from the current batch or use API if available
          // Since API doesn't give total active count separately, we can only show active in current batch
          // or we just show the count. The image has "Active Rates 50".
          // If the limit is 50, and all are active, maybe that's why.
          // We will count visible active rates.
          _activeCount = _rates.where((r) => r.isActive).length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
        _offset = 0; // Reset pagination
      });
      _fetchRates();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'GST Rates',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchRates),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by HSN code or description...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total GST Rates',
                          '$_totalCount',
                          Colors.blue.shade700,
                          bgColor: Colors.blue.shade50,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Active Rates',
                          '$_activeCount', // This is only for the current page, ideally should be total active from API
                          Colors.green.shade700,
                          bgColor: Colors.green.shade50,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Loaded',
                          '${_rates.length} / $_totalCount',
                          Colors.blue.shade700,
                          bgColor: Colors.blue.shade50,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Table
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildRatesTable(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color valueColor, {
    Color? bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatesTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              color: Colors.grey.shade50,
            ),
            child: Row(
              children: [
                _buildHeaderCell('HSN Code', flex: 2),
                _buildHeaderCell('Description', flex: 4),
                _buildHeaderCell('CGST %', flex: 1),
                _buildHeaderCell('SGST %', flex: 1),
                _buildHeaderCell('IGST %', flex: 1),
                _buildHeaderCell('CESS %', flex: 1),
                _buildHeaderCell('Effective From', flex: 2),
                _buildHeaderCell(
                  'Status',
                  flex: 1,
                  alignment: Alignment.centerRight,
                ),
              ],
            ),
          ),

          // List
          if (_rates.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Text("No rates found"),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rates.length,
              separatorBuilder: (c, i) =>
                  Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                final rate = _rates[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      // HSN
                      Expanded(
                        flex: 2,
                        child: Text(
                          rate.hsnCode,
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      // Description
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            rate.hsnDescription,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      // Percentages
                      _buildPercentCell(rate.cgstPercent),
                      _buildPercentCell(rate.sgstPercent),
                      _buildPercentCell(rate.igstPercent),
                      _buildPercentCell(rate.cessPercent), // CESS
                      // Effective From
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rate.effectiveFrom,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            if (rate.effectiveTo.isNotEmpty)
                              Text(
                                "To: ${rate.effectiveTo}",
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.redAccent,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Status
                      Expanded(
                        flex: 1,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: rate.isActive
                                  ? Colors.green.shade600
                                  : Colors.grey,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              rate.isActive ? 'Active' : 'Inactive',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

  Widget _buildHeaderCell(
    String text, {
    int flex = 1,
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildPercentCell(String value) {
    return Expanded(
      flex: 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        margin: const EdgeInsets.only(right: 4), // Spacing
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          "$value%",
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }
}
