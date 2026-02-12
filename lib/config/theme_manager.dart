import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Enum for theme modes
enum AppThemeMode { light, dark, system }

/// Theme manager to handle theme switching and persistence with animations
class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  AppThemeMode _themeMode = AppThemeMode.light;
  bool _isAnimating = false;

  /// Current theme mode
  AppThemeMode get themeMode => AppThemeMode.light;

  /// Whether theme switching animation is in progress
  bool get isAnimating => _isAnimating;

  /// Animation duration for theme transitions
  static const Duration animationDuration = Duration(milliseconds: 400);

  /// Animation curve for theme transitions
  static const Curve animationCurve = Curves.easeInOutCubic;

  /// Get the current ThemeData based on the selected mode and system brightness
  ThemeData getTheme(BuildContext context) {
    return AppTheme.lightTheme;
  }

  /// Get the current ThemeMode for MaterialApp
  ThemeMode get materialThemeMode {
    return ThemeMode.light;
  }

  /// Check if current theme is dark
  bool isDark(BuildContext context) {
    return false;
  }

  /// Set theme mode with animation
  Future<void> setThemeMode(AppThemeMode mode) async {
    // Theme switching is disabled
    return;
  }

  /// Set theme mode without animation (for initialization)
  void setThemeModeInstant(AppThemeMode mode) {
    // Theme switching is disabled
    return;
  }

  /// Toggle between light and dark themes with animation
  Future<void> toggleTheme(BuildContext context) async {
    // Theme switching is disabled
    return;
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
