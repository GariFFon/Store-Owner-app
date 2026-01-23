import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:exanor/services/translation_service.dart';
import 'package:exanor/services/performance_service.dart';

/// Enhanced Translation Service for comprehensive text translation
/// Handles API responses, batch processing, and advanced translation scenarios
class EnhancedTranslationService {
  static EnhancedTranslationService? _instance;
  static EnhancedTranslationService get instance =>
      _instance ??= EnhancedTranslationService._();
  EnhancedTranslationService._();

  final TranslationService _baseService = TranslationService.instance;
  final PerformanceService _performanceService = PerformanceService.instance;
  final Map<String, String> _globalCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(hours: 24);

  /// Initialize the enhanced service
  Future<void> initialize() async {
    await _performanceService.traceOperation(
      'enhanced_translation_init',
      () async {
        await _baseService.initialize();
        _cleanExpiredCache();
      },
      attributes: {'category': 'translation', 'operation': 'initialize'},
    );
  }

  /// Get current language code
  String get currentLanguageCode => _baseService.currentLanguageCode;

  /// Check if translation is needed
  bool get isTranslationNeeded => currentLanguageCode != 'en';

  /// Clean expired cache entries
  void _cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheExpiry) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _globalCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  /// Translate a single text with caching
  Future<String> translateText(String text, {bool bypassCache = false}) async {
    if (!isTranslationNeeded || text.trim().isEmpty) {
      return text;
    }

    // Check cache first
    if (!bypassCache && _globalCache.containsKey(text)) {
      return _globalCache[text]!;
    }

    return await _performanceService.traceTranslation(
      'en',
      currentLanguageCode,
      () async {
        try {
          final translated = await _baseService.translateFromEnglish(text);

          // Cache the result
          _globalCache[text] = translated;
          _cacheTimestamps[text] = DateTime.now();

          return translated;
        } catch (e) {
          if (kDebugMode) {
            print('❌ Enhanced Translation Error: $e');
          }
          return text; // Fallback to original
        }
      },
    );
  }

  /// Translate multiple texts in batch with optimization
  Future<List<String>> translateBatch(List<String> texts) async {
    if (!isTranslationNeeded) {
      return texts;
    }

    return await _performanceService.traceOperation(
      'translation_batch',
      () async {
        final List<String> results = [];
        final List<Future<String>> futures = [];

        // Process in batches to avoid overwhelming the translation service
        const batchSize = 5;

        for (int i = 0; i < texts.length; i += batchSize) {
          final batch = texts.skip(i).take(batchSize).toList();

          for (final text in batch) {
            futures.add(translateText(text));
          }

          // Wait for this batch before processing next
          final batchResults = await Future.wait(futures);
          results.addAll(batchResults);
          futures.clear();

          // Small delay between batches to prevent rate limiting
          if (i + batchSize < texts.length) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }

        return results;
      },
      attributes: {
        'category': 'translation',
        'operation': 'batch',
        'text_count': texts.length.toString(),
        'language': currentLanguageCode,
      },
    );
  }

  /// Translate API response data intelligently
  Future<Map<String, dynamic>> translateApiResponse(
    Map<String, dynamic> response, {
    List<String> excludeFields = const [
      'id',
      'uuid',
      'phone_number',
      'email',
      'url',
      'img_url',
      'image_url',
    ],
    List<String> forceIncludeFields = const [
      'name',
      'title',
      'description',
      'bio',
      'about',
      'profession',
      'services',
    ],
    bool translateUserNames = true,
  }) async {
    if (!isTranslationNeeded) {
      return response;
    }

    return await _performanceService.traceOperation(
      'translation_api_response',
      () async {
        final Map<String, dynamic> translated = Map<String, dynamic>.from(
          response,
        );

        for (final entry in response.entries) {
          if (entry.value is String &&
              entry.value.toString().trim().isNotEmpty) {
            final fieldName = entry.key.toLowerCase();
            final textValue = entry.value.toString().trim();

            // Skip if field is excluded
            if (_shouldExcludeField(fieldName, excludeFields)) {
              continue;
            }

            // Special handling for names
            if (_isNameField(fieldName) && !translateUserNames) {
              continue;
            }

            // Force include certain fields
            if (_shouldForceInclude(fieldName, forceIncludeFields) ||
                _shouldTranslateField(fieldName, textValue)) {
              try {
                final translatedText = await translateText(textValue);
                translated[entry.key] = translatedText;
              } catch (e) {
                // Keep original on error
                translated[entry.key] = entry.value;
              }
            }
          } else if (entry.value is List) {
            // Handle arrays of strings
            final list = entry.value as List;
            final translatedList = <dynamic>[];

            for (final item in list) {
              if (item is String && item.trim().isNotEmpty) {
                try {
                  final translatedItem = await translateText(item);
                  translatedList.add(translatedItem);
                } catch (e) {
                  translatedList.add(item);
                }
              } else {
                translatedList.add(item);
              }
            }

            translated[entry.key] = translatedList;
          }
        }

        return translated;
      },
      attributes: {
        'category': 'translation',
        'operation': 'api_response',
        'field_count': response.length.toString(),
        'language': currentLanguageCode,
      },
    );
  }

  /// Translate a list of API responses
  Future<List<Map<String, dynamic>>> translateApiResponseList(
    List<Map<String, dynamic>> responses, {
    List<String> excludeFields = const [
      'id',
      'uuid',
      'phone_number',
      'email',
      'url',
      'img_url',
      'image_url',
    ],
    List<String> forceIncludeFields = const [
      'name',
      'title',
      'description',
      'bio',
      'about',
      'profession',
      'services',
    ],
    bool translateUserNames = true,
  }) async {
    if (!isTranslationNeeded) {
      return responses;
    }

    return await _performanceService.traceOperation(
      'translation_api_response_list',
      () async {
        final List<Map<String, dynamic>> translatedList = [];

        // Process in smaller batches to manage memory and performance
        const batchSize = 3;

        for (int i = 0; i < responses.length; i += batchSize) {
          final batch = responses.skip(i).take(batchSize).toList();
          final futures = batch.map(
            (response) => translateApiResponse(
              response,
              excludeFields: excludeFields,
              forceIncludeFields: forceIncludeFields,
              translateUserNames: translateUserNames,
            ),
          );

          final batchResults = await Future.wait(futures);
          translatedList.addAll(batchResults);

          // Small delay between batches
          if (i + batchSize < responses.length) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
        }

        return translatedList;
      },
      attributes: {
        'category': 'translation',
        'operation': 'api_response_list',
        'response_count': responses.length.toString(),
        'language': currentLanguageCode,
      },
    );
  }

  /// Check if field should be excluded from translation
  bool _shouldExcludeField(String fieldName, List<String> excludeFields) {
    return excludeFields.any(
      (excluded) =>
          fieldName.contains(excluded.toLowerCase()) ||
          fieldName.endsWith('_id') ||
          fieldName.endsWith('_url') ||
          fieldName.startsWith('is_') ||
          fieldName.contains('timestamp') ||
          fieldName.contains('date'),
    );
  }

  /// Check if field should be force included
  bool _shouldForceInclude(String fieldName, List<String> forceIncludeFields) {
    return forceIncludeFields.any(
      (included) => fieldName.contains(included.toLowerCase()),
    );
  }

  /// Check if this is a name field
  bool _isNameField(String fieldName) {
    return fieldName.contains('name') ||
        fieldName.contains('username') ||
        fieldName == 'user';
  }

  /// Determine if field should be translated based on content analysis
  bool _shouldTranslateField(String fieldName, String textValue) {
    // Skip very short strings (likely codes or IDs)
    if (textValue.length < 2) return false;

    // Skip strings that look like IDs, codes, or technical values
    if (RegExp(r'^[A-Z0-9_-]+$').hasMatch(textValue) ||
        RegExp(r'^\d+$').hasMatch(textValue) ||
        textValue.contains('@') ||
        textValue.startsWith('http') ||
        textValue.contains('.com') ||
        textValue.contains('.png') ||
        textValue.contains('.jpg')) {
      return false;
    }

    // Translate if it contains common translatable indicators
    if (fieldName.contains('title') ||
        fieldName.contains('description') ||
        fieldName.contains('bio') ||
        fieldName.contains('about') ||
        fieldName.contains('message') ||
        fieldName.contains('text') ||
        fieldName.contains('content') ||
        fieldName.contains('profession') ||
        fieldName.contains('service') ||
        fieldName.contains('category') ||
        fieldName.contains('skill') ||
        fieldName.contains('location')) {
      return true;
    }

    // Default: translate if it looks like human-readable text
    return textValue.split(' ').length > 1 || textValue.length > 10;
  }

  /// Get translation statistics
  Map<String, dynamic> getStatistics() {
    return {
      'cached_translations': _globalCache.length,
      'current_language': currentLanguageCode,
      'cache_size_bytes': _estimateCacheSize(),
      'oldest_cache_entry': _getOldestCacheEntry(),
    };
  }

  /// Estimate cache size in bytes
  int _estimateCacheSize() {
    int size = 0;
    for (final entry in _globalCache.entries) {
      size += entry.key.length + entry.value.length;
    }
    return size * 2; // Rough estimate (UTF-16)
  }

  /// Get oldest cache entry time
  DateTime? _getOldestCacheEntry() {
    if (_cacheTimestamps.isEmpty) return null;
    return _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b);
  }

  /// Clear all caches
  void clearCache() {
    _globalCache.clear();
    _cacheTimestamps.clear();
  }

  /// Change language and clear cache
  Future<bool> changeLanguage(String languageCode) async {
    return await _performanceService.traceOperation(
      'translation_change_language',
      () async {
        final success = await _baseService.changeLanguage(languageCode);
        if (success) {
          clearCache(); // Clear cache when language changes
        }
        return success;
      },
      attributes: {
        'category': 'translation',
        'operation': 'change_language',
        'from_language': currentLanguageCode,
        'to_language': languageCode,
      },
    );
  }

  /// Preload translations for common UI text
  Future<void> preloadCommonTranslations() async {
    await _performanceService.traceOperation(
      'translation_preload_common',
      () async {
        final commonTexts = [
          'Home',
          'Profile',
          'Settings',
          'Search',
          'Loading',
          'Error',
          'Success',
          'Save',
          'Cancel',
          'Edit',
          'Delete',
          'Add',
          'Remove',
          'View All',
          'Back',
          'Next',
          'Previous',
          'Continue',
          'Submit',
          'Upload',
          'Download',
          'Login',
          'Logout',
          'Register',
          'Forgot Password',
          'Reset Password',
          'Welcome',
          'Hello',
          'Goodbye',
          'Thank you',
          'Please wait',
          'Try again',
          'No results found',
          'Something went wrong',
          'Please try again later',
          'Connection error',
          'Invalid input',
          'Required field',
          'Optional',
        ];

        if (kDebugMode) {
          print('🔄 Preloading ${commonTexts.length} common translations...');
        }

        await translateBatch(commonTexts);

        if (kDebugMode) {
          print('✅ Preloading completed');
        }
      },
      attributes: {
        'category': 'translation',
        'operation': 'preload',
        'text_count': '40',
        'language': currentLanguageCode,
      },
    );
  }
}

/// Mixin for widgets that need translation capabilities
mixin TranslationMixin<T extends StatefulWidget> on State<T> {
  final EnhancedTranslationService _enhancedService =
      EnhancedTranslationService.instance;

  /// Translate text with automatic caching
  Future<String> translate(String text) async {
    return await _enhancedService.translateText(text);
  }

  /// Translate multiple texts
  Future<List<String>> translateMultiple(List<String> texts) async {
    return await _enhancedService.translateBatch(texts);
  }

  /// Translate API response
  Future<Map<String, dynamic>> translateApiData(
    Map<String, dynamic> data,
  ) async {
    return await _enhancedService.translateApiResponse(data);
  }

  /// Check if translation is needed
  bool get needsTranslation => _enhancedService.isTranslationNeeded;

  /// Current language code
  String get currentLanguage => _enhancedService.currentLanguageCode;
}
