import 'package:shared_preferences/shared_preferences.dart';

/// Shared-preference keys and helpers for the on-screen keyboard feature.
///
/// The keyboard is only ever shown on tablet / desktop screens (≥600 px wide),
/// and only when [isEnabled] returns `true` (user has turned the toggle on in
/// Layout Settings). It defaults to **off** so existing users are not surprised.
///
/// Width and position are persisted so the keyboard opens in the same place
/// and at the same size the user last used.
class OnscreenKeyboardPrefs {
  OnscreenKeyboardPrefs._();

  // ── Keys ─────────────────────────────────────────────────────────────────
  static const String _enabledKey = 'pos_use_onscreen_keyboard';
  static const String _widthKey = 'pos_keyboard_width';
  static const String _alignXKey = 'pos_keyboard_align_x';
  static const String _alignYKey = 'pos_keyboard_align_y';

  // ── Enabled toggle ───────────────────────────────────────────────────────

  /// Returns whether the on-screen keyboard is enabled by the user.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// Persists the user's preference.
  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  // ── Width ────────────────────────────────────────────────────────────────

  /// Returns the last-saved keyboard width, or `null` to use the default.
  static Future<double?> getWidth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_widthKey);
  }

  /// Persists the keyboard width.
  static Future<void> setWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_widthKey, width);
  }

  // ── Position (0.0 – 1.0 normalised) ─────────────────────────────────────

  /// Returns the last-saved position as `(alignX, alignY)`, or `null`.
  static Future<(double, double)?> getPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble(_alignXKey);
    final y = prefs.getDouble(_alignYKey);
    if (x == null || y == null) return null;
    return (x, y);
  }

  /// Persists the keyboard position.
  static Future<void> setPosition(double x, double y) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_alignXKey, x);
    await prefs.setDouble(_alignYKey, y);
  }
}
