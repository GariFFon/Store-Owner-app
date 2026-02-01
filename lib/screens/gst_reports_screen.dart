import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:exanor/components/translation_widget.dart';

class GstReportsScreen extends StatefulWidget {
  final String storeId;

  const GstReportsScreen({super.key, required this.storeId});

  @override
  State<GstReportsScreen> createState() => _GstReportsScreenState();
}

class _GstReportsScreenState extends State<GstReportsScreen> {
  // State
  String _selectedReportType = 'GSTR1';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;

  // Report Types Mapping
  final List<Map<String, String>> _reportTypes = [
    {
      'id': 'GSTR1',
      'title': 'GSTR-1',
      'description': 'Outward Supplies (Sales)',
    },
    {
      'id': 'GSTR2A',
      'title': 'GSTR-2A',
      'description': 'Inward Supplies (Purchases & ITC)',
    },
    {
      'id': 'GSTR2B',
      'title': 'GSTR-2B',
      'description': 'Inward Supplies (same as GSTR-2A)',
    },
    {
      'id': 'GSTR3B',
      'title': 'GSTR-3B',
      'description': 'Monthly Return & Tax Payment (Most Important)',
    },
    {'id': 'GSTR9', 'title': 'GSTR-9', 'description': 'Annual Return'},
    {
      'id': 'ITC',
      'title': 'ITC',
      'description': 'Input Tax Credit Detailed Report',
    },
    {
      'id': 'OUTPUT_TAX',
      'title': 'Output Tax',
      'description': 'Output Tax Liability Report',
    },
    {
      'id': 'HSN_SAC',
      'title': 'HSN/SAC',
      'description': 'HSN/SAC Summary Report',
    },
    {
      'id': 'GST_LEDGER',
      'title': 'GST Ledger',
      'description': 'GST Ledger Summary',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Determine screen size for responsive layout
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width > 800; // Arbitrary breakpoint for desktop/tablet
    final isMobile = width <= 600;

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background
      appBar: AppBar(
        title: const TranslatedText(
          'GST Reports',
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TranslatedText(
                    'GST Reports That Can Be Generated',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildReportCards(isDesktop, isMobile),
                  const SizedBox(height: 24),
                  _buildDateFilters(isDesktop),
                  const SizedBox(height: 32),
                  const TranslatedText(
                    'Export Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildExportOptions(),
                  const SizedBox(height: 48), // Bottom padding
                ],
              ),
            ),
    );
  }

  Widget _buildReportCards(bool isDesktop, bool isMobile) {
    int crossAxisCount = isDesktop ? 3 : (isMobile ? 1 : 2);
    double childAspectRatio = isDesktop ? 2.5 : 3.0;
    if (isMobile) childAspectRatio = 3.5;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: childAspectRatio,
        mainAxisExtent: 100, // Fixed height for consistency
      ),
      itemCount: _reportTypes.length,
      itemBuilder: (context, index) {
        final report = _reportTypes[index];
        final isSelected = report['id'] == _selectedReportType;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedReportType = report['id']!;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue[50] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey[200]!,
                width: isSelected ? 2 : 1,
              ),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TranslatedText(
                        report['title']!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.blue[800] : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TranslatedText(
                        report['description']!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.blue,
                    size: 24,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateFilters(bool isDesktop) {
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
          Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: isDesktop ? 1 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TranslatedText(
                      'Start Date',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectDate(context, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('MM/dd/yyyy').format(_startDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isDesktop) const SizedBox(width: 32),
              if (!isDesktop) const SizedBox(height: 16),
              Expanded(
                flex: isDesktop ? 1 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TranslatedText(
                      'End Date',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _selectDate(context, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('MM/dd/yyyy').format(_endDate),
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportOptions() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildExportButton(
          'Download PDF',
          Icons.picture_as_pdf,
          Colors.red,
          () => _handleGenerate('pdf'),
        ),
        _buildExportButton(
          'Download XLSX',
          Icons.table_chart,
          Colors.green,
          () => _handleGenerate('xlsx'),
        ),
        _buildExportButton(
          'Download CSV',
          Icons.description,
          Colors.blue,
          () => _handleGenerate('csv'),
        ),
        _buildExportButton(
          'Download JSON',
          Icons.code,
          Colors.purple,
          () => _handleGenerate('json'),
        ),
        _buildExportButton(
          'View Report',
          Icons.visibility,
          Colors.cyan,
          () => _handleGenerate(
            'view',
          ), // file_type doesn't strictly matter for 'view' if we parse response, but we'll ask for JSON for data
        ),
      ],
    );
  }

  Widget _buildExportButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 2,
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: TranslatedText(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _handleGenerate(String type) async {
    setState(() => _isLoading = true);

    try {
      // If valid is 'view', we request JSON structure mostly, or we assume backend sends data anyway
      // The sample payload uses 'file_type', so we pass it.
      // If 'view', we might still want 'json' file type or 'pdf', but standard practice if we want data is probably JSON.
      // However, the user provided sample response has BOTH 'report' (data) AND 'file' (url).
      // So regardless of file_type, we get the report data.
      // Let's pass 'pdf' as default for view unless we strictly want to download specific file.
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
            // Handle Download
            if (response['file'] != null &&
                response['file']['file_url'] != null) {
              final fileUrlData = response['file']['file_url'];
              // Sometimes file_url is a String, sometimes a Map depending on user sample:
              // "file_url": { "response": "http...", "boolean_status": true }
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
                    const SnackBar(
                      content: TranslatedText('Could not launch file URL'),
                    ),
                  );
                }
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: TranslatedText('No file generated')),
                );
              }
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: TranslatedText(
                'Failed to generate report: ${response['message'] ?? 'Unknown Error'}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: TranslatedText('Error: $e')));
      }
    }
  }

  void _showReportViewDialog(Map<String, dynamic> data) {
    // Extract report details
    final report = data['report'] ?? {};
    final reportName = report['report_name'] ?? 'GST Report';

    // Simple key-value display for potentially complex JSON
    // We will specifically look for common fields from the user sample

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reportName),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (report['period'] != null) ...[
                  Text(
                    'Period: ${report['period']['from']} to ${report['period']['to']}',
                  ),
                  Text('Financial Year: ${report['period']['financial_year']}'),
                  const Divider(),
                ],
                if (report['hsn_summary'] != null &&
                    report['hsn_summary']['totals'] != null) ...[
                  const Text(
                    'Summary (HSN/SAC):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _buildKeyValueRow(
                    'Total Taxable Value',
                    report['hsn_summary']['totals']['total_taxable_value'],
                  ),
                  _buildKeyValueRow(
                    'Total Tax',
                    report['hsn_summary']['totals']['total_tax'],
                  ),
                  const Divider(),
                ],
                if (report['b2cs'] != null &&
                    report['b2cs']['summary'] != null) ...[
                  const Text(
                    'B2C Small Summary:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  _buildKeyValueRow(
                    'Total Taxable Value',
                    report['b2cs']['summary']['total_taxable_value'],
                  ),
                  const Divider(),
                ],
                if (report['document_summary'] != null) ...[
                  _buildKeyValueRow(
                    'Total Invoices',
                    report['document_summary']['total_invoices'],
                  ),
                  _buildKeyValueRow(
                    'Cancelled',
                    report['document_summary']['total_cancelled'],
                  ),
                  const Divider(),
                ],
                // Fallback: Dump keys if we don't recognize structure
                const SizedBox(height: 10),
                const Text(
                  'Raw Data Preview:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[100],
                  child: Text(
                    data.toString().length > 500
                        ? '${data.toString().substring(0, 500)}...'
                        : data.toString(),
                    style: const TextStyle(fontFamily: 'Courier', fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const TranslatedText('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyValueRow(String key, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(color: Colors.grey)),
          Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
