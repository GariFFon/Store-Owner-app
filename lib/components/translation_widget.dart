import 'package:flutter/material.dart';
import 'package:exanor/services/translation_service.dart';

/// A widget that automatically translates text based on the current language
class TranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool softWrap;
  final bool enableTranslation;

  const TranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap = true,
    this.enableTranslation = true,
  });

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
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
  void didUpdateWidget(TranslatedText oldWidget) {
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

    setState(() {
      _isLoading = true;
    });

    try {
      final translated = await _translationService.translateFromEnglish(
        widget.text,
      );
      if (mounted) {
        setState(() {
          _translatedText = translated;
          _isLoading = false;
        });
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

/// A simple language toggle button with current language indicator
class LanguageButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final double? size;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const LanguageButton({
    super.key,
    this.onPressed,
    this.size = 48,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final translationService = TranslationService.instance;
    final currentLanguage = translationService.currentLanguage;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular((size ?? 48) / 2),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentLanguage.flag,
                    style: TextStyle(fontSize: (size ?? 48) * 0.4),
                  ),
                  Text(
                    currentLanguage.code.toUpperCase(),
                    style: TextStyle(
                      fontSize: (size ?? 48) * 0.15,
                      fontWeight: FontWeight.w600,
                      color: foregroundColor ?? theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (currentLanguage.code != 'en')
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A floating action button for language selection
class LanguageFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool mini;

  const LanguageFAB({super.key, this.onPressed, this.mini = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final translationService = TranslationService.instance;
    final currentLanguage = translationService.currentLanguage;

    return FloatingActionButton(
      onPressed: onPressed,
      mini: mini,
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      elevation: 4,
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentLanguage.flag,
                  style: TextStyle(fontSize: mini ? 16 : 20),
                ),
                if (!mini)
                  Text(
                    currentLanguage.code.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (currentLanguage.code != 'en')
            Positioned(
              top: mini ? 4 : 6,
              right: mini ? 4 : 6,
              child: Container(
                width: mini ? 6 : 8,
                height: mini ? 6 : 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Extension methods for easy translation
extension TranslationExtension on String {
  /// Returns a TranslatedText widget for this string
  Widget translated({
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
    bool softWrap = true,
    bool enableTranslation = true,
  }) {
    return TranslatedText(
      this,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      enableTranslation: enableTranslation,
    );
  }

  /// Translate this string using the translation service
  Future<String> translate() async {
    return await TranslationService.instance.translateFromEnglish(this);
  }
}
