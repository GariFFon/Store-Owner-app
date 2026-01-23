import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';

/// Enum for theme modes
enum AppThemeMode { light, dark, system }

/// Theme manager to handle theme switching and persistence with animations
class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  AppThemeMode _themeMode = AppThemeMode.system;
  bool _isAnimating = false;

  /// Current theme mode
  AppThemeMode get themeMode => _themeMode;

  /// Whether theme switching animation is in progress
  bool get isAnimating => _isAnimating;

  /// Animation duration for theme transitions
  static const Duration animationDuration = Duration(milliseconds: 400);

  /// Animation curve for theme transitions
  static const Curve animationCurve = Curves.easeInOutCubic;

  /// Get the current ThemeData based on the selected mode and system brightness
  ThemeData getTheme(BuildContext context) {
    switch (_themeMode) {
      case AppThemeMode.light:
        return AppTheme.lightTheme;
      case AppThemeMode.dark:
        return AppTheme.darkTheme;
      case AppThemeMode.system:
        final brightness = MediaQuery.of(context).platformBrightness;
        return brightness == Brightness.dark
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;
    }
  }

  /// Get the current ThemeMode for MaterialApp
  ThemeMode get materialThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// Check if current theme is dark
  bool isDark(BuildContext context) {
    switch (_themeMode) {
      case AppThemeMode.dark:
        return true;
      case AppThemeMode.light:
        return false;
      case AppThemeMode.system:
        return MediaQuery.of(context).platformBrightness == Brightness.dark;
    }
  }

  /// Set theme mode with animation
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode != mode && !_isAnimating) {
      _isAnimating = true;
      notifyListeners();

      // Add a small delay to show animation start
      await Future.delayed(const Duration(milliseconds: 50));

      _themeMode = mode;
      _updateSystemUIOverlay();
      notifyListeners();

      // Wait for animation to complete
      await Future.delayed(animationDuration);

      _isAnimating = false;
      notifyListeners();
    }
  }

  /// Set theme mode without animation (for initialization)
  void setThemeModeInstant(AppThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      _updateSystemUIOverlay();
      notifyListeners();
    }
  }

  /// Toggle between light and dark themes with animation
  Future<void> toggleTheme(BuildContext context) async {
    if (isDark(context)) {
      await setThemeMode(AppThemeMode.light);
    } else {
      await setThemeMode(AppThemeMode.dark);
    }
  }

  /// Update system UI overlay style based on current theme
  void _updateSystemUIOverlay() {
    // This will be called when theme changes to update status bar
    // The actual status bar color will be handled by the app
  }

  /// Initialize theme manager
  void initialize() {
    _updateSystemUIOverlay();
  }

  /// Get theme mode name for display
  String getThemeModeName() {
    switch (_themeMode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }

  /// Get all available theme modes
  List<AppThemeMode> get availableThemeModes => AppThemeMode.values;

  /// Get animation status text
  String getAnimationStatus() {
    return _isAnimating ? 'Switching theme...' : 'Theme ready';
  }
}
