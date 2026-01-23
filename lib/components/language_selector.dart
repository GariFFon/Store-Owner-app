import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:exanor/services/translation_service.dart';
import 'package:exanor/components/translation_diagnostics.dart';
import 'package:exanor/components/translation_test_widget.dart';
import 'package:exanor/components/translation_integration_guide.dart';
import 'package:exanor/guides/universal_translation_integration_guide.dart';
import 'package:exanor/examples/comprehensive_translation_example.dart';

class LanguageSelector extends StatefulWidget {
  final Function(SupportedLanguage)? onLanguageSelected;
  final bool showOnlyIndianLanguages;
  final String searchHint;
  final bool navigateToSplashOnSelection;

  const LanguageSelector({
    super.key,
    this.onLanguageSelected,
    this.showOnlyIndianLanguages = false,
    this.searchHint = 'Search languages...',
    this.navigateToSplashOnSelection = false,
  });

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  final TextEditingController _searchController = TextEditingController();
  List<SupportedLanguage> _filteredLanguages = [];
  final TranslationService _translationService = TranslationService.instance;
  Map<String, bool> _downloadedLanguages = {};
  Map<String, double> _downloadProgress = {};
  bool _showHelperTools = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));

    _initializeLanguages();

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initializeLanguages() {
    final languages = widget.showOnlyIndianLanguages
        ? _translationService.indianLanguages
        : _translationService.availableLanguages;

    setState(() {
      _filteredLanguages = languages;
    });

    _checkDownloadedLanguages();
  }

  Future<void> _checkDownloadedLanguages() async {
    final Map<String, bool> downloadedStatus = {};

    for (final language in _filteredLanguages) {
      try {
        final isDownloaded = await _translationService
            .isLanguageModelDownloaded(language.code);
        downloadedStatus[language.code] = isDownloaded;
      } catch (e) {
        // If check fails, assume not downloaded
        downloadedStatus[language.code] = false;
      }
    }

    if (mounted) {
      setState(() {
        _downloadedLanguages = downloadedStatus;
      });
    }
  }

  /// Force refresh downloaded languages status
  Future<void> _refreshDownloadedStatus() async {
    await _checkDownloadedLanguages();
  }

  void _filterLanguages(String query) {
    final languages = widget.showOnlyIndianLanguages
        ? _translationService.indianLanguages
        : _translationService.availableLanguages;

    setState(() {
      if (query.isEmpty) {
        _filteredLanguages = languages;
      } else {
        _filteredLanguages = languages
            .where(
              (language) =>
                  language.name.toLowerCase().contains(query.toLowerCase()) ||
                  language.nativeName.toLowerCase().contains(
                    query.toLowerCase(),
                  ) ||
                  language.code.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  Future<void> _downloadLanguageModel(SupportedLanguage language) async {
    try {
      setState(() {
        _downloadedLanguages[language.code] = false;
        _downloadProgress[language.code] = 0.0;
      });

      // Simulate download progress for better UX (only to 90%)
      for (int i = 0; i <= 90; i += 10) {
        if (mounted) {
          setState(() {
            _downloadProgress[language.code] = i / 100.0;
          });
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      // Complete progress to 95% before actual download
      if (mounted) {
        setState(() {
          _downloadProgress[language.code] = 0.95;
        });
      }

      final success = await _translationService.downloadLanguageModel(
        language.code,
      );

      if (mounted) {
        // Set progress to 100% briefly to show completion
        setState(() {
          _downloadProgress[language.code] = 1.0;
        });

        // Small delay to show 100% completion
        await Future.delayed(const Duration(milliseconds: 200));

        // Now update final state atomically
        setState(() {
          _downloadedLanguages[language.code] = success;
          _downloadProgress.remove(language.code);
        });

        // Force refresh downloaded status to ensure consistency
        await _refreshDownloadedStatus();

        if (success) {
          // Show success message and update UI to show select button
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '✨ ${language.name} downloaded successfully! You can now select it.',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to download ${language.name} model'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadedLanguages[language.code] = false;
          _downloadProgress.remove(language.code);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading ${language.name}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _selectLanguage(SupportedLanguage language) async {
    HapticFeedback.mediumImpact();

    final isDownloaded = _downloadedLanguages[language.code] ?? false;
    if (!isDownloaded && language.code != 'en') {
      final shouldDownload = await _showDownloadDialog(language);
      if (shouldDownload) {
        await _downloadLanguageModel(language);
      }
      return;
    }

    try {
      // Add timeout to prevent hanging
      final success = await Future.any([
        _translationService.changeLanguage(language.code),
        Future.delayed(const Duration(seconds: 10), () => false),
      ]);

      if (success && mounted) {
        widget.onLanguageSelected?.call(language);

        // Always navigate to splash screen after language selection
        Navigator.of(context).pop(); // Dismiss bottom sheet first
        await Future.delayed(const Duration(milliseconds: 100)); // Small delay
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/restart_app');
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to change language to ${language.name}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing language: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<bool> _showDownloadDialog(SupportedLanguage language) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Text(language.flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(child: Text('Download ${language.name}?')),
              ],
            ),
            content: Text(
              'The ${language.name} language model needs to be downloaded before use. This may take a few moments.',
              style: const TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Download'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _fadeAnimation,
        _slideAnimation,
        _scaleAnimation,
      ]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                height: screenSize.height * 0.9,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDarkMode
                              ? [
                                  Colors.grey[900]!.withOpacity(0.95),
                                  Colors.grey[800]!.withOpacity(0.9),
                                ]
                              : [
                                  Colors.white.withOpacity(0.95),
                                  Colors.grey[50]!.withOpacity(0.9),
                                ],
                        ),
                        border: Border.all(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildHeader(theme, isDarkMode),
                          _buildSearchSection(theme, isDarkMode),
                          if (_showHelperTools)
                            _buildHelperTools(theme, isDarkMode),
                          Expanded(
                            child: _buildLanguageList(theme, isDarkMode),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 24),

          // Title section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.language, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.showOnlyIndianLanguages
                          ? 'Indian Languages'
                          : 'Choose Language',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Translate your entire app experience',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.7)
                            : Colors.black.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeaderButton(
                    icon: _showHelperTools
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    onPressed: () {
                      setState(() {
                        _showHelperTools = !_showHelperTools;
                      });
                      HapticFeedback.lightImpact();
                    },
                    tooltip: _showHelperTools
                        ? 'Hide Tools'
                        : 'Show Helper Tools',
                    theme: theme,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(width: 8),
                  _buildHeaderButton(
                    icon: Icons.close,
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                    theme: theme,
                    isDarkMode: isDarkMode,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    required ThemeData theme,
    required bool isDarkMode,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
              ),
            ),
            child: Icon(
              icon,
              color: isDarkMode ? Colors.white : Colors.black87,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSection(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDarkMode
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _filterLanguages,
          decoration: InputDecoration(
            hintText: widget.searchHint,
            hintStyle: TextStyle(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.5)
                  : Colors.black.withOpacity(0.5),
              fontSize: 16,
            ),
            prefixIcon: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.search,
                color: isDarkMode
                    ? Colors.white.withOpacity(0.6)
                    : Colors.black.withOpacity(0.6),
                size: 22,
              ),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.6)
                          : Colors.black.withOpacity(0.6),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _filterLanguages('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildHelperTools(ThemeData theme, bool isDarkMode) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Translation Tools',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.9)
                  : Colors.black.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Commented out as requested by user
              // _buildToolChip(
              //   icon: Icons.integration_instructions,
              //   label: 'Basic Guide',
              //   color: Colors.purple,
              //   onTap: () {
              //     Navigator.of(context).pop();
              //     showTranslationIntegrationGuide(context);
              //   },
              // ),
              // _buildToolChip(
              //   icon: Icons.translate,
              //   label: 'Universal Guide',
              //   color: Colors.orange,
              //   onTap: () {
              //     Navigator.of(context).pop();
              //     showUniversalTranslationGuide(context);
              //   },
              // ),
              // _buildToolChip(
              //   icon: Icons.view_list,
              //   label: 'Live Example',
              //   color: Colors.teal,
              //   onTap: () {
              //     Navigator.of(context).pop();
              //     showComprehensiveTranslationExample(context);
              //   },
              // ),
              _buildToolChip(
                icon: Icons.play_arrow,
                label: 'Test Download',
                color: Colors.green,
                onTap: () {
                  Navigator.of(context).pop();
                  showTranslationTest(context);
                },
              ),
              _buildToolChip(
                icon: Icons.help_outline,
                label: 'Diagnostics',
                color: theme.colorScheme.primary,
                onTap: () {
                  Navigator.of(context).pop();
                  showTranslationDiagnostics(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageList(ThemeData theme, bool isDarkMode) {
    if (_filteredLanguages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: isDarkMode
                  ? Colors.white.withOpacity(0.3)
                  : Colors.black.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No languages found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.7)
                    : Colors.black.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your search',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.5)
                    : Colors.black.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      itemCount: _filteredLanguages.length,
      itemBuilder: (context, index) {
        final language = _filteredLanguages[index];
        final isDownloaded =
            _downloadedLanguages[language.code] ??
            (language.code == 'en'); // English is always available
        final downloadProgress = _downloadProgress[language.code];
        final isCurrentLanguage =
            language.code == _translationService.currentLanguageCode;

        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 200 + (index * 50)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: _buildLanguageCard(
                  language: language,
                  isDownloaded: isDownloaded,
                  downloadProgress: downloadProgress,
                  isCurrentLanguage: isCurrentLanguage,
                  theme: theme,
                  isDarkMode: isDarkMode,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLanguageCard({
    required SupportedLanguage language,
    required bool isDownloaded,
    required double? downloadProgress,
    required bool isCurrentLanguage,
    required ThemeData theme,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isCurrentLanguage
            ? LinearGradient(
                colors: [
                  theme.colorScheme.primary.withOpacity(0.15),
                  theme.colorScheme.primary.withOpacity(0.05),
                ],
              )
            : null,
        color: isCurrentLanguage
            ? null
            : isDarkMode
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.7),
        border: Border.all(
          color: isCurrentLanguage
              ? theme.colorScheme.primary.withOpacity(0.4)
              : isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.08),
          width: isCurrentLanguage ? 2 : 1,
        ),
        boxShadow: [
          if (isCurrentLanguage)
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectLanguage(language),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Language image and flag
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.05),
                  ),
                  child: ClipOval(
                    child: language.imageUrl != null
                        ? Image.network(
                            language.imageUrl!,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                                  child: Text(
                                    language.flag,
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ),
                          )
                        : Center(
                            child: Text(
                              language.flag,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // Language info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: isDarkMode ? Colors.white : Colors.black87,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        language.nativeName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDarkMode
                              ? Colors.white.withOpacity(0.7)
                              : Colors.black.withOpacity(0.6),
                          fontSize: 15,
                        ),
                      ),
                      if (downloadProgress != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: downloadProgress,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary,
                                    theme.colorScheme.primary.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Status/Action
                _buildLanguageStatus(
                  language: language,
                  isDownloaded: isDownloaded,
                  downloadProgress: downloadProgress,
                  isCurrentLanguage: isCurrentLanguage,
                  theme: theme,
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageStatus({
    required SupportedLanguage language,
    required bool isDownloaded,
    required double? downloadProgress,
    required bool isCurrentLanguage,
    required ThemeData theme,
    required bool isDarkMode,
  }) {
    // If this is the current language, always show "Current" status
    if (isCurrentLanguage) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              'Current',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    // If download is in progress, show progress indicator
    if (downloadProgress != null) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.primary.withOpacity(0.1),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              value: downloadProgress,
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      );
    }

    // If English or model is downloaded, show "Select" button
    if (language.code == 'en' || isDownloaded) {
      return GestureDetector(
        onTap: () => _selectLanguage(language),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green, Colors.green.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Text(
                'Select',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default: show download button
    return GestureDetector(
      onTap: () => _downloadLanguageModel(language),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.15),
              theme.colorScheme.primary.withOpacity(0.05),
            ],
          ),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
        ),
        child: Icon(Icons.download, color: theme.colorScheme.primary, size: 20),
      ),
    );
  }
}

/// Enhanced Language Button with glassmorphism and animated gradient boundary
class EnhancedLanguageButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final EdgeInsets? margin;

  const EnhancedLanguageButton({super.key, this.onPressed, this.margin});

  @override
  State<EnhancedLanguageButton> createState() => _EnhancedLanguageButtonState();
}

class _EnhancedLanguageButtonState extends State<EnhancedLanguageButton>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _gradientAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _gradientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final translationService = TranslationService.instance;
    final currentLanguage = translationService.currentLanguage;

    return Container(
      margin: widget.margin ?? const EdgeInsets.all(16),
      child: AnimatedBuilder(
        animation: Listenable.merge([_gradientAnimation, _pulseAnimation]),
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDarkMode
                          ? [
                              Colors.white.withOpacity(0.15),
                              Colors.white.withOpacity(0.05),
                            ]
                          : [
                              Colors.white.withOpacity(0.8),
                              Colors.white.withOpacity(0.4),
                            ],
                    ),
                    border: Border.all(width: 2, color: Colors.transparent),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: [
                          _gradientAnimation.value * 0.3,
                          _gradientAnimation.value * 0.7,
                          _gradientAnimation.value,
                        ],
                        colors: [
                          const Color(
                            0xFF3B82F6,
                          ).withOpacity(0.3 * _pulseAnimation.value), // Blue
                          const Color(
                            0xFF8B5CF6,
                          ).withOpacity(0.4 * _pulseAnimation.value), // Purple
                          const Color(
                            0xFF3B82F6,
                          ).withOpacity(0.2 * _pulseAnimation.value), // Blue
                        ],
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: widget.onPressed,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Language image and flag
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.05),
                                ),
                                child: ClipOval(
                                  child: currentLanguage.imageUrl != null
                                      ? Image.network(
                                          currentLanguage.imageUrl!,
                                          width: 32,
                                          height: 32,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Center(
                                                    child: Text(
                                                      currentLanguage.flag,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                  ),
                                        )
                                      : Center(
                                          child: Text(
                                            currentLanguage.flag,
                                            style: const TextStyle(
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Language name in native language
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentLanguage.nativeName,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
                                            fontSize: 14,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      currentLanguage.name,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: isDarkMode
                                                ? Colors.white.withOpacity(0.7)
                                                : Colors.black.withOpacity(0.6),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Dropdown arrow
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.05),
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: isDarkMode
                                      ? Colors.white.withOpacity(0.8)
                                      : Colors.black.withOpacity(0.7),
                                ),
                              ),

                              // Active indicator if not English
                              if (currentLanguage.code != 'en')
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF3B82F6),
                                        const Color(0xFF8B5CF6),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF3B82F6,
                                        ).withOpacity(0.4),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Utility function to show language selector bottom sheet
Future<void> showLanguageSelector(
  BuildContext context, {
  Function(SupportedLanguage)? onLanguageSelected,
  bool showOnlyIndianLanguages = false,
  bool navigateToSplashOnSelection = false,
}) async {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => LanguageSelector(
      onLanguageSelected: onLanguageSelected,
      showOnlyIndianLanguages: showOnlyIndianLanguages,
      navigateToSplashOnSelection: navigateToSplashOnSelection,
    ),
  );
}
