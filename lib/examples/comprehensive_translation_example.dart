import 'package:flutter/material.dart';
import 'package:exanor/components/universal_translation_wrapper.dart';
import 'package:exanor/services/enhanced_translation_service.dart';

/// Comprehensive example showing how to integrate universal translation
/// This covers ALL scenarios: UI text, API responses, lists, forms, etc.
class ComprehensiveTranslationExample extends StatefulWidget {
  const ComprehensiveTranslationExample({super.key});

  @override
  State<ComprehensiveTranslationExample> createState() =>
      _ComprehensiveTranslationExampleState();
}

class _ComprehensiveTranslationExampleState
    extends State<ComprehensiveTranslationExample>
    with TranslationMixin {
  // Sample API response data
  final List<Map<String, dynamic>> _apiData = [
    {
      'id': '123',
      'first_name': 'John',
      'last_name': 'Smith',
      'profession': 'Software Engineer',
      'bio': 'Experienced developer with 5 years in mobile development',
      'services': ['App Development', 'UI Design', 'Consulting'],
      'location': 'New York',
      'phone_number': '+1234567890',
      'email': 'john@example.com',
      'img_url': 'https://example.com/image.jpg',
    },
    {
      'id': '456',
      'first_name': 'Maria',
      'last_name': 'Garcia',
      'profession': 'Graphic Designer',
      'bio': 'Creative designer specializing in brand identity and web design',
      'services': ['Logo Design', 'Branding', 'Web Design'],
      'location': 'Los Angeles',
      'phone_number': '+1987654321',
      'email': 'maria@example.com',
      'img_url': 'https://example.com/image2.jpg',
    },
  ];

  List<Map<String, dynamic>> _translatedData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAndTranslateData();
  }

  Future<void> _loadAndTranslateData() async {
    setState(() {
      _isLoading = true;
    });

    // Method 1: Translate API responses using enhanced service
    final enhancedService = EnhancedTranslationService.instance;
    final translated = await enhancedService.translateApiResponseList(
      _apiData,
      translateUserNames: true, // As requested - translate everything
      forceIncludeFields: [
        'first_name',
        'last_name',
        'profession',
        'bio',
        'services',
        'location',
      ],
    );

    setState(() {
      _translatedData = translated;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Method 1: Using SmartTranslatedText for UI elements
        title: const SmartTranslatedText('Professional Directory'),
        actions: [
          IconButton(
            onPressed: _loadAndTranslateData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh', // Tooltips need synchronous strings
          ),
        ],
      ),
      body: UniversalTranslationWrapper(
        // Method 3: Wrap entire sections for automatic translation
        excludePatterns: ['@', '.com'], // Don't translate emails/URLs
        child: Column(
          children: [
            // Header section with mixed content
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // UI text - automatically translated by wrapper
                  const SmartTranslatedText(
                    'Browse Professional Profiles',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const SmartTranslatedText(
                    'Find skilled professionals in your area for any service you need.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),

                  // Statistics row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        'Total Professionals',
                        '${_apiData.length}',
                      ),
                      _buildStatCard('Languages Supported', '20+'),
                      _buildStatCard('Success Rate', '99%'),
                    ],
                  ),
                ],
              ),
            ),

            // Loading or content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          SmartTranslatedText('Translating content...'),
                        ],
                      ),
                    )
                  : _buildTranslatedList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showTranslationDemo,
        child: const Icon(Icons.translate),
        tooltip: 'Translation Demo', // Tooltips need synchronous strings
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Column(
      children: [
        SmartTranslatedText(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTranslatedList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _translatedData.length,
      itemBuilder: (context, index) {
        final profile = _translatedData[index];
        return _buildProfileCard(profile);
      },
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> profile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and profession
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage(
                    profile['img_url'] ?? 'https://via.placeholder.com/150',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Names - will be translated as requested
                      Text(
                        '${profile['first_name']} ${profile['last_name']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Profession - translated
                      Text(
                        profile['profession'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Location - translated
                      Text(
                        profile['location'] ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Bio section - translated
            if (profile['bio'] != null && profile['bio'].toString().isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SmartTranslatedText(
                    'About:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(profile['bio']),
                  const SizedBox(height: 12),
                ],
              ),

            // Services section - list items translated
            if (profile['services'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SmartTranslatedText(
                    'Services:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: (profile['services'] as List)
                        .map<Widget>(
                          (service) => Chip(
                            label: Text(service.toString()),
                            backgroundColor: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showContactDialog(profile),
                  icon: const Icon(Icons.message, size: 16),
                  label: const SmartTranslatedText('Contact'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _viewFullProfile(profile),
                  icon: const Icon(Icons.person, size: 16),
                  label: const SmartTranslatedText('View Profile'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showContactDialog(Map<String, dynamic> profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: SmartTranslatedText('Contact ${profile['first_name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phone: ${profile['phone_number']}'), // Don't translate
            Text('Email: ${profile['email']}'), // Don't translate
            const SizedBox(height: 16),
            const SmartTranslatedText(
              'How would you like to contact this professional?',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const SmartTranslatedText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle contact action
            },
            child: const SmartTranslatedText('Send Message'),
          ),
        ],
      ),
    );
  }

  void _viewFullProfile(Map<String, dynamic> profile) {
    // Navigate to full profile screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullProfileExample(profile: profile),
      ),
    );
  }

  void _showTranslationDemo() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SmartTranslatedText(
              'Translation Demo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const SmartTranslatedText('Current language: '),
            Text(currentLanguage), // Don't translate language codes
            const SizedBox(height: 16),
            const SmartTranslatedText(
              'All visible text including API responses like names, professions, and descriptions are being translated in real-time.',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Show translation statistics
                _showTranslationStats();
              },
              child: const SmartTranslatedText('View Translation Statistics'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTranslationStats() {
    final stats = EnhancedTranslationService.instance.getStatistics();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const SmartTranslatedText('Translation Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cached translations: ${stats['cached_translations']}'),
            Text('Current language: ${stats['current_language']}'),
            Text('Cache size: ${stats['cache_size_bytes']} bytes'),
            const SizedBox(height: 16),
            const SmartTranslatedText(
              'The translation system automatically caches results for better performance.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const SmartTranslatedText('Close'),
          ),
        ],
      ),
    );
  }
}

/// Full profile screen example
class FullProfileExample extends StatelessWidget {
  final Map<String, dynamic> profile;

  const FullProfileExample({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SmartTranslatedText(
          '${profile['first_name']} ${profile['last_name']}',
        ),
      ),
      body: UniversalTranslationWrapper(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // All content here will be automatically translated
              const SmartTranslatedText(
                'Professional Profile',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Profile details with mixed translated/untranslated content
              _buildDetailRow(
                'Name',
                '${profile['first_name']} ${profile['last_name']}',
              ),
              _buildDetailRow('Profession', profile['profession']),
              _buildDetailRow('Location', profile['location']),
              _buildDetailRow('Bio', profile['bio']),

              const SizedBox(height: 24),

              const SmartTranslatedText(
                'Contact Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Contact details (not translated)
              _buildDetailRow(
                'Phone',
                profile['phone_number'],
                translate: false,
              ),
              _buildDetailRow('Email', profile['email'], translate: false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value, {bool translate = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: SmartTranslatedText(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: translate
                ? SmartTranslatedText(value ?? 'N/A')
                : Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }
}

/// Extension methods for easy integration
extension UniversalTranslationExtension on String {
  /// Quick translation method (async)
  Future<String> translate() async {
    return await EnhancedTranslationService.instance.translateText(this);
  }

  /// Get immediate translation (returns original if not cached) - for tooltips and sync usage
  String translateSync() {
    // For synchronous usage like tooltips, return original text
    // The translation will happen in the background via SmartTranslatedText widgets
    return this;
  }
}

/// Helper function to show the comprehensive example
void showComprehensiveTranslationExample(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const ComprehensiveTranslationExample(),
    ),
  );
}
