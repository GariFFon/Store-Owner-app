import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:exanor/services/performance_service.dart';
import 'package:exanor/components/translation_widget.dart';

/// Debug helper widget for testing Firebase Performance functionality
/// Only shown in debug mode
class PerformanceDebugHelper extends StatefulWidget {
  const PerformanceDebugHelper({super.key});

  @override
  State<PerformanceDebugHelper> createState() => _PerformanceDebugHelperState();
}

class _PerformanceDebugHelperState extends State<PerformanceDebugHelper> {
  final PerformanceService _performance = PerformanceService.instance;
  Map<String, dynamic> _performanceSummary = {};
  bool _isCollectionEnabled = false;

  @override
  void initState() {
    super.initState();
    _updateSummary();
  }

  Future<void> _updateSummary() async {
    final summary = _performance.getPerformanceSummary();
    final isEnabled = await _performance.isPerformanceCollectionEnabled;

    if (mounted) {
      setState(() {
        _performanceSummary = summary;
        _isCollectionEnabled = isEnabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.blue.shade900.withOpacity(0.1)
            : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const TranslatedText(
                'Performance Debug Helper',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const TranslatedText(
            'Debug mode only - Test performance monitoring functionality',
            style: TextStyle(fontSize: 12, color: Colors.blue),
          ),
          const SizedBox(height: 16),

          // Performance status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isCollectionEnabled ? Icons.check_circle : Icons.cancel,
                      color: _isCollectionEnabled ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Collection: ${_isCollectionEnabled ? "Enabled" : "Disabled"}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: _isCollectionEnabled ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Active Traces: ${_performanceSummary['trace_count'] ?? 0}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (_performanceSummary['active_traces'] != null &&
                    (_performanceSummary['active_traces'] as List).isNotEmpty)
                  Text(
                    'Traces: ${(_performanceSummary['active_traces'] as List).join(', ')}',
                    style: const TextStyle(fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Test buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTestButton(
                context,
                'Toggle Collection',
                Icons.toggle_on,
                Colors.purple,
                () async {
                  _performance.togglePerformanceCollection();
                  await _updateSummary();
                  _showSnackBar(context, 'Performance collection toggled');
                },
              ),
              _buildTestButton(
                context,
                'Test API Trace',
                Icons.api,
                Colors.green,
                () async {
                  await _performance.traceApiCall('test_endpoint', () async {
                    await Future.delayed(const Duration(milliseconds: 500));
                    return 'Test API response';
                  });
                  await _updateSummary();
                  _showSnackBar(context, 'API trace completed');
                },
              ),
              _buildTestButton(
                context,
                'Test Auth Trace',
                Icons.login,
                Colors.orange,
                () async {
                  await _performance.traceAuthentication(
                    'test_login',
                    () async {
                      await Future.delayed(const Duration(milliseconds: 300));
                      return true;
                    },
                  );
                  await _updateSummary();
                  _showSnackBar(context, 'Auth trace completed');
                },
              ),
              _buildTestButton(
                context,
                'Test Navigation',
                Icons.navigation,
                Colors.blue,
                () async {
                  await _performance.traceScreenNavigation(
                    'debug_screen',
                    'test_screen',
                  );
                  await _updateSummary();
                  _showSnackBar(context, 'Navigation trace completed');
                },
              ),
              _buildTestButton(
                context,
                'Test Image Load',
                Icons.image,
                Colors.teal,
                () async {
                  await _performance.traceImageLoad(
                    'https://example.com/test.jpg',
                    () async {
                      await Future.delayed(const Duration(milliseconds: 400));
                      return 'Image loaded';
                    },
                  );
                  await _updateSummary();
                  _showSnackBar(context, 'Image load trace completed');
                },
              ),
              _buildTestButton(
                context,
                'Test Translation',
                Icons.translate,
                Colors.pink,
                () async {
                  await _performance.traceTranslation('en', 'hi', () async {
                    await Future.delayed(const Duration(milliseconds: 200));
                    return 'Translated text';
                  });
                  await _updateSummary();
                  _showSnackBar(context, 'Translation trace completed');
                },
              ),
              _buildTestButton(
                context,
                'Custom Trace',
                Icons.timeline,
                Colors.indigo,
                () async {
                  final trace = await _performance.startTrace(
                    'custom_debug_trace',
                  );
                  await Future.delayed(const Duration(milliseconds: 600));
                  await _performance.addTraceAttribute(
                    'custom_debug_trace',
                    'test_attribute',
                    'test_value',
                  );
                  await _performance.setTraceMetric(
                    'custom_debug_trace',
                    'test_metric',
                    42,
                  );
                  await _performance.stopTrace('custom_debug_trace');
                  await _updateSummary();
                  _showSnackBar(context, 'Custom trace completed');
                },
              ),
              _buildTestButton(
                context,
                'Refresh Status',
                Icons.refresh,
                Colors.grey,
                () async {
                  await _updateSummary();
                  _showSnackBar(context, 'Status refreshed');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

/// A floating debug button that can be added to any screen for quick access
class FloatingPerformanceDebugButton extends StatelessWidget {
  const FloatingPerformanceDebugButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 150,
      right: 16,
      child: FloatingActionButton.small(
        heroTag: 'performance_debug',
        backgroundColor: Colors.blue.withOpacity(0.8),
        onPressed: () {
          _showDebugBottomSheet(context);
        },
        child: const Icon(Icons.speed, color: Colors.white, size: 20),
      ),
    );
  }

  void _showDebugBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const PerformanceDebugHelper(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Combined debug helper that includes both Crashlytics and Performance tools
class FirebaseDebugHelper extends StatelessWidget {
  const FirebaseDebugHelper({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        PerformanceDebugHelper(),
        const SizedBox(height: 16),
        // You can add CrashlyticsDebugHelper here if you want both together
      ],
    );
  }
}
