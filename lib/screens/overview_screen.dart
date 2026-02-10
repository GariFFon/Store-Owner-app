import 'package:exanor/services/store_analytics_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:math' as math;

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

  // Custom Date Range
  DateTime _customStartDate = DateTime.now();
  DateTime _customEndDate = DateTime.now();

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
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31);
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
        // Do not update main start/end dates yet, wait for Apply button
        break;
    }
  }

  Future<void> _selectCustomDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _customStartDate : _customEndDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
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
        if (isStart) {
          _customStartDate = picked;
        } else {
          _customEndDate = picked;
        }
      });
    }
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);

    final dateFormat = DateFormat('yyyy-MM-dd');
    final startDateStr = dateFormat.format(_startDate);
    final endDateStr = dateFormat.format(_endDate);
    final yearStr = DateFormat('yyyy').format(_startDate);

    try {
      final results = await Future.wait([
        StoreAnalyticsService.getRevenueAnalytics(
          storeId: widget.storeId,
          startDate:
              (_selectedFilter == 'Yearly' || _selectedFilter == 'Monthly')
              ? ''
              : startDateStr,
          endDate: (_selectedFilter == 'Yearly' || _selectedFilter == 'Monthly')
              ? ''
              : endDateStr,
          type: (_selectedFilter == 'Yearly' || _selectedFilter == 'Monthly')
              ? _selectedFilter.toLowerCase()
              : 'custom',
          year: yearStr,
          month: (_selectedFilter == 'Yearly' || _selectedFilter == 'Monthly')
              ? DateFormat('MMMM').format(DateTime.now()).toLowerCase()
              : null,
        ),
        StoreAnalyticsService.getOrderCountAnalytics(
          storeId: widget.storeId,
          startDate:
              (_selectedFilter == 'Yearly' || _selectedFilter == 'Monthly')
              ? ''
              : startDateStr,
          endDate: (_selectedFilter == 'Yearly' || _selectedFilter == 'Monthly')
              ? ''
              : endDateStr,
          type: (_selectedFilter == 'Yearly' || _selectedFilter == 'Monthly')
              ? _selectedFilter.toLowerCase()
              : 'custom',
          year: yearStr,
          month: (_selectedFilter == 'Yearly' || _selectedFilter == 'Monthly')
              ? DateFormat('MMMM').format(DateTime.now()).toLowerCase()
              : null,
        ),
        StoreAnalyticsService.getPaymentMethodAnalytics(
          storeId: widget.storeId,
          startDate: _selectedFilter == 'Weekly' ? '' : startDateStr,
          endDate: _selectedFilter == 'Weekly' ? '' : endDateStr,
          type: _selectedFilter == 'Weekly' ? 'weekly' : 'custom',
          year: yearStr,
          month: _selectedFilter == 'Weekly'
              ? DateTime.now().month.toString()
              : null,
          week: _selectedFilter == 'Weekly'
              ? ((DateTime.now().day - 1) ~/ 7 + 1)
              : null,
          day: _selectedFilter == 'Weekly' ? DateTime.now().day : null,
        ),
        StoreAnalyticsService.getOrderMethodAnalytics(
          storeId: widget.storeId,
          startDate: _selectedFilter == 'Weekly' ? '' : startDateStr,
          endDate: _selectedFilter == 'Weekly' ? '' : endDateStr,
          type: _selectedFilter == 'Weekly' ? 'weekly' : 'custom',
          year: yearStr,
          month: _selectedFilter == 'Weekly'
              ? DateTime.now().month.toString()
              : null,
          week: _selectedFilter == 'Weekly'
              ? ((DateTime.now().day - 1) ~/ 7 + 1)
              : null,
          day: _selectedFilter == 'Weekly' ? DateTime.now().day : null,
        ),
        StoreAnalyticsService.getSentimentAnalytics(
          storeId: widget.storeId,
          startDate:
              (_selectedFilter == 'Yearly' || _selectedFilter == 'Monthly')
              ? ''
              : startDateStr,
          endDate: (_selectedFilter == 'Yearly' || _selectedFilter == 'Monthly')
              ? ''
              : endDateStr,
          type: (_selectedFilter == 'Yearly' || _selectedFilter == 'Monthly')
              ? _selectedFilter.toLowerCase()
              : 'custom',
          year: yearStr,
          month: (_selectedFilter == 'Yearly' || _selectedFilter == 'Monthly')
              ? DateFormat('MMMM').format(DateTime.now()).toLowerCase()
              : null,
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
          if (_selectedFilter == 'Weekly') {
            final now = DateTime.now();
            // Start of week (Sunday)
            final startOfWeek = DateTime(
              now.year,
              now.month,
              now.day,
            ).subtract(Duration(days: now.weekday % 7));
            final endOfWeek = startOfWeek.add(
              const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
            );

            _totalRevenue = _revenueData.fold(0.0, (sum, item) {
              if (item['date'] == null) return sum;
              try {
                final date = DateTime.parse(item['date']);
                if (date.isAfter(
                      startOfWeek.subtract(const Duration(seconds: 1)),
                    ) &&
                    date.isBefore(endOfWeek.add(const Duration(seconds: 1)))) {
                  return sum + ((item['revenue'] ?? 0.0) as num).toDouble();
                }
              } catch (e) {
                // Ignore parsing errors
              }
              return sum;
            });

            _totalOrders = _orderCountData.fold(0, (sum, item) {
              if (item['date'] == null) return sum;
              try {
                final date = DateTime.parse(item['date']);
                if (date.isAfter(
                      startOfWeek.subtract(const Duration(seconds: 1)),
                    ) &&
                    date.isBefore(endOfWeek.add(const Duration(seconds: 1)))) {
                  return sum + ((item['order_count'] ?? 0) as int);
                }
              } catch (e) {
                // Ignore parsing errors
              }
              return sum;
            });
          } else {
            _totalRevenue = _revenueData.fold(
              0.0,
              (sum, item) => sum + ((item['revenue'] ?? 0.0) as num).toDouble(),
            );
            _totalOrders = _orderCountData.fold(
              0,
              (sum, item) => sum + ((item['order_count'] ?? 0) as int),
            );
          }

          // Mock growth
          _revenueGrowth = -90.1;
          _ordersGrowth = -92.6;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedFilter == 'Custom') ...[
                      _buildCustomDateSelector(),
                      const SizedBox(height: 24),
                    ],
                    _buildSummaryCards(),
                    const SizedBox(height: 24),
                    _buildMiddleSection(),
                    const SizedBox(height: 24),
                    _buildBottomSection(),
                    const SizedBox(height: 24),
                    _buildChartCard(
                      title: "Order Volume",
                      subtitle:
                          "Monitor order frequency over time. High volume indicates strong engagement.",
                      child: _buildOrderVolumeChartBody(),
                    ),
                    const SizedBox(height: 48),
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
                  Icons.storefront_rounded,
                  size: 180,
                  color: watermarkColor.withOpacity(0.8),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
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
                        Expanded(child: _buildHeaderContent()),
                        const SizedBox(width: 16),
                        _buildFilterDropdown(),
                      ],
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

  Widget _buildHeaderContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, ${widget.ownerName}',
          style: const TextStyle(
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            DateFormat(
              'EEEE, MMM d, yyyy',
            ).format(DateTime.now()).toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2563EB),
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedFilter,
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB)),
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
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
                if (value != 'Custom') {
                  _updateDateRange();
                  _fetchAllData();
                } else {
                  _customStartDate = DateTime.now();
                  _customEndDate = DateTime.now();
                }
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildCustomDateSelector() {
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
          _buildSectionHeader('Custom Date Range'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildDateField('Start', _customStartDate, true)),
              const SizedBox(width: 16),
              Expanded(child: _buildDateField('End', _customEndDate, false)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _startDate = _customStartDate;
                  _endDate = _customEndDate;
                });
                _fetchAllData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apply Filter',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, DateTime date, bool isStart) {
    return InkWell(
      onTap: () => _selectCustomDate(context, isStart),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: Colors.blue[700],
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM dd, yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    String revenueTitle;
    String ordersTitle;

    switch (_selectedFilter) {
      case 'Weekly':
        revenueTitle = "This Week";
        ordersTitle = "Orders";
        break;
      case 'Monthly':
        revenueTitle = "${DateFormat('MMM').format(_startDate)} Rev";
        ordersTitle = "Orders";
        break;
      case 'Yearly':
        revenueTitle = "${DateFormat('yyyy').format(_startDate)} Rev";
        ordersTitle = "Orders";
        break;
      case 'Custom':
        revenueTitle = "Revenue";
        ordersTitle = "Orders";
        break;
      case 'Daily':
      default:
        revenueTitle = "Today";
        ordersTitle = "Today";
        break;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        if (isMobile) {
          return Column(
            children: [
              _buildStatCard(
                revenueTitle,
                NumberFormat.currency(symbol: '₹').format(_totalRevenue),
                Icons.attach_money_rounded,
                Colors.blue,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                ordersTitle,
                _totalOrders.toString(),
                Icons.shopping_bag_rounded,
                Colors.orange,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                revenueTitle,
                NumberFormat.currency(symbol: '₹').format(_totalRevenue),
                Icons.attach_money_rounded,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                ordersTitle,
                _totalOrders.toString(),
                Icons.shopping_bag_rounded,
                Colors.orange,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                _isLoading
                    ? Shimmer.fromColors(
                        baseColor: Colors.grey.shade300,
                        highlightColor: Colors.grey.shade100,
                        child: Container(
                          height: 24,
                          width: 80,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        value,
                        style: TextStyle(
                          fontSize: 24,
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

  Widget _buildMiddleSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              _buildChartCard(
                title: "Revenue Trends",
                subtitle: "Track total earnings over time.",
                child: _buildRevenueChartBody(),
              ),
              const SizedBox(height: 24),
              _buildChartCard(
                title: "Payment Methods",
                subtitle: "How customers prefer to pay.",
                child: _buildPaymentMethodsChartBody(),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildChartCard(
                title: "Revenue Trends",
                subtitle: "Track total earnings over time.",
                child: _buildRevenueChartBody(),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 1,
              child: _buildChartCard(
                title: "Payment Methods",
                subtitle: "Customer payment preferences.",
                child: _buildPaymentMethodsChartBody(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            children: [
              _buildChartCard(
                title: "Order Channels",
                subtitle: "Online vs Instore vs Mobile.",
                child: _buildOrderChannelsChartBody(),
              ),
              const SizedBox(height: 24),
              _buildChartCard(
                title: "Customer Sentiment",
                subtitle: "Satisfaction scores (out of 5).",
                child: _buildCustomerSentimentBody(),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: _buildChartCard(
                title: "Order Channels",
                subtitle: "Source of your orders.",
                child: _buildOrderChannelsChartBody(),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 2,
              child: _buildChartCard(
                title: "Customer Sentiment",
                subtitle: "Customer satisfaction feedback.",
                child: _buildCustomerSentimentBody(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[400],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF64748B),
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  // --- Chart Bodies ---

  Widget _buildRevenueChartBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_revenueData.isEmpty) return const Center(child: Text("No Data"));

    return BarChart(
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
              reservedSize: 45,
              getTitlesWidget: (value, meta) => Text(
                '₹${value.toInt()}',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                // Simplified title logic for innovation display
                int index = value.toInt();
                if (_selectedFilter == 'Weekly') {
                  if (index % 5 == 0 && index < 53)
                    return _chartLabel('W${index + 1}');
                } else if (_selectedFilter == 'Yearly') {
                  if (index >= 0 && index < _revenueData.length) {
                    return _chartLabel(
                      (_revenueData[index]['year'] ?? '').toString(),
                    );
                  }
                } else {
                  if (index >= 0 && index < 12)
                    return _chartLabel(_getMonthName(index));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _generateRevenueBarGroups(),
      ),
    );
  }

  Widget _chartLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPaymentMethodsChartBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_paymentMethodsData.isEmpty)
      return const Center(child: Text("No Data"));

    return Stack(
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 4,
            centerSpaceRadius: 50,
            sections: _paymentMethodsData.map((e) {
              final name = e['payment_method_name'] ?? '';
              final color = name.toLowerCase().contains('delivery')
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF8B5CF6);
              final val = (e['total_orders'] as num).toDouble();
              return PieChartSectionData(
                color: color,
                value: val,
                title: '${val.toInt()}',
                radius: 40,
                titleStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }).toList(),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: _paymentMethodsData.map((e) {
              final name = e['payment_method_name'] ?? '';
              final color = name.toLowerCase().contains('delivery')
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF8B5CF6);
              return _legendItem(name, color);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderChannelsChartBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_orderMethodsData.isEmpty) return const Center(child: Text("No Data"));

    return Stack(
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 4,
            centerSpaceRadius: 50,
            sections: _orderMethodsData.map((e) {
              final name = e['order_method_name'] ?? '';
              final color = name.toLowerCase().contains('dine')
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B);
              final val = (e['total_orders'] as num).toDouble();
              return PieChartSectionData(
                color: color,
                value: val,
                title: '${val.toInt()}',
                radius: 40,
                titleStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }).toList(),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: _orderMethodsData.map((e) {
              final name = e['order_method_name'] ?? '';
              final color = name.toLowerCase().contains('dine')
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B);
              return _legendItem(name, color);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _legendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerSentimentBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_sentimentData.isEmpty) return const Center(child: Text("No Data"));

    return BarChart(
      BarChartData(
        maxY: 5,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (val, _) => Text(
                '${val.toInt()}',
                style: TextStyle(color: Colors.grey[400], fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                int index = val.toInt();
                if (_selectedFilter == 'Weekly') {
                  if (index % 5 == 0 && index < 53)
                    return _chartLabel('W${index + 1}');
                } else if (_selectedFilter == 'Yearly') {
                  if (index >= 0 && index < _sentimentData.length) {
                    return _chartLabel(
                      (_sentimentData[index]['year'] ?? '').toString(),
                    );
                  }
                } else {
                  if (index >= 0 && index < 12)
                    return _chartLabel(_getMonthName(index));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _selectedFilter == 'Monthly'
            ? List.generate(12, (index) {
                double val = 0;
                // Find matching month in _sentimentData

                // Map short name 'jan', 'feb' to full names if needed, or rely on API using full names
                // The API sample shows 'january', 'february'.
                // Need a helper to match short names or just convert index to full name.
                // Or loop and find.
                final fullMonthName = DateFormat(
                  'MMMM',
                ).format(DateTime(2022, index + 1, 1)).toLowerCase();

                final item = _sentimentData.firstWhere(
                  (element) =>
                      (element['month'] ?? '').toString().toLowerCase() ==
                      fullMonthName,
                  orElse: () => {},
                );

                if (item.isNotEmpty && item['average_sentiment'] != null) {
                  val = (item['average_sentiment'] as num).toDouble();
                }

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: val,
                      color: const Color(0xFFEC4899), // Pink
                      width: 16,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              })
            : List.generate(_sentimentData.length, (index) {
                double val = 0;
                var item = _sentimentData[index];
                if (item['average_sentiment'] != null) {
                  val = (item['average_sentiment'] as num).toDouble();
                }
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: val,
                      color: const Color(0xFFEC4899), // Pink
                      width: 16,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
      ),
    );
  }

  Widget _buildOrderVolumeChartBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_orderCountData.isEmpty) return const Center(child: Text("No Data"));

    return BarChart(
      BarChartData(
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (val, _) => Text(
                '${val.toInt()}',
                style: TextStyle(color: Colors.grey[400], fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (_selectedFilter == 'Weekly') {
                  if (index % 5 == 0 && index < 53)
                    return _chartLabel('W${index + 1}');
                } else if (_selectedFilter == 'Yearly') {
                  if (index >= 0 && index < _orderCountData.length) {
                    return _chartLabel(
                      (_orderCountData[index]['year'] ?? '').toString(),
                    );
                  }
                } else {
                  if (index >= 0 && index < 12)
                    return _chartLabel(_getMonthName(index));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _generateOrderVolumeBarGroups(),
      ),
    );
  }

  String _getMonthName(int monthIndex) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (monthIndex >= 0 && monthIndex < 12) return months[monthIndex];
    return '';
  }

  List<BarChartGroupData> _generateRevenueBarGroups() {
    // Re-using simplified logic for brevity, assuming _revenueData is populated
    if (_selectedFilter == 'Weekly') {
      List<double> weeklyRevenue = List.filled(53, 0.0);
      for (var item in _revenueData) {
        // ... parsing logic ...
        if (item['date'] != null) {
          try {
            DateTime d = DateTime.parse(item['date']);
            int week =
                ((int.parse(DateFormat("D").format(d)) - d.weekday + 10) / 7)
                    .floor();
            if (week >= 1 && week <= 53)
              weeklyRevenue[week - 1] += (item['revenue'] as num).toDouble();
          } catch (e) {}
        }
      }
      return List.generate(
        53,
        (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: weeklyRevenue[i],
              color: const Color(0xFF3B82F6),
              width: 8,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    } else if (_selectedFilter == 'Yearly') {
      return List.generate(_revenueData.length, (i) {
        final item = _revenueData[i];
        double val = 0;
        if (item['revenue'] != null) {
          val = (item['revenue'] as num).toDouble();
        }
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: const Color(0xFF3B82F6),
              width: 32,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      });
    } else if (_selectedFilter == 'Monthly') {
      List<double> monthlyRevenue = List.filled(12, 0.0);
      for (var item in _revenueData) {
        if (item['month'] != null) {
          String mName = item['month'].toString().toLowerCase();
          for (int i = 0; i < 12; i++) {
            if (DateFormat(
                  'MMMM',
                ).format(DateTime(2022, i + 1, 1)).toLowerCase() ==
                mName) {
              monthlyRevenue[i] = (item['revenue'] as num).toDouble();
              break;
            }
          }
        }
      }
      return List.generate(
        12,
        (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: monthlyRevenue[i],
              color: const Color(0xFF3B82F6),
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    } else {
      List<double> monthlyRevenue = List.filled(12, 0.0);
      for (var item in _revenueData) {
        if (item['date'] != null) {
          try {
            DateTime d = DateTime.parse(item['date']);
            if (d.month >= 1 && d.month <= 12)
              monthlyRevenue[d.month - 1] += (item['revenue'] as num)
                  .toDouble();
          } catch (e) {}
        }
      }
      return List.generate(
        12,
        (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: monthlyRevenue[i],
              color: const Color(0xFF3B82F6),
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }
  }

  List<BarChartGroupData> _generateOrderVolumeBarGroups() {
    if (_selectedFilter == 'Weekly') {
      List<double> weekly = List.filled(53, 0.0);
      for (var item in _orderCountData) {
        if (item['date'] != null) {
          try {
            DateTime d = DateTime.parse(item['date']);
            int week =
                ((int.parse(DateFormat("D").format(d)) - d.weekday + 10) / 7)
                    .floor();
            if (week >= 1 && week <= 53)
              weekly[week - 1] += (item['order_count'] as num).toDouble();
          } catch (e) {}
        }
      }
      return List.generate(
        53,
        (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: weekly[i],
              color: const Color(0xFFF97316),
              width: 8,
              borderRadius: BorderRadius.circular(2),
            ),
          ],
        ),
      );
    } else if (_selectedFilter == 'Yearly') {
      return List.generate(_orderCountData.length, (i) {
        final item = _orderCountData[i];
        double val = 0;
        if (item['order_count'] != null) {
          val = (item['order_count'] as num).toDouble();
        }
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: val,
              color: const Color(0xFFF97316),
              width: 32, // Wider for single year
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        );
      });
    } else if (_selectedFilter == 'Monthly') {
      List<double> monthly = List.filled(12, 0.0);
      for (var item in _orderCountData) {
        if (item['month'] != null) {
          String mName = item['month'].toString().toLowerCase();
          for (int i = 0; i < 12; i++) {
            if (DateFormat(
                  'MMMM',
                ).format(DateTime(2022, i + 1, 1)).toLowerCase() ==
                mName) {
              monthly[i] = (item['order_count'] as num).toDouble();
              break;
            }
          }
        }
      }
      return List.generate(
        12,
        (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: monthly[i],
              color: const Color(0xFFF97316),
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    } else {
      List<double> monthly = List.filled(12, 0.0);
      for (var item in _orderCountData) {
        if (item['date'] != null) {
          try {
            DateTime d = DateTime.parse(item['date']);
            if (d.month >= 1 && d.month <= 12)
              monthly[d.month - 1] += (item['order_count'] as num).toDouble();
          } catch (e) {}
        }
      }
      return List.generate(
        12,
        (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: monthly[i],
              color: const Color(0xFFF97316),
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }
  }
}
