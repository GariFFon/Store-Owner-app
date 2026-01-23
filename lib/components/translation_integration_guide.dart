import 'package:flutter/material.dart';
import 'package:exanor/components/translation_widget.dart';

/// This file demonstrates how to integrate translation into your existing screens
///
/// STEP 1: Import the translation widget
/// import 'package:exanor/components/translation_widget.dart';
///
/// STEP 2: Replace Text widgets with TranslatedText widgets
/// STEP 3: Use String.translated() extension for simple text
/// STEP 4: Test with different languages

class TranslationIntegrationGuide extends StatelessWidget {
  const TranslationIntegrationGuide({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText('Translation Integration Guide'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const TranslatedText(
              'How to Add Translation to Your Screens',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Basic Example
            _buildSection('Step 1: Replace Text with TranslatedText', '''
// BEFORE (not translated):
Text(
  'My Profile',
  style: theme.textTheme.titleLarge,
)

// AFTER (translated):
TranslatedText(
  'My Profile',
  style: theme.textTheme.titleLarge,
)
              '''),

            // Extension Example
            _buildSection('Step 2: Use String Extensions', '''
// For simple text, use the extension method:
final translatedText = 'Hello World'.translated();

// Or in widgets like SnackBar:
SnackBar(content: Text('Success'.translated()))
              '''),

            // API Data Example
            _buildSection('Step 3: Don\'t Translate API Data', '''
// API data like user names, descriptions should NOT be translated:
Text(userData['firstName']) // ✅ Keep as Text
TranslatedText('First Name:') // ✅ UI labels should be translated

// Mixed content:
TranslatedText('Welcome, \${userData['firstName']}!')
              '''),

            // Form Example
            _buildSection('Step 4: Forms and Input Fields', '''
// Input field labels and hints:
TextFormField(
  decoration: InputDecoration(
    labelText: 'First Name'.translated(),
    hintText: 'Enter your first name'.translated(),
  ),
)

// Or using TranslatedText for labels:
Column(
  children: [
    TranslatedText('First Name'),
    TextFormField(...)
  ],
)
              '''),

            // Common UI Elements
            _buildSection('Step 5: Common UI Elements to Translate', '''
✅ App Bar titles
✅ Button labels  
✅ Menu items
✅ Section headers
✅ Descriptions and help text
✅ Error messages
✅ Toast/SnackBar messages
✅ Dialog titles and content
✅ Tab labels
✅ Settings options

❌ User-generated content (names, reviews, etc.)
❌ API response data
❌ URLs and technical identifiers
              '''),

            // Quick Pattern
            _buildSection('Quick Pattern to Follow', '''
1. Import: import 'package:exanor/components/translation_widget.dart';

2. Find all Text widgets with hardcoded strings
3. Replace: Text('Hello') → TranslatedText('Hello')
4. Keep the same style properties
5. Test by changing language in the app

// Example transformation:
AppBar(
  title: TranslatedText('My Profile'), // ✅ Translated
  actions: [
    TextButton(
      child: TranslatedText('Edit Profile'), // ✅ Translated
      onPressed: () => ...,
    ),
  ],
)
              '''),

            const SizedBox(height: 32),

            // Live Example
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TranslatedText(
                    'Live Example:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const TranslatedText(
                    'This text will be translated to Hindi when you change the language!',
                  ),
                  const SizedBox(height: 8),
                  Text('User Name: ${'John Doe'}'), // API data - not translated
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {},
                    child: const TranslatedText('Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String code) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TranslatedText(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Text(
            code,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Show the translation integration guide
void showTranslationIntegrationGuide(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => const TranslationIntegrationGuide(),
    ),
  );
}
