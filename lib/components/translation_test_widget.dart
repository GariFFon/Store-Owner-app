import 'package:flutter/material.dart';
import 'package:exanor/services/translation_service.dart';

class TranslationTestWidget extends StatefulWidget {
  const TranslationTestWidget({super.key});

  @override
  State<TranslationTestWidget> createState() => _TranslationTestWidgetState();
}

class _TranslationTestWidgetState extends State<TranslationTestWidget> {
  final TranslationService _translationService = TranslationService.instance;
  bool _isDownloading = false;
  bool _isTesting = false;
  String _status = 'Ready to test';
  String _testResult = '';

  Future<void> _testHindiDownload() async {
    setState(() {
      _isDownloading = true;
      _status = 'Testing Hindi model download...';
      _testResult = '';
    });

    try {
      // First check if already downloaded
      final alreadyDownloaded = await _translationService
          .isLanguageModelDownloaded('hi');

      if (alreadyDownloaded) {
        setState(() {
          _status = '✅ Hindi model already available';
          _isDownloading = false;
        });
        return;
      }

      // Try to download
      final success = await _translationService.downloadLanguageModel('hi');

      setState(() {
        _isDownloading = false;
        if (success) {
          _status = '✅ Hindi model downloaded successfully!';
        } else {
          _status = '❌ Failed to download Hindi model';
        }
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _status = '❌ Error: $e';
      });
    }
  }

  Future<void> _testTranslation() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Testing translation...';
    });

    try {
      // Test English to Hindi translation
      const testText = 'Hello, how are you?';
      final translated = await _translationService.translateText(
        testText,
        'en',
        'hi',
      );

      setState(() {
        _isTesting = false;
        if (translated != testText && translated.isNotEmpty) {
          _testResult =
              '✅ Translation successful:\n"$testText"\n→\n"$translated"';
        } else {
          _testResult = '⚠️ Translation returned same text or empty result';
        }
      });
    } catch (e) {
      setState(() {
        _isTesting = false;
        _testResult = '❌ Translation failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Translation Test'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.translate,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Translation Test',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Test Hindi model download and translation functionality',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Download Test
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step 1: Download Hindi Model',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_status, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isDownloading ? null : _testHindiDownload,
                      child: _isDownloading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Downloading...'),
                              ],
                            )
                          : const Text('Test Hindi Download'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Translation Test
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step 2: Test Translation',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_testResult.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(
                          0.5,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _testResult,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isTesting ? null : _testTranslation,
                      child: _isTesting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Testing...'),
                              ],
                            )
                          : const Text('Test Translation'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Troubleshooting Tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Troubleshooting Tips',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '• Ensure you have internet connection\n'
                    '• Check that Google Play Services is updated\n'
                    '• Make sure you have enough storage space\n'
                    '• Try restarting the app if downloads fail\n'
                    '• On some devices, it may take a few attempts',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.orange[700],
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
}

/// Show translation test screen
Future<void> showTranslationTest(BuildContext context) async {
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (context) => const TranslationTestWidget()),
  );
}
