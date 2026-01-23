import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

/// Service to manage HTTP cookies for authentication
/// Handles refresh_token and csrf_token sent via Set-Cookie headers
class CookieManager {
  static const String _refreshTokenKey = 'refresh_token_cookie';
  static const String _csrfTokenKey = 'csrf_token_cookie';

  /// Extract cookies from HTTP response headers
  /// Looks for Set-Cookie headers and stores them
  static Future<void> saveCookiesFromHeaders(
    Map<String, String> headers,
  ) async {
    try {
      // Look for Set-Cookie headers (can be lowercase or capitalized)
      final setCookieHeaders = headers.entries
          .where((entry) => entry.key.toLowerCase() == 'set-cookie')
          .map((entry) => entry.value)
          .toList();

      if (setCookieHeaders.isEmpty) {
        developer.log(
          '⚠️ CookieManager: No Set-Cookie headers found',
          name: 'CookieManager',
        );
        return;
      }

      developer.log(
        '🍪 CookieManager: Found ${setCookieHeaders.length} Set-Cookie headers',
        name: 'CookieManager',
      );

      for (final cookieHeader in setCookieHeaders) {
        await _parseSingleCookie(cookieHeader);
      }
    } catch (e) {
      developer.log(
        '❌ CookieManager: Error saving cookies: $e',
        name: 'CookieManager',
      );
    }
  }

  /// Parse a single Set-Cookie header and extract cookie name/value
  static Future<void> _parseSingleCookie(String cookieHeader) async {
    try {
      // Split by semicolon to get cookie parts
      final parts = cookieHeader.split(';');
      if (parts.isEmpty) return;

      // First part is always name=value
      final cookieNameValue = parts[0].trim();
      final separatorIndex = cookieNameValue.indexOf('=');
      if (separatorIndex == -1) return;

      final cookieName = cookieNameValue.substring(0, separatorIndex).trim();
      final cookieValue = cookieNameValue.substring(separatorIndex + 1).trim();

      developer.log(
        '🍪 CookieManager: Parsing cookie: $cookieName',
        name: 'CookieManager',
      );

      // Store specific cookies we care about
      if (cookieName.toLowerCase() == 'refresh_token' ||
          cookieName.toLowerCase() == 'refreshtoken') {
        await _saveRefreshTokenCookie(cookieValue);
        developer.log(
          '✅ CookieManager: Saved refresh_token cookie',
          name: 'CookieManager',
        );
      } else if (cookieName.toLowerCase() == 'csrf_token' ||
          cookieName.toLowerCase() == 'csrftoken') {
        await _saveCsrfTokenCookie(cookieValue);
        developer.log(
          '✅ CookieManager: Saved csrf_token cookie',
          name: 'CookieManager',
        );
      }
    } catch (e) {
      developer.log(
        '❌ CookieManager: Error parsing cookie: $e',
        name: 'CookieManager',
      );
    }
  }

  /// Save refresh token cookie to SharedPreferences
  static Future<void> _saveRefreshTokenCookie(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshTokenKey, value);
  }

  /// Save CSRF token cookie to SharedPreferences
  static Future<void> _saveCsrfTokenCookie(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_csrfTokenKey, value);
  }

  /// Get refresh token cookie
  static Future<String?> getRefreshTokenCookie() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  /// Get CSRF token cookie
  static Future<String?> getCsrfTokenCookie() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_csrfTokenKey);
  }

  /// Build Cookie header string for requests
  /// Returns format: "refresh_token=xxx; csrf_token=yyy"
  static Future<String?> buildCookieHeader() async {
    final refreshToken = await getRefreshTokenCookie();
    final csrfToken = await getCsrfTokenCookie();

    final cookies = <String>[];

    if (refreshToken != null) {
      cookies.add('refresh_token=$refreshToken');
    }

    if (csrfToken != null) {
      cookies.add('csrf_token=$csrfToken');
    }

    if (cookies.isEmpty) return null;

    final cookieHeader = cookies.join('; ');
    developer.log(
      '🍪 CookieManager: Built cookie header with ${cookies.length} cookies',
      name: 'CookieManager',
    );

    return cookieHeader;
  }

  /// Clear all stored cookies
  static Future<void> clearCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_csrfTokenKey);
      developer.log(
        '🧹 CookieManager: Cleared all cookies',
        name: 'CookieManager',
      );
    } catch (e) {
      developer.log(
        '❌ CookieManager: Error clearing cookies: $e',
        name: 'CookieManager',
      );
    }
  }

  /// Check if we have valid cookies stored
  static Future<bool> hasCookies() async {
    final refreshToken = await getRefreshTokenCookie();
    return refreshToken != null;
  }
}
