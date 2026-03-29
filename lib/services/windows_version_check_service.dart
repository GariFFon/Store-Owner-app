import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:exanor/utils/platform_helper.dart';

/// Service to check for app updates on Windows (where Firebase Remote Config is not available).
/// 
/// HOW IT WORKS:
/// 1. Host a JSON file at your server URL (e.g., https://exanor.com/store-app-version.json)
/// 2. The JSON file contains: { "min_version": "1.0.1", "latest_version": "1.0.2", "download_url": "https://...", "release_notes": "..." }
/// 3. On app startup, this service fetches the JSON and compares versions
/// 4. If the app is outdated, it shows an update dialog
///
/// HOW TO PUSH AN UPDATE:
/// 1. Build the new Windows app: flutter build windows
/// 2. Create installer with Inno Setup (update version in installer.iss)
/// 3. Upload the installer to your server
/// 4. Update the JSON file with the new version and download URL
class WindowsVersionCheckService {
  // 🔧 CHANGE THIS to your actual hosted JSON URL
  static const String _versionCheckUrl =
      'https://exanor.com/api/store-app-version.json';

  // Fallback download URL if not provided in JSON
  static const String _fallbackDownloadUrl = 'https://exanor.com/download';

  /// Check for updates on Windows platform.
  /// Call this during app startup (e.g., in SplashScreen._initializeApp).
  /// Returns true if an update is required and dialog was shown.
  static Future<bool> checkForUpdates(BuildContext context) async {
    // Only run on Windows
    if (!PlatformHelper.isWindows) {
      developer.log(
        '⏭️ WindowsVersionCheck: Not Windows, skipping',
        name: 'WindowsVersionCheck',
      );
      return false;
    }

    try {
      developer.log(
        '🔍 WindowsVersionCheck: Checking for updates...',
        name: 'WindowsVersionCheck',
      );

      final versionInfo = await _fetchVersionInfo();
      if (versionInfo == null) {
        developer.log(
          '⚠️ WindowsVersionCheck: Could not fetch version info',
          name: 'WindowsVersionCheck',
        );
        return false;
      }

      final String currentVersion = _getCurrentAppVersion();
      final String minVersion = versionInfo['min_version'] ?? '1.0.0';
      final String latestVersion =
          versionInfo['latest_version'] ?? minVersion;
      final String downloadUrl =
          versionInfo['download_url'] ?? _fallbackDownloadUrl;
      final String releaseNotes =
          versionInfo['release_notes'] ?? 'A new version is available.';
      final bool forceUpdate = versionInfo['force_update'] ?? false;

      developer.log(
        '📊 WindowsVersionCheck: Current=$currentVersion, Min=$minVersion, Latest=$latestVersion',
        name: 'WindowsVersionCheck',
      );

      // Check if current version is below minimum required version
      final bool isBelowMinimum = _isVersionLower(currentVersion, minVersion);
      // Check if a newer version is available (optional update)
      final bool isUpdateAvailable =
          _isVersionLower(currentVersion, latestVersion);

      if (isBelowMinimum || forceUpdate) {
        developer.log(
          '🚨 WindowsVersionCheck: FORCED update required! ($currentVersion < $minVersion)',
          name: 'WindowsVersionCheck',
        );
        if (context.mounted) {
          await _showUpdateDialog(
            context,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes,
            isForced: true,
          );
        }
        return true;
      } else if (isUpdateAvailable) {
        developer.log(
          '💡 WindowsVersionCheck: Optional update available ($currentVersion → $latestVersion)',
          name: 'WindowsVersionCheck',
        );
        if (context.mounted) {
          await _showUpdateDialog(
            context,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes,
            isForced: false,
          );
        }
        return true;
      }

      developer.log(
        '✅ WindowsVersionCheck: App is up to date!',
        name: 'WindowsVersionCheck',
      );
      return false;
    } catch (e) {
      developer.log(
        '❌ WindowsVersionCheck: Error checking for updates: $e',
        name: 'WindowsVersionCheck',
      );
      return false;
    }
  }

  /// Fetch version info JSON from your server
  static Future<Map<String, dynamic>?> _fetchVersionInfo() async {
    try {
      final response = await http
          .get(Uri.parse(_versionCheckUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        developer.log(
          '✅ WindowsVersionCheck: Fetched version info: $data',
          name: 'WindowsVersionCheck',
        );
        return data;
      } else {
        developer.log(
          '❌ WindowsVersionCheck: Server returned ${response.statusCode}',
          name: 'WindowsVersionCheck',
        );
        return null;
      }
    } catch (e) {
      developer.log(
        '❌ WindowsVersionCheck: Network error: $e',
        name: 'WindowsVersionCheck',
      );
      return null;
    }
  }

  /// Get the current app version from pubspec.yaml (compiled into the app)
  /// This reads from the app's package info.
  /// For now, we hardcode it — you should replace this with package_info_plus.
  static String _getCurrentAppVersion() {
    // TODO: Replace with PackageInfo.fromPlatform() once package_info_plus is added
    // For now, this matches pubspec.yaml version: 1.0.1+2
    return '1.0.1';
  }

  /// Compare two semantic version strings.
  /// Returns true if version1 < version2.
  static bool _isVersionLower(String version1, String version2) {
    try {
      final v1Parts = version1.split('.').map(int.parse).toList();
      final v2Parts = version2.split('.').map(int.parse).toList();

      // Pad shorter version with zeros
      while (v1Parts.length < 3) {
        v1Parts.add(0);
      }
      while (v2Parts.length < 3) {
        v2Parts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (v1Parts[i] < v2Parts[i]) return true;
        if (v1Parts[i] > v2Parts[i]) return false;
      }

      return false; // Versions are equal
    } catch (e) {
      developer.log(
        '❌ WindowsVersionCheck: Error comparing versions "$version1" vs "$version2": $e',
        name: 'WindowsVersionCheck',
      );
      return false;
    }
  }

  /// Show the update dialog
  static Future<void> _showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    required String downloadUrl,
    required String releaseNotes,
    required bool isForced,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: !isForced,
      builder: (BuildContext dialogContext) {
        final theme = Theme.of(dialogContext);
        final isDark = theme.brightness == Brightness.dark;

        return WillPopScope(
          onWillPop: () async => !isForced,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isForced
                              ? [const Color(0xFFFF6B6B), const Color(0xFFEE5A24)]
                              : [const Color(0xFF6C63FF), const Color(0xFF3F3D8E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: (isForced
                                    ? const Color(0xFFFF6B6B)
                                    : const Color(0xFF6C63FF))
                                .withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        isForced
                            ? Icons.system_update_alt_rounded
                            : Icons.update_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Title
                    Text(
                      isForced ? 'Update Required' : 'Update Available',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Version info
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'v$currentVersion',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.grey.shade400,
                              size: 18,
                            ),
                          ),
                          Text(
                            'v$latestVersion',
                            style: TextStyle(
                              color: isForced
                                  ? const Color(0xFFEE5A24)
                                  : const Color(0xFF6C63FF),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Release notes
                    Text(
                      releaseNotes,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),

                    if (isForced) ...[
                      const SizedBox(height: 8),
                      Text(
                        'You must update to continue using the app.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFEE5A24),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Buttons
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => _openDownloadUrl(downloadUrl),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isForced
                              ? const Color(0xFFEE5A24)
                              : const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Download Update',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (!isForced) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: TextButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Later',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Open the download URL in the default browser
  static Future<void> _openDownloadUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        developer.log(
          '🌐 WindowsVersionCheck: Opened download URL: $url',
          name: 'WindowsVersionCheck',
        );
      } else {
        developer.log(
          '❌ WindowsVersionCheck: Cannot launch URL: $url',
          name: 'WindowsVersionCheck',
        );
      }
    } catch (e) {
      developer.log(
        '❌ WindowsVersionCheck: Error opening URL: $e',
        name: 'WindowsVersionCheck',
      );
    }
  }
}
