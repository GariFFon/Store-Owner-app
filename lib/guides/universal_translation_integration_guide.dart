import 'package:flutter/material.dart';
import 'package:exanor/components/universal_translation_wrapper.dart';
import 'package:exanor/services/enhanced_translation_service.dart';

/// Comprehensive Universal Translation Integration Guide
/// Shows how to apply translation to ANY screen with ALL types of content
class UniversalTranslationIntegrationGuide extends StatefulWidget {
  const UniversalTranslationIntegrationGuide({super.key});

  @override
  State<UniversalTranslationIntegrationGuide> createState() =>
      _UniversalTranslationIntegrationGuideState();
}

class _UniversalTranslationIntegrationGuideState
    extends State<UniversalTranslationIntegrationGuide> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const SmartTranslatedText('Universal Translation Guide'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: const UniversalTranslationWrapper(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IntroSection(),
              SizedBox(height: 24),
              _StepByStepGuide(),
              SizedBox(height: 24),
              _CodeExamples(),
              SizedBox(height: 24),
              _APIResponseExamples(),
              SizedBox(height: 24),
              _BestPractices(),
              SizedBox(height: 24),
              _TroubleshootingSection(),
              SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroSection extends StatelessWidget {
  const _IntroSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.translate, color: Colors.blue, size: 24),
              SizedBox(width: 8),
              SmartTranslatedText(
                'Universal Translation System',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 12),
          SmartTranslatedText(
            'This system translates ALL visible text including UI elements, API responses, user names, descriptions, and any other content that users see.',
          ),
          SizedBox(height: 8),
          SmartTranslatedText(
            '🎯 Goal: Complete app translation with minimal code changes',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StepByStepGuide extends StatelessWidget {
  const _StepByStepGuide();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SmartTranslatedText(
          'Step-by-Step Integration',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildStep(
          '1',
          'Import Required Components',
          'Add the universal translation imports to your screen.',
          '''import 'package:exanor/components/universal_translation_wrapper.dart';
import 'package:exanor/services/enhanced_translation_service.dart';''',
        ),
        _buildStep(
          '2',
          'Wrap Your Screen Body',
          'Wrap the main content with UniversalTranslationWrapper.',
          '''body: UniversalTranslationWrapper(
  excludePatterns: ['@', '.com', '+'], // Don't translate emails/phones
  child: YourScreenContent(),
),''',
        ),
        _buildStep(
          '3',
          'Replace Text Widgets',
          'Replace Text widgets with SmartTranslatedText for UI elements.',
          '''// Before
Text('Welcome to exanor')

// After  
SmartTranslatedText('Welcome to exanor')''',
        ),
        _buildStep(
          '4',
          'Translate API Responses',
          'Use enhanced service to translate API data.',
          '''final enhancedService = EnhancedTranslationService.instance;
final translatedData = await enhancedService.translateApiResponse(
  apiResponse,
  translateUserNames: true, // Translate everything
  forceIncludeFields: ['name', 'title', 'description'],
);''',
        ),
        _buildStep(
          '5',
          'Handle Lists and Complex Data',
          'Use TranslatedListView for lists of translated content.',
          '''TranslatedListView(
  items: apiDataList,
  itemBuilder: (context, translatedItem, index) {
    return ListTile(title: Text(translatedItem['name']));
  },
)''',
        ),
      ],
    );
  }

  Widget _buildStep(
    String number,
    String title,
    String description,
    String code,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SmartTranslatedText(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                SmartTranslatedText(description),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeExamples extends StatelessWidget {
  const _CodeExamples();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SmartTranslatedText(
          'Complete Screen Example',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: const Text('''class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> 
    with TranslationMixin {
  
  List<Map<String, dynamic>> _data = [];
  final _enhancedService = EnhancedTranslationService.instance;
  
  Future<void> _loadData() async {
    final apiResponse = await ApiService.get('/endpoint');
    
    // Translate API responses
    final translated = await _enhancedService.translateApiResponseList(
      apiResponse['data'],
      translateUserNames: true,
    );
    
    setState(() {
      _data = translated;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SmartTranslatedText('My Screen'),
      ),
      body: UniversalTranslationWrapper(
        excludePatterns: ['@', '.com', 'http'],
        child: Column(
          children: [
            // Header
            SmartTranslatedText('Welcome Message'),
            
            // List with translated data
            Expanded(
              child: ListView.builder(
                itemCount: _data.length,
                itemBuilder: (context, index) {
                  final item = _data[index];
                  return ListTile(
                    title: Text(item['name']), // Already translated
                    subtitle: Text(item['description']), // Already translated
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}''', style: TextStyle(fontFamily: 'monospace', fontSize: 11)),
        ),
      ],
    );
  }
}

class _APIResponseExamples extends StatelessWidget {
  const _APIResponseExamples();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SmartTranslatedText(
          'API Response Translation Examples',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildApiExample('User Profile Translation', '''// Original API Response
{
  "id": "123",
  "first_name": "John",
  "last_name": "Smith", 
  "profession": "Software Engineer",
  "bio": "Experienced developer",
  "email": "john@example.com"
}

// After Translation (Hindi)
{
  "id": "123",
  "first_name": "जॉन",
  "last_name": "स्मिथ",
  "profession": "सॉफ्टवेयर इंजीनियर", 
  "bio": "अनुभवी डेवलपर",
  "email": "john@example.com" // Excluded from translation
}'''),
        _buildApiExample('Service List Translation', '''// Original API Response
[
  {
    "service_name": "House Cleaning",
    "description": "Professional home cleaning service",
    "category": "Home Services"
  },
  {
    "service_name": "Plumbing",
    "description": "Expert plumbing repairs and installation", 
    "category": "Home Maintenance"
  }
]

// After Translation (Hindi) 
[
  {
    "service_name": "घर की सफाई",
    "description": "पेशेवर घरेलू सफाई सेवा",
    "category": "गृह सेवाएं"
  },
  {
    "service_name": "प्लंबिंग",
    "description": "विशेषज्ञ प्लंबिंग मरम्मत और स्थापना",
    "category": "घर का रखरखाव"
  }
]'''),
      ],
    );
  }

  Widget _buildApiExample(String title, String code) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartTranslatedText(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Text(
              code,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _BestPractices extends StatelessWidget {
  const _BestPractices();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SmartTranslatedText(
          'Best Practices',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildPractice(
          '✅',
          'DO: Translate User-Facing Content',
          'Translate all text that users read: UI labels, descriptions, names, titles, messages.',
        ),
        _buildPractice(
          '✅',
          'DO: Use Exclude Patterns',
          'Exclude emails, URLs, phone numbers using excludePatterns: ["@", ".com", "+"]',
        ),
        _buildPractice(
          '✅',
          'DO: Batch Process API Data',
          'Use translateApiResponseList() for lists to optimize performance.',
        ),
        _buildPractice(
          '✅',
          'DO: Cache Translations',
          'The system automatically caches translations for better performance.',
        ),
        _buildPractice(
          '❌',
          'DON\'T: Translate Technical Data',
          'Avoid translating IDs, timestamps, URLs, error codes, or API keys.',
        ),
        _buildPractice(
          '💡',
          'TIP: Test with Different Languages',
          'Always test your translations with various languages to ensure UI layout works.',
        ),
      ],
    );
  }

  Widget _buildPractice(String icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SmartTranslatedText(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                SmartTranslatedText(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TroubleshootingSection extends StatelessWidget {
  const _TroubleshootingSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SmartTranslatedText(
          'Troubleshooting',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildTroubleshootingItem('Translation Not Working?', [
          'Check if language model is downloaded',
          'Verify text is not in excludePatterns',
          'Ensure network connectivity for initial download',
          'Check if text length > 1 character',
        ]),
        _buildTroubleshootingItem('Performance Issues?', [
          'Use batch translation for lists',
          'Implement pagination for large data sets',
          'Clear translation cache periodically',
          'Avoid translating very frequently changing text',
        ]),
        _buildTroubleshootingItem('UI Layout Breaking?', [
          'Test with longer languages (German, Hindi)',
          'Use flexible layouts with Expanded/Flexible',
          'Set appropriate maxLines for Text widgets',
          'Consider text scaling factors',
        ]),
      ],
    );
  }

  Widget _buildTroubleshootingItem(String title, List<String> solutions) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartTranslatedText(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...solutions.map(
            (solution) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: SmartTranslatedText(solution)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show the integration guide
void showUniversalTranslationGuide(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const UniversalTranslationIntegrationGuide(),
    ),
  );
}
