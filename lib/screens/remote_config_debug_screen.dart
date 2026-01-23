import 'package:flutter/material.dart';
import 'package:exanor/services/firebase_remote_config_service.dart';
import 'dart:developer' as developer;

class RemoteConfigDebugScreen extends StatefulWidget {
  const RemoteConfigDebugScreen({super.key});

  @override
  State<RemoteConfigDebugScreen> createState() =>
      _RemoteConfigDebugScreenState();
}

class _RemoteConfigDebugScreenState extends State<RemoteConfigDebugScreen> {
  Map<String, dynamic> _configData = {};
  bool _isLoading = false;
  String _lastRefreshResult = '';

  @override
  void initState() {
    super.initState();
    developer.log(
      '🐛 RemoteConfigDebugScreen: Initializing debug screen',
      name: 'RemoteConfigDebug',
    );
    _loadConfigData();
  }

  void _loadConfigData() {
    try {
      developer.log(
        '🔄 RemoteConfigDebugScreen: Loading config data...',
        name: 'RemoteConfigDebug',
      );
      setState(() {
        _configData = FirebaseRemoteConfigService.getAllConfig();
      });
      developer.log(
        '✅ RemoteConfigDebugScreen: Config data loaded: $_configData',
        name: 'RemoteConfigDebug',
      );
    } catch (e) {
      developer.log(
        '❌ RemoteConfigDebugScreen: Error loading config data: $e',
        name: 'RemoteConfigDebug',
      );
    }
  }

  Future<void> _forceRefresh() async {
    setState(() {
      _isLoading = true;
      _lastRefreshResult = '';
    });

    try {
      developer.log(
        '🔄 RemoteConfigDebugScreen: Starting force refresh...',
        name: 'RemoteConfigDebug',
      );

      final result = await FirebaseRemoteConfigService.forceRefresh();

      setState(() {
        _lastRefreshResult = result
            ? 'Success: New values fetched'
            : 'No new values available';
        _isLoading = false;
      });

      developer.log(
        '✅ RemoteConfigDebugScreen: Force refresh completed: $result',
        name: 'RemoteConfigDebug',
      );

      // Reload config data
      _loadConfigData();

      // Show snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_lastRefreshResult),
            backgroundColor: result ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      developer.log(
        '❌ RemoteConfigDebugScreen: Force refresh failed: $e',
        name: 'RemoteConfigDebug',
      );

      setState(() {
        _lastRefreshResult = 'Error: $e';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Config Debug'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _forceRefresh,
            tooltip: 'Force Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _forceRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            FirebaseRemoteConfigService.isInitialized
                                ? Icons.check_circle
                                : Icons.error,
                            color: FirebaseRemoteConfigService.isInitialized
                                ? Colors.green
                                : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Remote Config Status',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        FirebaseRemoteConfigService.isInitialized
                            ? 'Initialized and Ready'
                            : 'Not Initialized',
                        style: TextStyle(
                          color: FirebaseRemoteConfigService.isInitialized
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_lastRefreshResult.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Last Refresh: $_lastRefreshResult',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Loading indicator
              if (_isLoading)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Refreshing configuration...'),
                      ],
                    ),
                  ),
                ),

              // Configuration Values
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Configuration Values',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_configData.isEmpty)
                        const Text('No configuration data available')
                      else
                        ..._configData.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: SelectableText(
                                    entry.value?.toString() ?? 'null',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Individual Parameter Cards
              if (FirebaseRemoteConfigService.isInitialized) ...[
                _buildParameterCard(
                  'Base URL',
                  FirebaseRemoteConfigService.getBaseUrl(),
                  Icons.link,
                  theme,
                ),
                _buildParameterCard(
                  'Bare Base URL',
                  FirebaseRemoteConfigService.getBareBaseUrl(),
                  Icons.link_off,
                  theme,
                ),
                _buildParameterCard(
                  'API Timeout',
                  '${FirebaseRemoteConfigService.getApiTimeout()}s',
                  Icons.timer,
                  theme,
                ),
                _buildParameterCard(
                  'Debug Mode',
                  FirebaseRemoteConfigService.isDebugModeEnabled().toString(),
                  Icons.bug_report,
                  theme,
                ),
                _buildParameterCard(
                  'Min App Version',
                  FirebaseRemoteConfigService.getMinAppVersion(),
                  Icons.app_settings_alt,
                  theme,
                ),
              ],

              const SizedBox(height: 16),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _forceRefresh,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_isLoading ? 'Refreshing...' : 'Force Refresh'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    developer.log(
                      '🔄 RemoteConfigDebugScreen: Manual reload requested',
                      name: 'RemoteConfigDebug',
                    );
                    _loadConfigData();
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('Reload Data'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Instructions
              Card(
                color: theme.colorScheme.surfaceVariant,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instructions',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Set up parameters in Firebase Console > Remote Config\n'
                        '2. Use parameter names: base_url, bare_base_url, api_timeout_seconds, enable_debug_mode, min_app_version\n'
                        '3. Publish your changes in the Firebase Console\n'
                        '4. Use "Force Refresh" to fetch latest values\n'
                        '5. Real-time updates will be received automatically',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParameterCard(
    String title,
    String value,
    IconData icon,
    ThemeData theme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: SelectableText(
          value,
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () {
            // Copy to clipboard functionality could be added here
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$title copied: $value')));
          },
        ),
      ),
    );
  }
}
