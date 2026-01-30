import 'package:exanor/services/store_analytics_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

class OverviewScreen extends StatefulWidget {
  final String storeId;
  final String ownerName;

  const OverviewScreen({
    super.key,
    required this.storeId,
    required this.ownerName,
  });

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  bool _isLoading = true;
  String _selectedFilter = 'Daily'; // Daily, Weekly, Monthly, Yearly, Custom
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  // Data Holders
  double _totalRevenue = 0.0;
  double _revenueGrowth = 0.0;
  int _totalOrders = 0;
  double _ordersGrowth = 0.0;

  List<Map<String, dynamic>> _revenueData = [];
  List<Map<String, dynamic>> _orderCountData = [];
  List<Map<String, dynamic>> _paymentMethodsData = [];
  List<Map<String, dynamic>> _orderMethodsData = [];
  List<dynamic> _sentimentData = [];

  @override
  void initState() {
    super.initState();
    _updateDateRange();
    _fetchAllData();
  }

  void _updateDateRange() {
    final now = DateTime.now();

    switch (_selectedFilter) {
      case 'Daily':
        _startDate = now;
        _endDate = now;
        break;
      case 'Weekly':
        // Last 7 days including today
        _startDate = now.subtract(const Duration(days: 6));
        _endDate = now;
        break;
      case 'Monthly':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0); // Last day of month
        break;
      case 'Yearly':
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31);
        break;
      case 'Custom':
        // Handle custom date picker logic later
        break;
    }
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);

    final dateFormat = DateFormat('yyyy-MM-dd');
    final startDateStr = dateFormat.format(_startDate);
    final endDateStr = dateFormat.format(_endDate);

    // For comparison (yesterday/previous period) - Simplified for now to just show current
    // In a real app, we'd fetch previous period variables to calc growth.

    try {
      final results = await Future.wait([
        StoreAnalyticsService.getRevenueAnalytics(
          storeId: widget.storeId,
          startDate: startDateStr,
          endDate: endDateStr,
          type: 'custom',
        ),
        StoreAnalyticsService.getOrderCountAnalytics(
          storeId: widget.storeId,
          startDate: startDateStr,
          endDate: endDateStr,
          type: 'custom',
        ),
        StoreAnalyticsService.getPaymentMethodAnalytics(
          storeId: widget.storeId,
          startDate: startDateStr,
          endDate: endDateStr,
          type: 'custom',
        ),
        StoreAnalyticsService.getOrderMethodAnalytics(
          storeId: widget.storeId,
          startDate: startDateStr,
          endDate: endDateStr,
          type: 'custom',
        ),
        StoreAnalyticsService.getSentimentAnalytics(
          storeId: widget.storeId,
          startDate: startDateStr,
          endDate: endDateStr,
          type: 'custom',
        ),
      ]);

      if (mounted) {
        setState(() {
          _revenueData = List<Map<String, dynamic>>.from(results[0]);
          _orderCountData = List<Map<String, dynamic>>.from(results[1]);
          _paymentMethodsData = List<Map<String, dynamic>>.from(results[2]);
          _orderMethodsData = List<Map<String, dynamic>>.from(results[3]);
          _sentimentData = List<dynamic>.from(results[4]);

          // Calculate Totals
          _totalRevenue = _revenueData.fold(
            0.0,
            (sum, item) => sum + ((item['revenue'] ?? 0.0) as num).toDouble(),
          );
          _totalOrders = _orderCountData.fold(
            0,
            (sum, item) => sum + ((item['order_count'] ?? 0) as int),
          );

          // Mock growth for display as API doesn't seem to return it directly in the overview sample
          _revenueGrowth = -90.1;
          _ordersGrowth = -92.6;

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching analytics: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), // Light background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              _buildSummaryCards(),
              const SizedBox(height: 24),
              _buildMiddleSection(),
              const SizedBox(height: 24),
              _buildBottomSection(),
              const SizedBox(height: 24),
              _buildOrderVolumeSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, ${widget.ownerName}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ],
        ),
        _buildFilterDropdown(),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          isDense: true,
          items: [
            'Daily',
            'Weekly',
            'Monthly',
            'Yearly',
            'Custom',
          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedFilter = value;
                _updateDateRange();
                _fetchAllData();
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: "Today's Revenue",
            value: NumberFormat.currency(symbol: '₹').format(_totalRevenue),
            growth: _revenueGrowth,
            isCurrency: true,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            title: "Today's Orders",
            value: _totalOrders.toString(),
            growth: _ordersGrowth,
            isCurrency: false,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required double growth,
    required bool isCurrency,
  }) {
    final isPositive = growth >= 0;
    final growthColor = isPositive ? Colors.green : Colors.red;
    final arrow = isPositive ? '↑' : '↓';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Text(
            title,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
          const SizedBox(height: 12),
          _isLoading
              ? Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(height: 32, width: 100, color: Colors.white),
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.red /* Brand color seems red in image */,
                    ),
                  ),
                ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: growthColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$arrow ${growth.abs()}%',
                  style: TextStyle(
                    color: growthColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Text(
                'vs yesterday',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiddleSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive check: if width is small, stack vertically
        if (constraints.maxWidth < 800) {
          return Column(
            children: [
              _buildRevenueChart(),
              const SizedBox(height: 24),
              _buildPaymentMethodsChart(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildRevenueChart()),
            const SizedBox(width: 24),
            Expanded(flex: 1, child: _buildPaymentMethodsChart()),
          ],
        );
      },
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Track your store's total earnings over time.",
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _revenueData.isEmpty
                ? const Center(child: Text("No Data"))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: const Color(0xFFE2E8F0),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) => Text(
                              '₹${value.toInt()}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ), // Hide for cleanliness or implement dates
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _revenueData.asMap().entries.map((e) {
                            return FlSpot(
                              e.key.toDouble(),
                              (e.value['revenue'] as num).toDouble(),
                            );
                          }).toList(),
                          isCurved: true,
                          color: Colors.redAccent,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.redAccent.withOpacity(0.1),
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

  Widget _buildPaymentMethodsChart() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Methods',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Shows how customers prefer to pay.",
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _paymentMethodsData.isEmpty
                ? const Center(child: Text("No Data"))
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 0,
                          centerSpaceRadius: 60,
                          sections: _paymentMethodsData.map((e) {
                            final index = _paymentMethodsData.indexOf(e);
                            final color = [
                              Colors.blue,
                              Colors.purple,
                              Colors.orange,
                              Colors.green,
                            ][index % 4];
                            final val = (e['total_orders'] as num).toDouble();
                            return PieChartSectionData(
                              color: color,
                              value: val,
                              title: '',
                              radius: 25,
                            );
                          }).toList(),
                        ),
                      ),
                      Text(
                        _totalOrders.toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
          ),
          // Legend
          if (_paymentMethodsData.isNotEmpty)
            Column(
              children: _paymentMethodsData.map((e) {
                final index = _paymentMethodsData.indexOf(e);
                final color = [
                  Colors.blue,
                  Colors.purple,
                  Colors.orange,
                  Colors.green,
                ][index % 4];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        e['payment_method_name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return Column(
            children: [
              _buildOrderChannelsChart(),
              const SizedBox(height: 24),
              _buildCustomerSentiment(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 1, child: _buildOrderChannelsChart()),
            const SizedBox(width: 24),
            Expanded(flex: 2, child: _buildCustomerSentiment()),
          ],
        );
      },
    );
  }

  Widget _buildOrderChannelsChart() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Channels',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "See where orders come from.",
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _orderMethodsData.isEmpty
                ? const Center(child: Text("No Data"))
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 0,
                          centerSpaceRadius: 60,
                          sections: _orderMethodsData.map((e) {
                            final index = _orderMethodsData.indexOf(e);
                            final color = [
                              Colors.indigo,
                              Colors.teal,
                              Colors.amber,
                            ][index % 3];
                            final val = (e['total_orders'] as num).toDouble();
                            return PieChartSectionData(
                              color: color,
                              value: val,
                              title: '',
                              radius: 25,
                            );
                          }).toList(),
                        ),
                      ),
                      Text(
                        _totalOrders.toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
          ),
          if (_orderMethodsData.isNotEmpty)
            Column(
              children: _orderMethodsData.map((e) {
                final index = _orderMethodsData.indexOf(e);
                final color = [
                  Colors.indigo,
                  Colors.teal,
                  Colors.amber,
                ][index % 3];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        e['order_method_name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomerSentiment() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Sentiment',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Measure customer satisfaction based on reviews.",
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: _sentimentData.isEmpty
                  ? const Text(
                      'No data available for the selected period',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    )
                  : const Text('Sentiment Data Available'), // Placeholder
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderVolumeSection() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Volume',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Monitor the number of orders received over time.",
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _orderCountData.isEmpty
                ? const Center(child: Text("No Data"))
                : BarChart(
                    BarChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: const Color(0xFFE2E8F0),
                          strokeWidth: 1,
                          dashArray: [5, 5],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) => Text(
                              '${value.toInt()}',
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: _orderCountData.asMap().entries.map((e) {
                        return BarChartGroupData(
                          x: e.key,
                          barRods: [
                            BarChartRodData(
                              toY: (e.value['order_count'] as num).toDouble(),
                              color: Colors.blueAccent,
                              width: 16,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
