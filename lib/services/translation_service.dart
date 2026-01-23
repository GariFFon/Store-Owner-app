import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/services/performance_service.dart';

class TranslationService {
  static TranslationService? _instance;
  static TranslationService get instance =>
      _instance ??= TranslationService._();
  TranslationService._();

  OnDeviceTranslator? _currentTranslator;
  OnDeviceTranslatorModelManager? _modelManager;
  String _currentLanguageCode = 'en'; // Default to English
  final PerformanceService _performanceService = PerformanceService.instance;

  // Supported languages with major Indian languages
  static const Map<String, SupportedLanguage> supportedLanguages = {
    'en': SupportedLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flag: '🇺🇸',
      mlKitLanguage: TranslateLanguage.english,
      imageUrl:
          'https://images.unsplash.com/photo-1485738422979-f5c462d49f74?w=100&h=100&fit=crop&crop=center',
    ),
    'hi': SupportedLanguage(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      flag: '🇮🇳',
      mlKitLanguage: TranslateLanguage.hindi,
      imageUrl:
          'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?w=100&h=100&fit=crop&crop=center',
    ),
    'bn': SupportedLanguage(
      code: 'bn',
      name: 'Bengali',
      nativeName: 'বাংলা',
      flag: '🇧🇩',
      mlKitLanguage: TranslateLanguage.bengali,
      imageUrl:
          'https://images.unsplash.com/photo-1568322503294-f8b7b2888fb8?w=100&h=100&fit=crop&crop=center',
    ),
    'te': SupportedLanguage(
      code: 'te',
      name: 'Telugu',
      nativeName: 'తెలుగు',
      flag: '🇮🇳',
      mlKitLanguage: TranslateLanguage.telugu,
      imageUrl:
          'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=100&h=100&fit=crop&crop=center',
    ),
    'ta': SupportedLanguage(
      code: 'ta',
      name: 'Tamil',
      nativeName: 'தமிழ்',
      flag: '🇮🇳',
      mlKitLanguage: TranslateLanguage.tamil,
      imageUrl:
          'https://images.unsplash.com/photo-1582510003544-4d00b7f74220?w=100&h=100&fit=crop&crop=center',
    ),
    'gu': SupportedLanguage(
      code: 'gu',
      name: 'Gujarati',
      nativeName: 'ગુજરાતી',
      flag: '🇮🇳',
      mlKitLanguage: TranslateLanguage.gujarati,
      imageUrl:
          'https://images.unsplash.com/photo-1561361513-2d000314d7b9?w=100&h=100&fit=crop&crop=center',
    ),
    'mr': SupportedLanguage(
      code: 'mr',
      name: 'Marathi',
      nativeName: 'मराठी',
      flag: '🇮🇳',
      mlKitLanguage: TranslateLanguage.marathi,
      imageUrl:
          'https://images.unsplash.com/photo-1580477667995-2b94f01c9516?w=100&h=100&fit=crop&crop=center',
    ),
    'kn': SupportedLanguage(
      code: 'kn',
      name: 'Kannada',
      nativeName: 'ಕನ್ನಡ',
      flag: '🇮🇳',
      mlKitLanguage: TranslateLanguage.kannada,
      imageUrl:
          'https://images.unsplash.com/photo-1594736797933-d0402ba18d95?w=100&h=100&fit=crop&crop=center',
    ),
    'ur': SupportedLanguage(
      code: 'ur',
      name: 'Urdu',
      nativeName: 'اردو',
      flag: '🇵🇰',
      mlKitLanguage: TranslateLanguage.urdu,
      imageUrl:
          'https://images.unsplash.com/photo-1588123353632-0954b2aaa9c5?w=100&h=100&fit=crop&crop=center',
    ),
    // Note: Assamese is supported by Google Cloud Translation but not yet by ML Kit
    // Will be added when ML Kit adds support: 'as' -> 'Assamese' -> 'অসমীয়া'
    // Nepali and Sinhala not available in ML Kit Translation
    // Additional popular languages
    'es': SupportedLanguage(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      flag: '🇪🇸',
      mlKitLanguage: TranslateLanguage.spanish,
      imageUrl:
          'https://images.unsplash.com/photo-1539037116277-4db20889f2d4?w=100&h=100&fit=crop&crop=center',
    ),
    'fr': SupportedLanguage(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      flag: '🇫🇷',
      mlKitLanguage: TranslateLanguage.french,
      imageUrl:
          'https://images.unsplash.com/photo-1502602898536-47ad22581b52?w=100&h=100&fit=crop&crop=center',
    ),
    'de': SupportedLanguage(
      code: 'de',
      name: 'German',
      nativeName: 'Deutsch',
      flag: '🇩🇪',
      mlKitLanguage: TranslateLanguage.german,
      imageUrl:
          'https://images.unsplash.com/photo-1467269204594-9661b134dd2b?w=100&h=100&fit=crop&crop=center',
    ),
    'ar': SupportedLanguage(
      code: 'ar',
      name: 'Arabic',
      nativeName: 'العربية',
      flag: '🇸🇦',
      mlKitLanguage: TranslateLanguage.arabic,
      imageUrl:
          'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=100&h=100&fit=crop&crop=center',
    ),
    'zh': SupportedLanguage(
      code: 'zh',
      name: 'Chinese',
      nativeName: '中文',
      flag: '🇨🇳',
      mlKitLanguage: TranslateLanguage.chinese,
      imageUrl:
          'https://images.unsplash.com/photo-1508804185872-d7badad00f7d?w=100&h=100&fit=crop&crop=center',
    ),
    'ja': SupportedLanguage(
      code: 'ja',
      name: 'Japanese',
      nativeName: '日本語',
      flag: '🇯🇵',
      mlKitLanguage: TranslateLanguage.japanese,
      imageUrl:
          'https://images.unsplash.com/photo-1528164344705-47542687000d?w=100&h=100&fit=crop&crop=center',
    ),
    'ko': SupportedLanguage(
      code: 'ko',
      name: 'Korean',
      nativeName: '한국어',
      flag: '🇰🇷',
      mlKitLanguage: TranslateLanguage.korean,
      imageUrl:
          'https://images.unsplash.com/photo-1517154421773-0529f29ea451?w=100&h=100&fit=crop&crop=center',
    ),
    'ru': SupportedLanguage(
      code: 'ru',
      name: 'Russian',
      nativeName: 'Русский',
      flag: '🇷🇺',
      mlKitLanguage: TranslateLanguage.russian,
      imageUrl:
          'https://images.unsplash.com/photo-1513475382585-d06e58bcb0e0?w=100&h=100&fit=crop&crop=center',
    ),
    'pt': SupportedLanguage(
      code: 'pt',
      name: 'Portuguese',
      nativeName: 'Português',
      flag: '🇵🇹',
      mlKitLanguage: TranslateLanguage.portuguese,
      imageUrl:
          'https://images.unsplash.com/photo-1555881400-74d7acaacd8b?w=100&h=100&fit=crop&crop=center',
    ),
    'it': SupportedLanguage(
      code: 'it',
      name: 'Italian',
      nativeName: 'Italiano',
      flag: '🇮🇹',
      mlKitLanguage: TranslateLanguage.italian,
      imageUrl:
          'https://images.unsplash.com/photo-1515542622106-78bda8ba0e5b?w=100&h=100&fit=crop&crop=center',
    ),
  };

  OnDeviceTranslatorModelManager get modelManager {
    _modelManager ??= OnDeviceTranslatorModelManager();
    return _modelManager!;
  }

  String get currentLanguageCode => _currentLanguageCode;

  SupportedLanguage get currentLanguage =>
      supportedLanguages[_currentLanguageCode] ?? supportedLanguages['en']!;

  List<SupportedLanguage> get availableLanguages =>
      supportedLanguages.values.toList();

  List<SupportedLanguage> get indianLanguages => supportedLanguages.values
      .where(
        (lang) => [
          'hi',
          'bn',
          'te',
          'ta',
          'gu',
          'mr',
          'kn',
          'ur',
        ].contains(lang.code),
      )
      .toList();

  /// Initialize the translation service
  Future<void> initialize() async {
    await _performanceService.traceOperation(
      'translation_service_init',
      () async {
        await _loadSavedLanguage();
        await _performDiagnostics();
      },
      attributes: {'category': 'translation', 'operation': 'initialize'},
    );

    if (kDebugMode) {
      print(
        '🌐 TranslationService initialized with language: $_currentLanguageCode',
      );
    }
  }

  /// Perform diagnostics to check if translation service is working
  Future<void> _performDiagnostics() async {
    try {
      if (kDebugMode) {
        print('🔍 Running Translation Service diagnostics...');

        // Check if model manager is accessible
        final manager = modelManager;
        print('✅ Model manager initialized: ${manager.runtimeType}');

        // Test with English model (should always be available)
        final englishAvailable = await manager.isModelDownloaded('en');
        print('🇺🇸 English model available: $englishAvailable');

        // Check Hindi model specifically
        final hindiAvailable = await manager.isModelDownloaded('hi');
        print('🇮🇳 Hindi model available: $hindiAvailable');

        print('✅ Translation Service diagnostics completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Translation Service diagnostics failed: $e');
        print('📝 Stack trace: ${StackTrace.current}');
      }
    }
  }

  /// Load saved language preference
  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentLanguageCode = prefs.getString('selected_language') ?? 'en';
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading saved language: $e');
      }
      _currentLanguageCode = 'en';
    }
  }

  /// Save language preference
  Future<void> _saveLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language', _currentLanguageCode);
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving language preference: $e');
      }
    }
  }

  /// Change the current language
  Future<bool> changeLanguage(String languageCode) async {
    if (!supportedLanguages.containsKey(languageCode)) {
      if (kDebugMode) {
        print('❌ Unsupported language code: $languageCode');
      }
      return false;
    }

    return await _performanceService.traceOperation(
      'translation_change_language',
      () async {
        try {
          // For English, no model download needed
          if (languageCode == 'en') {
            await _closeCurrentTranslator();
            _currentLanguageCode = languageCode;
            await _saveLanguagePreference();

            if (kDebugMode) {
              print('✅ Language changed to: English');
            }
            return true;
          }

          // Check if target language model is downloaded
          final isDownloaded = await modelManager.isModelDownloaded(
            supportedLanguages[languageCode]!.mlKitLanguage.bcpCode,
          );

          if (!isDownloaded) {
            if (kDebugMode) {
              print(
                '📥 Model not downloaded, attempting download for: $languageCode',
              );
            }
            // Download the model if not available
            final downloadSuccess = await downloadLanguageModel(languageCode);
            if (!downloadSuccess) {
              if (kDebugMode) {
                print('❌ Failed to download model for: $languageCode');
              }
              return false;
            }
          }

          // Close current translator if exists
          await _closeCurrentTranslator();

          // Update current language
          _currentLanguageCode = languageCode;
          await _saveLanguagePreference();

          if (kDebugMode) {
            print(
              '✅ Language changed to: ${supportedLanguages[languageCode]!.name}',
            );
          }

          return true;
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error changing language: $e');
            print('📝 Stack trace: ${StackTrace.current}');
          }
          return false;
        }
      },
      attributes: {
        'category': 'translation',
        'operation': 'change_language',
        'from_language': _currentLanguageCode,
        'to_language': languageCode,
      },
    );
  }

  /// Download language model with comprehensive error handling
  Future<bool> downloadLanguageModel(String languageCode) async {
    if (!supportedLanguages.containsKey(languageCode)) {
      if (kDebugMode) {
        print('❌ Language code not supported: $languageCode');
      }
      return false;
    }

    // English doesn't need download
    if (languageCode == 'en') {
      if (kDebugMode) {
        print('✅ English model is always available');
      }
      return true;
    }

    return await _performanceService.traceOperation(
      'translation_download_model',
      () async {
        try {
          final language = supportedLanguages[languageCode]!;

          if (kDebugMode) {
            print(
              '📥 Starting download for: ${language.name} (${language.code})',
            );
            print('🔍 BCP-47 code: ${language.mlKitLanguage.bcpCode}');
          }

          // Check if already downloaded
          final alreadyDownloaded = await modelManager.isModelDownloaded(
            language.mlKitLanguage.bcpCode,
          );

          if (alreadyDownloaded) {
            if (kDebugMode) {
              print('✅ Model already downloaded for: ${language.name}');
            }
            return true;
          }

          if (kDebugMode) {
            print('⬇️ Downloading model for: ${language.name}...');
          }

          // Attempt download with timeout
          final success = await Future.any([
            modelManager.downloadModel(language.mlKitLanguage.bcpCode),
            Future.delayed(
              const Duration(seconds: 30),
              () => false,
            ), // 30 second timeout
          ]);

          if (kDebugMode) {
            if (success) {
              print('✅ Model downloaded successfully for: ${language.name}');

              // Verify download
              final verifyDownload = await modelManager.isModelDownloaded(
                language.mlKitLanguage.bcpCode,
              );
              print('🔍 Download verification: $verifyDownload');
            } else {
              print('❌ Failed to download model for: ${language.name}');
              print('💡 Common solutions:');
              print('   1. Check internet connection (try opening a website)');
              print('   2. Update Google Play Services from Play Store');
              print('   3. Restart the app and try again');
              print('   4. Clear some storage space (models need ~1-3MB each)');
              print('   5. Try downloading on WiFi instead of mobile data');
              print('   6. Restart your device if problem persists');
            }
          }

          return success;
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error downloading language model: $e');
            print('📝 Error type: ${e.runtimeType}');
            print('📝 Stack trace: ${StackTrace.current}');

            // Provide specific error guidance
            if (e.toString().contains('NETWORK_ERROR')) {
              print('💡 Network error - check internet connection');
            } else if (e.toString().contains('INSUFFICIENT_SPACE')) {
              print('💡 Insufficient storage space');
            } else if (e.toString().contains('MODEL_NOT_AVAILABLE')) {
              print('💡 Model not available for this language/region');
            } else {
              print('💡 Unknown error - check Google Play Services');
            }
          }
          return false;
        }
      },
      attributes: {
        'category': 'translation',
        'operation': 'download_model',
        'language': languageCode,
      },
    );
  }

  /// Check if language model is downloaded
  Future<bool> isLanguageModelDownloaded(String languageCode) async {
    if (!supportedLanguages.containsKey(languageCode)) {
      return false;
    }

    // English is always available
    if (languageCode == 'en') {
      return true;
    }

    try {
      final isDownloaded = await modelManager.isModelDownloaded(
        supportedLanguages[languageCode]!.mlKitLanguage.bcpCode,
      );

      if (kDebugMode) {
        print('🔍 Model download status for $languageCode: $isDownloaded');
      }

      return isDownloaded;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error checking model download status: $e');
      }
      return false;
    }
  }

  /// Delete language model
  Future<bool> deleteLanguageModel(String languageCode) async {
    if (!supportedLanguages.containsKey(languageCode)) {
      return false;
    }

    // Can't delete English model
    if (languageCode == 'en') {
      if (kDebugMode) {
        print('⚠️ Cannot delete English model (always available)');
      }
      return false;
    }

    return await _performanceService.traceOperation(
      'translation_delete_model',
      () async {
        try {
          final language = supportedLanguages[languageCode]!;
          final success = await modelManager.deleteModel(
            language.mlKitLanguage.bcpCode,
          );

          if (kDebugMode) {
            print(
              success
                  ? '🗑️ Model deleted successfully for: ${language.name}'
                  : '❌ Failed to delete model for: ${language.name}',
            );
          }

          return success;
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error deleting language model: $e');
          }
          return false;
        }
      },
      attributes: {
        'category': 'translation',
        'operation': 'delete_model',
        'language': languageCode,
      },
    );
  }

  /// Translate text from English to current language
  Future<String> translateFromEnglish(String text) async {
    if (_currentLanguageCode == 'en' || text.trim().isEmpty) {
      return text; // No translation needed
    }

    return await translateText(text, 'en', _currentLanguageCode);
  }

  /// Translate text to English from current language
  Future<String> translateToEnglish(String text) async {
    if (_currentLanguageCode == 'en' || text.trim().isEmpty) {
      return text; // No translation needed
    }

    return await translateText(text, _currentLanguageCode, 'en');
  }

  /// Translate text between specific languages
  Future<String> translateText(
    String text,
    String fromLanguage,
    String toLanguage,
  ) async {
    if (text.trim().isEmpty || fromLanguage == toLanguage) {
      return text;
    }

    if (!supportedLanguages.containsKey(fromLanguage) ||
        !supportedLanguages.containsKey(toLanguage)) {
      if (kDebugMode) {
        print('❌ Unsupported language pair: $fromLanguage -> $toLanguage');
      }
      return text;
    }

    return await _performanceService.traceTranslation(
      fromLanguage,
      toLanguage,
      () async {
        try {
          final sourceLanguage =
              supportedLanguages[fromLanguage]!.mlKitLanguage;
          final targetLanguage = supportedLanguages[toLanguage]!.mlKitLanguage;

          // Check if models are downloaded (English is always available)
          final sourceDownloaded =
              fromLanguage == 'en' ||
              await modelManager.isModelDownloaded(sourceLanguage.bcpCode);
          final targetDownloaded =
              toLanguage == 'en' ||
              await modelManager.isModelDownloaded(targetLanguage.bcpCode);

          if (!sourceDownloaded || !targetDownloaded) {
            if (kDebugMode) {
              print(
                '❌ Required language models not downloaded: '
                'source($fromLanguage): $sourceDownloaded, '
                'target($toLanguage): $targetDownloaded',
              );
            }
            return text;
          }

          // Create translator
          final translator = OnDeviceTranslator(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
          );

          final translatedText = await translator.translateText(text);

          // Close translator after use
          translator.close();

          if (kDebugMode) {
            print('🔄 Translated: "$text" -> "$translatedText"');
          }

          return translatedText;
        } catch (e) {
          if (kDebugMode) {
            print('❌ Translation error: $e');
            print('📝 From: $fromLanguage, To: $toLanguage');
          }
          return text; // Return original text on error
        }
      },
    );
  }

  /// Close current translator
  Future<void> _closeCurrentTranslator() async {
    try {
      _currentTranslator?.close();
      _currentTranslator = null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error closing translator: $e');
      }
    }
  }

  /// Get download progress for a language (mock implementation)
  Stream<double> getDownloadProgress(String languageCode) async* {
    // This is a mock implementation since ML Kit doesn't provide progress
    // You can enhance this by implementing actual progress tracking
    for (double progress = 0.0; progress <= 1.0; progress += 0.1) {
      await Future.delayed(const Duration(milliseconds: 200));
      yield progress;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _closeCurrentTranslator();
    _modelManager = null;
  }
}

/// Language model class
class SupportedLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String flag;
  final TranslateLanguage mlKitLanguage;
  final String? imageUrl;

  const SupportedLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.mlKitLanguage,
    this.imageUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupportedLanguage &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => '$flag $nativeName ($name)';
}
