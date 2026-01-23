import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:exanor/services/crashlytics_service.dart';
import 'package:exanor/components/translation_widget.dart';

/// Debug helper widget for testing Firebase Crashlytics functionality
/// Only shown in debug mode
class CrashlyticsDebugHelper extends StatefulWidget {
  const CrashlyticsDebugHelper({super.key});

  @override
  State<CrashlyticsDebugHelper> createState() => _CrashlyticsDebugHelperState();
}

class _CrashlyticsDebugHelperState extends State<CrashlyticsDebugHelper> {
  final CrashlyticsService _crashlytics = CrashlyticsService.instance;

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
            ? Colors.red.shade900.withOpacity(0.1)
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const TranslatedText(
                'Crashlytics Debug Helper',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const TranslatedText(
            'Debug mode only - Test crash reporting functionality',
            style: TextStyle(fontSize: 12, color: Colors.red),
          ),
          const SizedBox(height: 16),

          // Test buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTestButton(
                context,
                'Test Crash',
                Icons.warning,
                Colors.red,
                () {
                  _crashlytics.forceCrash();
                },
              ),
              _buildTestButton(
                context,
                'Test Error',
                Icons.error,
                Colors.orange,
                () {
                  _crashlytics.recordError(
                    Exception('Test error from debug helper'),
                    StackTrace.current,
                    reason: 'Testing error reporting',
                    fatal: false,
                  );
                  _showSnackBar(context, 'Test error recorded');
                },
              ),
              _buildTestButton(
                context,
                'Test Log',
                Icons.info,
                Colors.blue,
                () {
                  _crashlytics.log('Test log message from debug helper');
                  _showSnackBar(context, 'Test log recorded');
                },
              ),
              _buildTestButton(
                context,
                'Set Test Key',
                Icons.key,
                Colors.green,
                () {
                  _crashlytics.setCustomKey(
                    'test_key',
                    'test_value_${DateTime.now().millisecondsSinceEpoch}',
                  );
                  _showSnackBar(context, 'Test custom key set');
                },
              ),
              _buildTestButton(
                context,
                'Test User ID',
                Icons.person,
                Colors.purple,
                () {
                  _crashlytics.setUserIdentifier(
                    'debug_user_${DateTime.now().millisecondsSinceEpoch}',
                  );
                  _showSnackBar(context, 'Test user ID set');
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
        backgroundColor: Colors.green,
      ),
    );
  }
}

/// A floating debug button that can be added to any screen for quick access
class FloatingCrashlyticsDebugButton extends StatelessWidget {
  const FloatingCrashlyticsDebugButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Only show in debug mode
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 100,
      right: 16,
      child: FloatingActionButton.small(
        heroTag: 'crashlytics_debug',
        backgroundColor: Colors.red.withOpacity(0.8),
        onPressed: () {
          _showDebugBottomSheet(context);
        },
        child: const Icon(Icons.bug_report, color: Colors.white, size: 20),
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
              const CrashlyticsDebugHelper(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
