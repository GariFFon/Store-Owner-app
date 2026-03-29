# Windows App Version Update System

## Overview

Since **Firebase Remote Config is not supported on Windows desktop**, the Exanor Store App uses a **custom HTTP-based version check** to handle updates on Windows. On app startup, the app fetches a JSON file from your server, compares versions, and shows an update dialog if needed.

---

## How It Works

### Flow Diagram

```
App Starts → SplashScreen → Fetch version JSON from server
                                    ↓
                            Compare versions
                                    ↓
                    ┌───────────────┼───────────────┐
                    ↓               ↓               ↓
              Up to date     Optional Update    Forced Update
                    ↓               ↓               ↓
            Continue to app   Show dialog       Show dialog
                              (dismissable)     (NOT dismissable)
                                    ↓               ↓
                              "Download" or   "Download" only
                              "Later"              ↓
                                    ↓         Opens browser
                              Opens browser   to download URL
                              to download URL
```

### Step-by-Step

1. **App launches** and the `SplashScreen` runs.
2. After the splash animation and config loading, `WindowsVersionCheckService.checkForUpdates()` is called.
3. The service makes an **HTTP GET** request to your hosted JSON URL.
4. It compares the app's current version against the `min_version` and `latest_version` from the JSON.
5. Based on the comparison:
   - **Current ≥ Latest** → App is up to date, no dialog shown.
   - **Current < Latest but ≥ Min** → Optional update dialog (user can tap "Later").
   - **Current < Min** → Forced update dialog (user MUST update, can't dismiss).
6. The **"Download Update"** button opens the download URL in the user's default browser.
7. User downloads and installs the new `.exe` installer.

---

## Server-Side Setup

### JSON File Format

Host a JSON file on your server. The app fetches this on every startup.

**URL:** `https://exanor.com/api/store-app-version.json` (configurable in code)

```json
{
  "min_version": "1.0.1",
  "latest_version": "1.0.2",
  "download_url": "https://exanor.com/downloads/ExanorStorePartner-Setup-1.0.2.exe",
  "release_notes": "Bug fixes and performance improvements.",
  "force_update": false
}
```

### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `min_version` | String | ✅ | Minimum allowed version. Users below this see a **forced** (undismissable) update dialog. |
| `latest_version` | String | ✅ | Newest available version. Users below this see an **optional** update dialog. |
| `download_url` | String | ✅ | Direct URL to the `.exe` installer. Opens in the user's browser. |
| `release_notes` | String | Optional | Message shown in the update dialog. Defaults to "A new version is available." |
| `force_update` | Boolean | Optional | If `true`, forces ALL users to update regardless of version. Defaults to `false`. |

### Hosting Options

**Option A — Static file on web server (Nginx/Apache):**
```
Place file at: /var/www/exanor.com/api/store-app-version.json
```

**Option B — Laravel API endpoint:**
```php
Route::get('/store-app-version', function () {
    return response()->json([
        'min_version' => '1.0.1',
        'latest_version' => '1.0.2',
        'download_url' => 'https://exanor.com/downloads/ExanorStorePartner-Setup-1.0.2.exe',
        'release_notes' => 'Bug fixes and performance improvements.',
        'force_update' => false,
    ]);
});
```

**Option C — Firebase Hosting:**
```
Place file at: public/api/store-app-version.json
Deploy with: firebase deploy --only hosting
```

---

## How to Release a New Windows Update

Follow these steps every time you want to push a new version to Windows users:

### 1. Update version numbers (3 places must match!)

**`pubspec.yaml`:**
```yaml
version: 1.0.2+3
```

**`installer.iss`:**
```ini
AppVersion=1.0.2
OutputBaseFilename=ExanorStorePartner-Setup-1.0.2
```

**`lib/services/windows_version_check_service.dart`:**
```dart
static String _getCurrentAppVersion() {
    return '1.0.2';
}
```

### 2. Build the Windows app
```powershell
flutter build windows --release
```

### 3. Create the installer with Inno Setup
```powershell
iscc installer.iss
```
Output: `installer_output/ExanorStorePartner-Setup-1.0.2.exe`

### 4. Upload the installer to your server
```bash
# Example: Upload to your downloads directory
scp installer_output/ExanorStorePartner-Setup-1.0.2.exe user@server:/var/www/exanor.com/downloads/
```

### 5. Update the version JSON on your server
```json
{
  "min_version": "1.0.1",
  "latest_version": "1.0.2",
  "download_url": "https://exanor.com/downloads/ExanorStorePartner-Setup-1.0.2.exe",
  "release_notes": "New features: improved printing, better UI.",
  "force_update": false
}
```

### 6. Done! 🎉
Next time any Windows user opens the app, they'll see the update dialog.

---

## What the User Sees

### Optional Update (current version is acceptable but not latest)
- Dialog title: **"Update Available"** (purple theme)
- Shows version change: `v1.0.1 → v1.0.2`
- Shows release notes
- Two buttons: **"Download Update"** and **"Later"**
- User can dismiss and continue using the app

### Forced Update (current version is below minimum)
- Dialog title: **"Update Required"** (red/orange theme)
- Shows version change: `v1.0.0 → v1.0.2`
- Shows release notes + "You must update to continue using the app."
- One button only: **"Download Update"**
- Dialog CANNOT be dismissed — no "Later" button, back button disabled

### App is Up to Date
- No dialog, app goes straight to the main screen

---

## Example Scenarios

### Scenario 1: Regular Feature Update
```json
{
  "min_version": "1.0.0",
  "latest_version": "1.0.2",
  "download_url": "https://exanor.com/downloads/ExanorStorePartner-Setup-1.0.2.exe",
  "release_notes": "New features: better reports and improved speed.",
  "force_update": false
}
```
Users on v1.0.0 and v1.0.1 see an **optional** update dialog.

### Scenario 2: Critical Security Fix
```json
{
  "min_version": "1.0.2",
  "latest_version": "1.0.2",
  "download_url": "https://exanor.com/downloads/ExanorStorePartner-Setup-1.0.2.exe",
  "release_notes": "Critical security fix. Please update immediately.",
  "force_update": false
}
```
Users on v1.0.0 and v1.0.1 see a **forced** update dialog (can't skip).

### Scenario 3: Emergency — Force ALL Users
```json
{
  "min_version": "1.0.2",
  "latest_version": "1.0.2",
  "download_url": "https://exanor.com/downloads/ExanorStorePartner-Setup-1.0.2.exe",
  "release_notes": "Emergency update required.",
  "force_update": true
}
```
ALL users, regardless of version, see a **forced** update dialog.

---

## Code Files Involved

| File | Purpose |
|------|---------|
| `lib/services/windows_version_check_service.dart` | Main service — fetches JSON, compares versions, shows dialog |
| `lib/screens/SplashScreen.dart` | Calls the version check during app startup |
| `lib/utils/platform_helper.dart` | Provides `isWindows` check |
| `installer.iss` | Inno Setup installer configuration |
| `pubspec.yaml` | App version definition |

---

## Configuration

### Changing the Version Check URL

Edit `lib/services/windows_version_check_service.dart`, line 23-24:

```dart
static const String _versionCheckUrl =
    'https://YOUR-ACTUAL-SERVER.com/api/store-app-version.json';
```

### Important: Keep versions in sync!

Every release, these 3 files must have the same version number:

1. **`pubspec.yaml`** → `version: X.X.X+N`
2. **`installer.iss`** → `AppVersion=X.X.X`
3. **`windows_version_check_service.dart`** → `return 'X.X.X';`

---

## Comparison with Other Platforms

| Platform | Update Method | Auto-Update | Service Used |
|----------|---------------|-------------|--------------|
| **Android** | Google Play Store + In-App Update | ✅ Yes | `InAppUpdateService` |
| **iOS** | Apple App Store | ✅ Yes | App Store handles it |
| **Windows** | Custom HTTP check + Manual download | ❌ Manual download | `WindowsVersionCheckService` |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Dialog not showing on Windows | Check that the JSON URL is correct and accessible |
| Version check fails silently | Check console logs for `WindowsVersionCheck:` entries |
| User can't download the file | Verify the `download_url` in JSON is a valid, accessible URL |
| Wrong version comparison | Ensure version format is `X.X.X` (three numbers separated by dots) |
| JSON not found (404) | Verify the JSON file is hosted and the URL is correct |

---

**Status:** ✅ Implemented and Ready for Testing

**Date:** March 14, 2026
