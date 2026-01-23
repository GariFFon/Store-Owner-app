import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';

class InAppUpdateService {
  static InAppUpdateService? _instance;
  static InAppUpdateService get instance =>
      _instance ??= InAppUpdateService._();

  InAppUpdateService._();

  // Track update state
  bool _isUpdateInProgress = false;
  bool _isFlexibleUpdateDownloaded = false;

  /// Check if in-app updates are supported on this platform
  bool get isSupported {
    // Only Android supports in-app updates
    try {
      return Platform.isAndroid;
    } catch (e) {
      debugPrint('❌ Error checking platform: $e');
      return false;
    }
  }

  /// Check for available updates and handle them based on priority
  /// [isForced] - Whether to show immediate update for critical updates
  /// [context] - BuildContext for showing dialogs
  Future<void> checkAndPerformUpdate({
    required BuildContext context,
    bool isForced = false,
  }) async {
    try {
      // Check if platform is supported
      if (!isSupported) {
        debugPrint('🔄 In-app updates only supported on Android');
        return;
      }

      if (_isUpdateInProgress) {
        debugPrint('🔄 Update already in progress, skipping check');
        return;
      }

      debugPrint('🔍 Checking for app updates...');

      // Check for updates with error handling
      final AppUpdateInfo updateInfo = await _safeCheckForUpdate();
      if (updateInfo.updateAvailability == UpdateAvailability.unknown) {
        debugPrint('❌ Unable to check for updates');
        return;
      }

      debugPrint('📊 Update availability: ${updateInfo.updateAvailability}');
      debugPrint(
        '📊 Immediate update allowed: ${updateInfo.immediateUpdateAllowed}',
      );
      debugPrint(
        '📊 Flexible update allowed: ${updateInfo.flexibleUpdateAllowed}',
      );

      // Handle update based on availability and priority
      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (isForced && updateInfo.immediateUpdateAllowed) {
          await _performImmediateUpdate(context);
        } else if (updateInfo.flexibleUpdateAllowed) {
          await _showFlexibleUpdateDialog(context);
        } else if (updateInfo.immediateUpdateAllowed) {
          await _showImmediateUpdateDialog(context);
        }
      } else {
        debugPrint('✅ App is up to date');
      }
    } catch (e) {
      debugPrint('❌ Error checking for updates: $e');
      // Don't show error to user for update checks unless critical
      if (isForced && context.mounted) {
        _showUpdateErrorDialog(
          context,
          'Unable to check for updates. Please try again later.',
        );
      }
    }
  }

  /// Safely check for updates with proper error handling
  Future<AppUpdateInfo> _safeCheckForUpdate() async {
    try {
      return await InAppUpdate.checkForUpdate();
    } on MissingPluginException catch (e) {
      debugPrint('❌ MissingPluginException: ${e.message}');
      debugPrint('💡 This usually means:');
      debugPrint(
        '   1. App needs to be rebuilt (try: flutter clean && flutter run)',
      );
      debugPrint('   2. App is not installed via Google Play Store');
      debugPrint('   3. Running on unsupported platform');

      // Return a default "unknown" state
      return AppUpdateInfo(
        updateAvailability: UpdateAvailability.unknown,
        immediateUpdateAllowed: false,
        flexibleUpdateAllowed: false,
        immediateAllowedPreconditions: [],
        flexibleAllowedPreconditions: [],
        availableVersionCode: null,
        installStatus: InstallStatus.unknown,
        packageName: '',
        clientVersionStalenessDays: null,
        updatePriority: 0,
      );
    } on PlatformException catch (e) {
      debugPrint('❌ PlatformException: ${e.message}');
      debugPrint('💡 Error code: ${e.code}');

      if (e.code == 'ERROR_API_NOT_AVAILABLE') {
        debugPrint(
          '💡 App must be installed via Google Play Store to check for updates',
        );
      }

      // Return a default "unknown" state
      return AppUpdateInfo(
        updateAvailability: UpdateAvailability.unknown,
        immediateUpdateAllowed: false,
        flexibleUpdateAllowed: false,
        immediateAllowedPreconditions: [],
        flexibleAllowedPreconditions: [],
        availableVersionCode: null,
        installStatus: InstallStatus.unknown,
        packageName: '',
        clientVersionStalenessDays: null,
        updatePriority: 0,
      );
    } catch (e) {
      debugPrint('❌ Unexpected error checking for updates: $e');
      rethrow;
    }
  }

  /// Perform immediate update (full-screen, blocking)
  Future<void> _performImmediateUpdate(BuildContext context) async {
    try {
      debugPrint('🚀 Starting immediate update...');
      _isUpdateInProgress = true;

      await InAppUpdate.performImmediateUpdate();

      debugPrint('✅ Immediate update completed');
    } on MissingPluginException catch (e) {
      debugPrint(
        '❌ MissingPluginException during immediate update: ${e.message}',
      );
      if (context.mounted) {
        _showUpdateErrorDialog(
          context,
          'Update feature not available. Please update manually from Google Play Store.',
        );
      }
    } on PlatformException catch (e) {
      debugPrint('❌ PlatformException during immediate update: ${e.message}');
      if (context.mounted) {
        _showUpdateErrorDialog(
          context,
          'Update failed: ${e.message}. Please try updating from Google Play Store.',
        );
      }
    } catch (e) {
      debugPrint('❌ Immediate update failed: $e');
      if (context.mounted) {
        _showUpdateErrorDialog(
          context,
          'Failed to perform immediate update: $e',
        );
      }
    } finally {
      _isUpdateInProgress = false;
    }
  }

  /// Show dialog for immediate update
  Future<void> _showImmediateUpdateDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.system_update,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('Update Required'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version of exanor is available with important improvements and bug fixes.',
              ),
              SizedBox(height: 12),
              Text(
                'Please update to continue using the app.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performImmediateUpdate(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('Update Now'),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog for flexible update
  Future<void> _showFlexibleUpdateDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final theme = Theme.of(context);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.new_releases,
                color: theme.colorScheme.secondary,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('Update Available'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version of exanor is available with exciting new features and improvements.',
              ),
              SizedBox(height: 12),
              Text(
                'The update will download in the background, and you can continue using the app.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _startFlexibleUpdate(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
              ),
              child: const Text('Update'),
            ),
          ],
        );
      },
    );
  }

  /// Start flexible update (background download)
  Future<void> _startFlexibleUpdate(BuildContext context) async {
    try {
      debugPrint('📥 Starting flexible update download...');
      _isUpdateInProgress = true;

      // Show downloading snackbar
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(child: Text('Downloading update in background...')),
              ],
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }

      await InAppUpdate.startFlexibleUpdate();

      debugPrint('✅ Flexible update download started');

      // Listen for download completion
      _listenForFlexibleUpdateCompletion(context);
    } on MissingPluginException catch (e) {
      debugPrint(
        '❌ MissingPluginException during flexible update: ${e.message}',
      );
      if (context.mounted) {
        _showUpdateErrorDialog(
          context,
          'Update feature not available. Please update manually from Google Play Store.',
        );
      }
    } on PlatformException catch (e) {
      debugPrint('❌ PlatformException during flexible update: ${e.message}');
      if (context.mounted) {
        _showUpdateErrorDialog(
          context,
          'Update failed: ${e.message}. Please try updating from Google Play Store.',
        );
      }
    } catch (e) {
      debugPrint('❌ Flexible update failed: $e');
      if (context.mounted) {
        _showUpdateErrorDialog(context, 'Failed to start update download: $e');
      }
    } finally {
      _isUpdateInProgress = false;
    }
  }

  /// Listen for flexible update download completion
  void _listenForFlexibleUpdateCompletion(BuildContext context) {
    // Note: The package doesn't provide a stream, so we'll check periodically
    // In a real implementation, you might want to use a timer or other mechanism
    // to check the update status periodically

    Future.delayed(const Duration(seconds: 10), () async {
      try {
        final updateInfo = await _safeCheckForUpdate();

        if (updateInfo.updateAvailability ==
            UpdateAvailability.developerTriggeredUpdateInProgress) {
          debugPrint('📦 Flexible update downloaded, ready to install');
          _isFlexibleUpdateDownloaded = true;

          if (context.mounted) {
            _showInstallUpdateDialog(context);
          }
        }
      } catch (e) {
        debugPrint('❌ Error checking flexible update status: $e');
      }
    });
  }

  /// Show dialog to install downloaded flexible update
  Future<void> _showInstallUpdateDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.install_mobile,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text('Update Ready'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('The update has been downloaded and is ready to install.'),
              SizedBox(height: 12),
              Text(
                'The app will restart to complete the installation.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Later'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _completeFlexibleUpdate(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('Install & Restart'),
            ),
          ],
        );
      },
    );
  }

  /// Complete flexible update installation
  Future<void> _completeFlexibleUpdate(BuildContext context) async {
    try {
      debugPrint('🔄 Completing flexible update installation...');

      await InAppUpdate.completeFlexibleUpdate();

      debugPrint('✅ Flexible update installation completed');
    } on MissingPluginException catch (e) {
      debugPrint(
        '❌ MissingPluginException during flexible update completion: ${e.message}',
      );
      if (context.mounted) {
        _showUpdateErrorDialog(
          context,
          'Update installation not available. Please restart the app manually.',
        );
      }
    } on PlatformException catch (e) {
      debugPrint(
        '❌ PlatformException during flexible update completion: ${e.message}',
      );
      if (context.mounted) {
        _showUpdateErrorDialog(
          context,
          'Update installation failed: ${e.message}. Please restart the app manually.',
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to complete flexible update: $e');
      if (context.mounted) {
        _showUpdateErrorDialog(context, 'Failed to install update: $e');
      }
    }
  }

  /// Show error dialog for update failures
  void _showUpdateErrorDialog(BuildContext context, String message) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Expanded(child: Text('Update Info')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Note for Testing:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                '• In-app updates only work when the app is installed via Google Play Store\n'
                '• Debug builds typically don\'t support in-app updates\n'
                '• You can manually check for updates in the Play Store',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Force check for critical updates (call on app startup)
  Future<void> checkForCriticalUpdates(BuildContext context) async {
    await checkAndPerformUpdate(context: context, isForced: true);
  }

  /// Manual update check (call from settings or menu)
  Future<void> manualUpdateCheck(BuildContext context) async {
    // Check if platform is supported first
    if (!isSupported) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text('In-app updates are only available on Android'),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Show checking dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Checking for updates...')),
          ],
        ),
      ),
    );

    try {
      final updateInfo = await _safeCheckForUpdate();

      // Close checking dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        await checkAndPerformUpdate(context: context);
      } else if (updateInfo.updateAvailability == UpdateAvailability.unknown) {
        // Show appropriate message for unknown state
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Unable to check for updates. Please try again later.',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Show up-to-date message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(child: Text('You\'re using the latest version')),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      // Close checking dialog
      if (context.mounted) {
        Navigator.of(context).pop();

        String errorMessage = 'Failed to check for updates: $e';

        // Provide more user-friendly messages for common errors
        if (e.toString().contains('MissingPluginException')) {
          errorMessage =
              'Update feature not available. Please check Google Play Store manually.';
        } else if (e.toString().contains('ERROR_API_NOT_AVAILABLE')) {
          errorMessage =
              'Updates can only be checked for apps installed from Google Play Store.';
        }

        _showUpdateErrorDialog(context, errorMessage);
      }
    }
  }

  /// Check if flexible update is downloaded and ready to install
  bool get isFlexibleUpdateReady => _isFlexibleUpdateDownloaded;

  /// Reset update state (call when needed)
  void resetUpdateState() {
    _isUpdateInProgress = false;
    _isFlexibleUpdateDownloaded = false;
  }

  /// Test if the in_app_update plugin is properly registered
  /// This is useful for debugging plugin registration issues
  Future<bool> testPluginAvailability() async {
    try {
      debugPrint('🧪 Testing in_app_update plugin availability...');

      if (!isSupported) {
        debugPrint('❌ Platform not supported for in-app updates');
        return false;
      }

      // Try to call the plugin method
      await InAppUpdate.checkForUpdate();
      debugPrint('✅ Plugin is properly registered and available');
      return true;
    } on MissingPluginException catch (e) {
      debugPrint('❌ Plugin not registered: ${e.message}');
      debugPrint('💡 Solutions:');
      debugPrint('   1. Run: flutter clean && flutter pub get && flutter run');
      debugPrint('   2. Restart your IDE/editor');
      debugPrint(
        '   3. Check if in_app_update is in pubspec.yaml dependencies',
      );
      return false;
    } on PlatformException catch (e) {
      if (e.code == 'ERROR_API_NOT_AVAILABLE') {
        debugPrint(
          '✅ Plugin is registered but API not available (expected in debug/non-Play Store installs)',
        );
        return true; // Plugin is working, just API not available
      } else if (e.code == '-10' ||
          e.message?.contains('ERROR_APP_NOT_OWNED') == true) {
        debugPrint(
          '✅ Plugin is working correctly! App not installed via Play Store (expected for side-loaded apps)',
        );
        debugPrint(
          '💡 This error confirms the plugin is functional - it will work when installed via Play Store',
        );
        return true; // Plugin is working correctly
      }
      debugPrint('❌ Platform exception: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return false;
    }
  }
}
