import 'package:package_info_plus/package_info_plus.dart';

class VersionUtils {
  /// Compare two semantic version strings (e.g., '1.2.3' and '1.3.0')
  /// Returns:
  /// -1 if v1 < v2
  ///  0 if v1 == v2
  ///  1 if v1 > v2
  static int compareVersions(String v1, String v2) {
    // Strip build numbers (e.g., '1.0.0+1' -> '1.0.0')
    final cleanV1 = v1.split('+')[0];
    final cleanV2 = v2.split('+')[0];

    final parts1 = cleanV1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = cleanV2.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    // Pad with zeros to ensure they have the same number of parts
    final maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;
    while (parts1.length < maxLength) parts1.add(0);
    while (parts2.length < maxLength) parts2.add(0);

    for (int i = 0; i < maxLength; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }

    return 0; // Versions are equal
  }

  /// Checks if the current app version is less than the minimum required version
  static Future<bool> isVersionOutdated(String minRequiredVersion) async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;
      
      final comparisonResult = compareVersions(currentVersion, minRequiredVersion);
      return comparisonResult < 0; // Outdated if current < minimum
    } catch (e) {
      // In case of error (e.g., package_info_plus fails), we assume it's not outdated to not block the user
      print('Error checking app version: $e');
      return false;
    }
  }

  /// Helper to get current app version string
  static Future<String> getCurrentAppVersion() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      return "Unknown";
    }
  }
}
