import 'package:flutter/material.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/enhanced_translation_service.dart';
import 'package:exanor/services/performance_service.dart';
import 'package:exanor/components/navigation_performance_tracker.dart';
import 'dart:developer' as developer;

/// Example screen that demonstrates complete Firebase Performance integration
class PerformanceIntegrationExampleScreen extends StatefulWidget {
  const PerformanceIntegrationExampleScreen({Key? key}) : super(key: key);

  @override
  State<PerformanceIntegrationExampleScreen> createState() =>
      _PerformanceIntegrationExampleScreenState();
}

class _PerformanceIntegrationExampleScreenState
    extends State<PerformanceIntegrationExampleScreen>
    with NavigationPerformanceMixin, TranslationMixin {
  final PerformanceService _performanceService = PerformanceService.instance;
  final EnhancedTranslationService _translationService =
      EnhancedTranslationService.instance;

  List<Map<String, dynamic>> _apiData = [];
  List<String> _translatedTexts = [];
  bool _isLoading = false;
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    // Example of screen initialization performance tracking
    await _performanceService.traceOperation(
      'example_screen_init',
      () async {
        setState(() {
          _status = 'Initializing...';
        });

        // Simulate some initialization work
        await Future.delayed(const Duration(milliseconds: 500));

        setState(() {
          _status = 'Ready';
        });
      },
      attributes: {
        'screen_name': 'PerformanceIntegrationExample',
        'category': 'screen_lifecycle',
      },
    );
  }

  /// Example of API call with performance tracking
  Future<void> _performApiCall() async {
    setState(() {
      _isLoading = true;
      _status = 'Making API call...';
    });

    try {
      // The API call will automatically be tracked due to the performance
      // integration in ApiService
      final response = await ApiService.get('/users', useBearerToken: false);

      // Process the response
      if (response['data'] != null && response['data'] is List) {
        final List<Map<String, dynamic>> userData =
            (response['data'] as List<dynamic>)
                .map((item) => item as Map<String, dynamic>)
                .toList();

        // Translate the API response using Enhanced Translation Service
        final translatedData = await _translationService
            .translateApiResponseList(userData);

        setState(() {
          _apiData = translatedData;
          _status = 'API call completed successfully';
        });
      } else {
        setState(() {
          _status = 'No data received from API';
        });
      }
    } catch (e) {
      developer.log('❌ API call failed: $e', name: 'ExampleScreen');
      setState(() {
        _status = 'API call failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Example of translation with performance tracking
  Future<void> _performTranslation() async {
    setState(() {
      _isLoading = true;
      _status = 'Translating text...';
    });

    try {
      final textsToTranslate = [
        'Welcome to our app',
        'Your profile has been updated',
        'Search for professionals',
        'Connect with businesses',
        'Explore new opportunities',
        'Rate your experience',
        'Share with friends',
        'Manage your settings',
      ];

      // Translate using the enhanced translation service
      // This will automatically track performance
      final translatedTexts = await _translationService.translateBatch(
        textsToTranslate,
      );

      setState(() {
        _translatedTexts = translatedTexts;
        _status = 'Translation completed successfully';
      });
    } catch (e) {
      developer.log('❌ Translation failed: $e', name: 'ExampleScreen');
      setState(() {
        _status = 'Translation failed: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Example of navigation with performance tracking
  Future<void> _performTrackedNavigation() async {
    // Track navigation performance
    await trackNavigation('PerformanceIntegrationExample', 'UserProfile');

    // Navigate to another screen
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NavigationPerformanceTracker(
            screenName: 'UserProfile',
            additionalAttributes: {
              'source': 'performance_example',
              'user_type': 'demo',
            },
            child: _DemoUserProfileScreen(),
          ),
        ),
      );
    }
  }

  /// Example of modal navigation with performance tracking
  Future<void> _showPerformanceTrackedModal() async {
    await NavigationPerformanceUtils.trackModalNavigation(
      'settings_modal',
      () => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Settings'),
          content: const Text('This is a performance-tracked modal'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  /// Example of bottom sheet with performance tracking
  Future<void> _showPerformanceTrackedBottomSheet() async {
    await NavigationPerformanceUtils.trackBottomSheetNavigation(
      'options_bottom_sheet',
      () => showModalBottomSheet<void>(
        context: context,
        builder: (context) => Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Options',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.help),
                title: const Text('Help'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavigationPerformanceTracker(
      screenName: 'PerformanceIntegrationExample',
      additionalAttributes: {
        'screen_type': 'example',
        'has_api_data': _apiData.isNotEmpty ? 'true' : 'false',
        'has_translations': _translatedTexts.isNotEmpty ? 'true' : 'false',
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Performance Integration Example'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (_isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          Icons.info,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _status,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // API Integration Section
              _buildSectionCard(
                title: 'API Integration',
                subtitle: 'Automatic HTTP performance tracking',
                icon: Icons.api,
                onTap: _performApiCall,
                children: [
                  if (_apiData.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'API Data (${_apiData.length} items):',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ...(_apiData
                        .take(3)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• ${item['name'] ?? 'Unknown'} (${item['email'] ?? 'No email'})',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        )),
                    if (_apiData.length > 3)
                      Text(
                        '... and ${_apiData.length - 3} more',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Translation Integration Section
              _buildSectionCard(
                title: 'Translation Integration',
                subtitle: 'Automatic translation performance tracking',
                icon: Icons.translate,
                onTap: _performTranslation,
                children: [
                  if (_translatedTexts.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Translated Texts:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ...(_translatedTexts
                        .take(4)
                        .map(
                          (text) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $text',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        )),
                    if (_translatedTexts.length > 4)
                      Text(
                        '... and ${_translatedTexts.length - 4} more',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Navigation Integration Section
              _buildSectionCard(
                title: 'Screen Navigation',
                subtitle: 'Screen transition performance tracking',
                icon: Icons.navigation,
                onTap: _performTrackedNavigation,
              ),
              const SizedBox(height: 16),

              // Modal Navigation Section
              _buildSectionCard(
                title: 'Modal Navigation',
                subtitle: 'Modal and dialog performance tracking',
                icon: Icons.open_in_new,
                onTap: _showPerformanceTrackedModal,
              ),
              const SizedBox(height: 16),

              // Bottom Sheet Navigation Section
              _buildSectionCard(
                title: 'Bottom Sheet Navigation',
                subtitle: 'Bottom sheet performance tracking',
                icon: Icons.vertical_align_bottom,
                onTap: _showPerformanceTrackedBottomSheet,
              ),
              const SizedBox(height: 32),

              // Performance Summary Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.analytics,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Performance Summary',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'This screen demonstrates comprehensive Firebase Performance integration:',
                      ),
                      const SizedBox(height: 8),
                      const Text('✅ Automatic HTTP request monitoring'),
                      const Text('✅ Translation operation tracking'),
                      const Text('✅ Screen navigation performance'),
                      const Text('✅ Modal and bottom sheet tracking'),
                      const Text('✅ Custom operation tracing'),
                      const Text('✅ Error handling and metrics'),
                      const SizedBox(height: 16),
                      Text(
                        'All performance data is automatically sent to Firebase Performance Monitoring for analysis.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    List<Widget> children = const [],
  }) {
    return Card(
      child: InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Demo user profile screen for navigation example
class _DemoUserProfileScreen extends StatelessWidget {
  const _DemoUserProfileScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demo User Profile'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person, size: 100, color: Colors.grey),
              SizedBox(height: 24),
              Text(
                'Demo User Profile',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text(
                'This screen demonstrates navigation performance tracking. The transition to this screen was automatically monitored.',
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              Text(
                'Check Firebase Performance console to see the navigation metrics.',
                style: TextStyle(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
