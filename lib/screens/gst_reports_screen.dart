import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:exanor/components/translation_widget.dart';
import 'dart:math' as math;

class GstReportsScreen extends StatefulWidget {
  final String storeId;

  const GstReportsScreen({super.key, required this.storeId});

  @override
  State<GstReportsScreen> createState() => _GstReportsScreenState();
}

class _GstReportsScreenState extends State<GstReportsScreen> {
  String _selectedReportType = 'GSTR1';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;

  final List<Map<String, String>> _reportTypes = [
    {
      'id': 'GSTR1',
      'title': 'GSTR-1',
      'description': 'Outward Supplies',
      'icon': 'outbox',
      'color': '2196F3', // Blue
    },
    {
      'id': 'GSTR2A',
      'title': 'GSTR-2A',
      'description': 'Inward Supplies',
      'icon': 'move_to_inbox',
      'color': '4CAF50', // Green
    },
    {
      'id': 'GSTR2B',
      'title': 'GSTR-2B',
      'description': 'Auto drafted ITC',
      'icon': 'description',
      'color': '009688', // Teal
    },
    {
      'id': 'GSTR3B',
      'title': 'GSTR-3B',
      'description': 'Monthly Return',
      'icon': 'summarize',
      'color': 'FF9800', // Orange
    },
    {
      'id': 'GSTR9',
      'title': 'GSTR-9',
      'description': 'Annual Return',
      'icon': 'event_repeat',
      'color': '9C27B0', // Purple
    },
    {
      'id': 'ITC',
      'title': 'ITC Register',
      'description': 'Input Tax Credit',
      'icon': 'account_balance_wallet',
      'color': '673AB7', // Deep Purple
    },
    {
      'id': 'OUTPUT_TAX',
      'title': 'Output Tax',
      'description': 'Liability Report',
      'icon': 'monetization_on',
      'color': 'F44336', // Red
    },
    {
      'id': 'HSN_SAC',
      'title': 'HSN/SAC',
      'description': 'Summary Report',
      'icon': 'grid_on',
      'color': '607D8B', // Blue Grey
    },
    {
      'id': 'GST_LEDGER',
      'title': 'GST Ledger',
      'description': 'Ledger Summary',
      'icon': 'book',
      'color': '795548', // Brown
    },
  ];

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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.all(20),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader('Select Report Type'),
                                const SizedBox(height: 16),
                                _buildReportGrid(),
                                const SizedBox(height: 32),
                                _buildDateFilters(),
                                const SizedBox(height: 32),
                                _buildExportSection(),
                                const SizedBox(height: 48),
                              ],
                            ),
                          ),
                        ),
                      ],
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
                  Icons.assessment_rounded,
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GST Reports',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
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
                                'TAX FILING & COMPLIANCE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2563EB),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildReportGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final crossAxisCount = isDesktop
            ? 4
            : 2; // 4 columns on desktop, 2 on mobile
        // Desktop: taller/squarish (1.0). Mobile: slightly horizontal (1.5) to fit text
        final aspectRatio = isDesktop ? 1.1 : 1.5;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12, // Reduced spacing
            mainAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemCount: _reportTypes.length,
          itemBuilder: (context, index) {
            final report = _reportTypes[index];
            final isSelected = report['id'] == _selectedReportType;
            final colorInt = int.parse(report['color']!, radix: 16);
            final color = Color(0xFF000000 | colorInt);

            return InkWell(
              onTap: () => setState(() => _selectedReportType = report['id']!),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: color.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getIconData(report['icon']!),
                            color: color,
                            size: 18,
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: color,
                            size: 18,
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report['title']!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          report['description']!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

  Widget _buildDateFilters() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Report Period'),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              if (isWide) {
                return Row(
                  children: [
                    Expanded(
                      child: _buildDateField("Start Date", _startDate, true),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildDateField("End Date", _endDate, false),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _buildDateField("Start Date", _startDate, true),
                  const SizedBox(height: 16),
                  _buildDateField("End Date", _endDate, false),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(String label, DateTime date, bool isStart) {
    return InkWell(
      onTap: () => _selectDate(context, isStart),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: Colors.grey[500],
              size: 20,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                  ),
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(date),
                  style: const TextStyle(
                    fontSize: 15,
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

  Widget _buildExportSection() {
    return Center(
      child: Column(
        children: [
          _buildSectionHeader('Export Actions'),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildActionButton(
                'View',
                Icons.visibility_rounded,
                Colors.purple,
                () => _handleGenerate('view'),
                isPrimary: true,
              ),
              _buildActionButton(
                'PDF',
                Icons.picture_as_pdf_outlined,
                Colors.red,
                () => _handleGenerate('pdf'),
              ),
              _buildActionButton(
                'Excel',
                Icons.grid_on_outlined,
                Colors.green,
                () => _handleGenerate('xlsx'),
              ),
              _buildActionButton(
                'CSV',
                Icons.description_outlined,
                Colors.blue,
                () => _handleGenerate('csv'),
              ),
              _buildActionButton(
                'JSON',
                Icons.data_object_outlined,
                Colors.orange,
                () => _handleGenerate('json'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isPrimary = false,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? const Color(0xFF2563EB) : Colors.white,
        foregroundColor: isPrimary ? Colors.white : Colors.grey[800],
        elevation: isPrimary ? 4 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isPrimary
              ? BorderSide.none
              : BorderSide(color: Colors.grey[300]!),
        ),
        shadowColor: isPrimary
            ? const Color(0xFF2563EB).withOpacity(0.4)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: isPrimary ? Colors.white : color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isPrimary ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'outbox':
        return Icons.outbox_rounded;
      case 'move_to_inbox':
        return Icons.move_to_inbox_rounded;
      case 'description':
        return Icons.description_rounded;
      case 'summarize':
        return Icons.summarize_rounded;
      case 'event_repeat':
        return Icons.event_repeat_rounded;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_rounded;
      case 'monetization_on':
        return Icons.monetization_on_rounded;
      case 'grid_on':
        return Icons.grid_on_rounded;
      case 'book':
        return Icons.book_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  // --- Logic Methods ---

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
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
      if (mounted) {
        setState(() {
          if (isStart) {
            _startDate = picked;
          } else {
            _endDate = picked;
          }
        });
      }
    }
  }

  Future<void> _handleGenerate(String type) async {
    setState(() => _isLoading = true);
    try {
      final apiFileType = type == 'view' ? 'pdf' : type;
      final response = await StoreOwnerApiService.generateGstReport(
        storeId: widget.storeId,
        reportType: _selectedReportType,
        startDate: DateFormat('yyyy-MM-dd').format(_startDate),
        endDate: DateFormat('yyyy-MM-dd').format(_endDate),
        fileType: apiFileType,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (response.isNotEmpty && response['status'] == 200) {
          if (type == 'view') {
            _showReportViewDialog(response);
          } else {
            if (response['file'] != null &&
                response['file']['file_url'] != null) {
              final fileUrlData = response['file']['file_url'];
              String? url;
              if (fileUrlData is Map) {
                url = fileUrlData['response'];
              } else if (fileUrlData is String) {
                url = fileUrlData;
              }
              if (url != null && await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url));
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not launch file URL')),
                  );
                }
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No file generated')),
                );
              }
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed: ${response['message'] ?? 'Unknown Error'}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
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

  void _showReportViewDialog(Map<String, dynamic> data) {
    final report = data['report'] ?? {};
    final reportName = report['report_name'] ?? 'GST Report';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          reportName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report['period'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Period: ${report['period']['from']} to ${report['period']['to']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('FY: ${report['period']['financial_year']}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (report['hsn_summary'] != null &&
                    report['hsn_summary']['totals'] != null) ...[
                  const Text(
                    'Summary (HSN/SAC):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    'Total Taxable Value',
                    report['hsn_summary']['totals']['total_taxable_value'],
                  ),
                  _buildDetailRow(
                    'Total Tax',
                    report['hsn_summary']['totals']['total_tax'],
                  ),
                  const Divider(height: 24),
                ],
                // Add more sections as per previous logic...
                const SizedBox(height: 10),
                const Text(
                  'Raw Data Preview:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Text(
                    data.toString().length > 500
                        ? '${data.toString().substring(0, 500)}...'
                        : data.toString(),
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 11,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String key, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
