# App Version Check Feature

## Overview
This feature implements a version check mechanism that compares the current app version (from `pubspec.yaml`) with the minimum required version stored in Firebase Remote Config. If the app version is outdated, an indismissible fullscreen dialog is shown to prompt the user to update.

## Implementation Details

### Files Created/Modified

1. **`lib/utils/version_utils.dart`** (NEW)
   - Contains `VersionUtils` class with version comparison logic
   - `compareVersions()`: Compares two semantic version strings
   - `isVersionOutdated()`: Checks if current version is less than minimum required version

2. **`lib/widgets/outdated_version_dialog.dart`** (NEW)
   - Fullscreen indismissible dialog with glassmorphism effect
   - Matches the app's design language with gradient buttons and modern UI
   - Shows current version vs required version
   - Provides a button to download the update from the configured URL

3. **`lib/services/firebase_remote_config_service.dart`** (MODIFIED)
   - Added new keys: `min_store_app_version_android` and `min_store_app_version_ios`
   - Added default values: `'1.0.0'` for both platforms
   - Added getter methods: `getMinAppVersionAndroid()`, `getMinAppVersionIos()`, and `getMinVersion()`
   - `getMinVersion()` automatically detects the platform and returns the appropriate version

4. **`lib/screens/HomeScreen.dart`** (MODIFIED)
   - Added imports for `package_info_plus`, `version_utils`, and `outdated_version_dialog`
   - Added `_checkAppVersion()` method
   - Called `_checkAppVersion()` in `initState()`

## Firebase Remote Config Setup

### Required Parameters

In your Firebase Console, add the following Remote Config parameters:

1. **`min_store_app_version_android`** (String)
   - Description: Minimum required app version for Android devices
   - Default value: `"1.0.0"`
   - Example: `"1.2.0"`

2. **`min_store_app_version_ios`** (String)
   - Description: Minimum required app version for iOS devices
   - Default value: `"1.0.0"`
   - Example: `"1.2.0"`

3. **`app_download_url`** (String) - Already exists
   - Description: URL where users can download the latest version
   - For Android: `"https://play.google.com/store/apps/details?id=com.exanor.store"`
   - For iOS: `"https://apps.apple.com/app/id1234567890"`
   - Note: You can use a universal link or set up platform-specific links

### Platform-Specific Versioning

The app automatically detects the platform and uses the appropriate minimum version:
- **Android devices**: Uses `min_store_app_version_android`
- **iOS devices**: Uses `min_store_app_version_ios`
- **Other platforms** (web, desktop): Uses `min_store_app_version_android` as fallback

This allows you to enforce different minimum versions for Android and iOS independently.

## How It Works

1. When the HomeScreen initializes, `_checkAppVersion()` is called
2. The current app version is retrieved from `pubspec.yaml` using `package_info_plus`
3. The platform is detected (Android or iOS)
4. The appropriate minimum required version is fetched from Firebase Remote Config:
   - Android: `min_store_app_version_android`
   - iOS: `min_store_app_version_ios`
5. The download URL is fetched from Firebase Remote Config parameter `app_download_url`
6. Versions are compared using semantic versioning (e.g., 1.2.3):
   - Major.Minor.Patch comparison
   - Build numbers are ignored (e.g., `1.0.0+1` becomes `1.0.0`)
6. If current version < minimum version:
   - An indismissible fullscreen dialog is shown
   - User cannot dismiss it (back button disabled)
   - User must click "Download Update" to go to the download URL
7. If versions are equal or current version is newer, no dialog is shown

## Testing

### Test Case 1: App is Up to Date (Both Platforms)
```yaml
# pubspec.yaml
version: 1.0.0+1

# Firebase Remote Config
min_store_app_version_android: "1.0.0"
min_store_app_version_ios: "1.0.0"

# Result: No dialog shown on either platform ✅
```

### Test Case 2: Android App is Outdated
```yaml
# pubspec.yaml
version: 1.0.0+1

# Firebase Remote Config
min_store_app_version_android: "1.1.0"
min_store_app_version_ios: "1.0.0"

# Result: 
# - Android: Update dialog shown ⚠️
# - iOS: No dialog shown ✅
```

### Test Case 3: iOS App is Outdated
```yaml
# pubspec.yaml
version: 1.0.0+1

# Firebase Remote Config
min_store_app_version_android: "1.0.0"
min_store_app_version_ios: "1.2.0"

# Result: 
# - Android: No dialog shown ✅
# - iOS: Update dialog shown ⚠️
```

### Test Case 4: Both Platforms Outdated (Different Versions)
```yaml
# pubspec.yaml
version: 1.5.2+10

# Firebase Remote Config
min_store_app_version_android: "2.0.0"
min_store_app_version_ios: "2.1.0"

# Result: 
# - Android: Update dialog shown (requires 2.0.0) ⚠️
# - iOS: Update dialog shown (requires 2.1.0) ⚠️
```

## Version Format

The version comparison supports semantic versioning:
- Format: `MAJOR.MINOR.PATCH` (e.g., `1.2.3`)
- Build numbers are ignored (e.g., `1.0.0+1` → `1.0.0`)
- Each component is compared numerically
- Comparison order: Major → Minor → Patch

### Examples:
- `1.0.0` < `1.0.1` ✓
- `1.0.9` < `1.1.0` ✓
- `1.9.9` < `2.0.0` ✓
- `2.0.0` > `1.9.9` ✓
- `1.0.0+1` == `1.0.0+2` ✓ (build numbers ignored)

## UI Features

The update dialog includes:
- ✨ Glassmorphism background effect
- 🎨 Theme-aware design (light/dark mode)
- ⚠️ Warning icon with animated glow
- 📊 Version comparison chips showing current vs required
- 🔽 Gradient download button
- 🚫 Indismissible (cannot be closed)

## Error Handling

- If version checking fails (network error, parsing error, etc.), the app continues normally
- Errors are logged but don't block the user
- Default values of `"1.0.0"` are used for both platforms if Remote Config is unavailable

## Future Enhancements

Potential improvements:
1. Add support for conditional updates (optional vs forced)
2. Show release notes in the dialog
3. Add automatic download on Android
4. Add version check on app resume (not just on HomeScreen init)
5. Add analytics tracking for update prompts
6. Support different download URLs per platform (currently uses single URL)

## Notes

- The version check happens on HomeScreen initialization
- The dialog is shown using a post-frame callback to ensure proper widget tree building
- The dialog uses `PopScope(canPop: false)` to make it truly indismissible
- URL launcher opens the download URL in an external browser/app store
- **Platform-specific versioning**: You can set different minimum versions for Android and iOS, allowing independent version management for each platform
