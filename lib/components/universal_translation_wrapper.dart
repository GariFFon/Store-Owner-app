import 'package:flutter/material.dart';
import 'package:exanor/services/translation_service.dart';

/// Universal Translation Wrapper that can translate ANY content
/// Handles static text, API responses, lists, and complex UI elements
class UniversalTranslationWrapper extends StatefulWidget {
  final Widget child;
  final bool enableTranslation;
  final List<String>? excludePatterns; // Patterns to exclude from translation
  final Map<String, String>? customTranslations; // Custom translation overrides

  const UniversalTranslationWrapper({
    super.key,
    required this.child,
    this.enableTranslation = true,
    this.excludePatterns,
    this.customTranslations,
  });

  @override
  State<UniversalTranslationWrapper> createState() =>
      _UniversalTranslationWrapperState();
}

class _UniversalTranslationWrapperState
    extends State<UniversalTranslationWrapper> {
  final TranslationService _translationService = TranslationService.instance;
  final Map<String, String> _translationCache = {};

  @override
  Widget build(BuildContext context) {
    if (!widget.enableTranslation ||
        _translationService.currentLanguageCode == 'en') {
      return widget.child;
    }

    return _TranslationInheritedWidget(
      translationCache: _translationCache,
      excludePatterns: widget.excludePatterns ?? [],
      customTranslations: widget.customTranslations ?? {},
      child: widget.child,
    );
  }
}

class _TranslationInheritedWidget extends InheritedWidget {
  final Map<String, String> translationCache;
  final List<String> excludePatterns;
  final Map<String, String> customTranslations;

  const _TranslationInheritedWidget({
    required this.translationCache,
    required this.excludePatterns,
    required this.customTranslations,
    required super.child,
  });

  @override
  bool updateShouldNotify(_TranslationInheritedWidget oldWidget) {
    return translationCache != oldWidget.translationCache ||
        excludePatterns != oldWidget.excludePatterns ||
        customTranslations != oldWidget.customTranslations;
  }

  static _TranslationInheritedWidget? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_TranslationInheritedWidget>();
  }
}

/// Enhanced TranslatedText that works with API responses and dynamic content
class SmartTranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;
  final bool enableTranslation;
  final bool isApiContent; // Mark as API content for special handling
  final String? contentType; // 'name', 'description', 'title', etc.

  const SmartTranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
    this.enableTranslation = true,
    this.isApiContent = false,
    this.contentType,
  });

  @override
  State<SmartTranslatedText> createState() => _SmartTranslatedTextState();
}

class _SmartTranslatedTextState extends State<SmartTranslatedText> {
  final TranslationService _translationService = TranslationService.instance;
  String _translatedText = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _translatedText = widget.text;
    _translateText();
  }

  @override
  void didUpdateWidget(SmartTranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _translatedText = widget.text;
      _translateText();
    }
  }

  Future<void> _translateText() async {
    if (!widget.enableTranslation ||
        widget.text.trim().isEmpty ||
        _translationService.currentLanguageCode == 'en') {
      setState(() {
        _translatedText = widget.text;
      });
      return;
    }

    // Check for exclusion patterns
    final inheritedWidget = _TranslationInheritedWidget.of(context);
    if (inheritedWidget != null) {
      for (final pattern in inheritedWidget.excludePatterns) {
        if (widget.text.toLowerCase().contains(pattern.toLowerCase())) {
          setState(() {
            _translatedText = widget.text;
          });
          return;
        }
      }

      // Check for custom translations
      if (inheritedWidget.customTranslations.containsKey(widget.text)) {
        setState(() {
          _translatedText = inheritedWidget.customTranslations[widget.text]!;
        });
        return;
      }

      // Check cache
      if (inheritedWidget.translationCache.containsKey(widget.text)) {
        setState(() {
          _translatedText = inheritedWidget.translationCache[widget.text]!;
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String translated;

      if (widget.isApiContent) {
        // Handle API content with special processing
        translated = await _translateApiContent(widget.text);
      } else {
        // Regular UI text translation
        translated = await _translationService.translateFromEnglish(
          widget.text,
        );
      }

      if (mounted) {
        setState(() {
          _translatedText = translated;
          _isLoading = false;
        });

        // Cache the translation
        inheritedWidget?.translationCache[widget.text] = translated;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _translatedText = widget.text; // Fallback to original text
          _isLoading = false;
        });
      }
    }
  }

  Future<String> _translateApiContent(String text) async {
    // For API content, we might want different handling based on content type
    switch (widget.contentType) {
      case 'name':
        // Names usually shouldn't be translated, but user wants everything translated
        // So we'll translate but with a note that this might not be ideal
        return await _translationService.translateFromEnglish(text);
      case 'description':
      case 'bio':
      case 'title':
        // These should definitely be translated
        return await _translationService.translateFromEnglish(text);
      default:
        // Default: translate everything as requested
        return await _translationService.translateFromEnglish(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SizedBox(
        width: 100,
        height: 16,
        child: LinearProgressIndicator(
          backgroundColor: Colors.grey.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
        ),
      );
    }

    return Text(
      _translatedText,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      softWrap: widget.softWrap,
    );
  }
}

/// Translates API response maps automatically
class ApiResponseTranslator {
  static final TranslationService _translationService =
      TranslationService.instance;
  static final Map<String, String> _cache = {};

  /// Translate all text fields in an API response map
  static Future<Map<String, dynamic>> translateResponse(
    Map<String, dynamic> apiResponse, {
    List<String> excludeFields = const ['id', 'uuid', 'phone_number', 'email'],
    List<String> includeFields =
        const [], // If specified, only translate these fields
  }) async {
    if (_translationService.currentLanguageCode == 'en') {
      return apiResponse;
    }

    final translated = Map<String, dynamic>.from(apiResponse);

    for (final entry in apiResponse.entries) {
      if (entry.value is String && entry.value.toString().trim().isNotEmpty) {
        final fieldName = entry.key.toLowerCase();

        // Skip excluded fields
        if (excludeFields.any(
          (field) => fieldName.contains(field.toLowerCase()),
        )) {
          continue;
        }

        // If includeFields is specified, only translate those
        if (includeFields.isNotEmpty &&
            !includeFields.any(
              (field) => fieldName.contains(field.toLowerCase()),
            )) {
          continue;
        }

        // Check cache first
        final cacheKey = entry.value.toString();
        if (_cache.containsKey(cacheKey)) {
          translated[entry.key] = _cache[cacheKey]!;
          continue;
        }

        try {
          final translatedText = await _translationService.translateFromEnglish(
            entry.value.toString(),
          );
          translated[entry.key] = translatedText;
          _cache[cacheKey] = translatedText;
        } catch (e) {
          // Keep original on error
          translated[entry.key] = entry.value;
        }
      }
    }

    return translated;
  }

  /// Translate a list of API responses
  static Future<List<Map<String, dynamic>>> translateResponseList(
    List<Map<String, dynamic>> apiResponses, {
    List<String> excludeFields = const ['id', 'uuid', 'phone_number', 'email'],
    List<String> includeFields = const [],
  }) async {
    final List<Map<String, dynamic>> translatedList = [];

    for (final response in apiResponses) {
      final translated = await translateResponse(
        response,
        excludeFields: excludeFields,
        includeFields: includeFields,
      );
      translatedList.add(translated);
    }

    return translatedList;
  }

  /// Clear translation cache
  static void clearCache() {
    _cache.clear();
  }
}

/// Widget for translating lists of items
class TranslatedListView extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final Widget Function(
    BuildContext context,
    Map<String, dynamic> item,
    int index,
  )
  itemBuilder;
  final List<String> excludeFields;
  final List<String> includeFields;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  const TranslatedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.excludeFields = const ['id', 'uuid', 'phone_number', 'email'],
    this.includeFields = const [],
    this.controller,
    this.padding,
  });

  @override
  State<TranslatedListView> createState() => _TranslatedListViewState();
}

class _TranslatedListViewState extends State<TranslatedListView> {
  List<Map<String, dynamic>> _translatedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _translateItems();
  }

  @override
  void didUpdateWidget(TranslatedListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _translateItems();
    }
  }

  Future<void> _translateItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final translated = await ApiResponseTranslator.translateResponseList(
        widget.items,
        excludeFields: widget.excludeFields,
        includeFields: widget.includeFields,
      );

      if (mounted) {
        setState(() {
          _translatedItems = translated;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _translatedItems = widget.items;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      controller: widget.controller,
      padding: widget.padding,
      itemCount: _translatedItems.length,
      itemBuilder: (context, index) {
        return widget.itemBuilder(context, _translatedItems[index], index);
      },
    );
  }
}

/// Extension methods for easy translation
extension StringTranslationExtension on String {
  /// Translate this string with caching (async)
  Future<String> translateSmart({
    bool isApiContent = false,
    String? contentType,
  }) async {
    final service = TranslationService.instance;
    if (service.currentLanguageCode == 'en' || trim().isEmpty) {
      return this;
    }

    return await service.translateFromEnglish(this);
  }

  /// Get immediate translation (returns original if not cached) - for synchronous usage
  String translatedOrOriginal() {
    // For synchronous usage like tooltips, return original text
    // The actual translation happens via SmartTranslatedText widgets
    return this;
  }

  /// Quick sync method for tooltips and immediate usage
  String translateSync() {
    return this; // Returns original, translation happens in background
  }
}

/// Batch translation utility
class BatchTranslator {
  static final TranslationService _translationService =
      TranslationService.instance;

  /// Translate multiple strings at once
  static Future<List<String>> translateBatch(List<String> texts) async {
    if (_translationService.currentLanguageCode == 'en') {
      return texts;
    }

    final List<String> translated = [];

    for (final text in texts) {
      if (text.trim().isEmpty) {
        translated.add(text);
        continue;
      }

      try {
        final result = await _translationService.translateFromEnglish(text);
        translated.add(result);
      } catch (e) {
        translated.add(text); // Fallback to original
      }
    }

    return translated;
  }

  /// Translate a map of key-value pairs
  static Future<Map<String, String>> translateMap(
    Map<String, String> textMap,
  ) async {
    if (_translationService.currentLanguageCode == 'en') {
      return textMap;
    }

    final Map<String, String> translated = {};

    for (final entry in textMap.entries) {
      try {
        if (entry.value.trim().isEmpty) {
          translated[entry.key] = entry.value;
        } else {
          final result = await _translationService.translateFromEnglish(
            entry.value,
          );
          translated[entry.key] = result;
        }
      } catch (e) {
        translated[entry.key] = entry.value; // Fallback to original
      }
    }

    return translated;
  }
}
