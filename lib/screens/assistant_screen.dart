import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;

/// AI Assistant Screen with full-screen transparent WebView
/// This screen loads an external chat interface embedded in a WebView
class AssistantScreen extends StatefulWidget {
  final String storeId;
  final String storeName;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onClose;

  const AssistantScreen({
    super.key,
    required this.storeId,
    required this.storeName,
    this.onMenuPressed,
    this.onClose,
  });

  @override
  State<AssistantScreen> createState() => AssistantScreenState();
}

class AssistantScreenState extends State<AssistantScreen>
    with TickerProviderStateMixin {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isInitialized = false;
  bool _isStopped = true; // Start as stopped - only load when tab is active
  String _errorMessage = '';
  String? _accessToken;
  String? _userId;

  @override
  void initState() {
    super.initState();
    // Removed _initAnimations

    _checkPermissionAndStart();
  }

  /// Public method to restart the assistant when tab becomes visible
  Future<void> restartAssistant() async {
    if (_isStopped || !_isInitialized) {
      developer.log('🔄 Assistant: Restarting assistant...', name: 'Assistant');
      _isStopped = false;
      await _checkPermissionAndStart();
    }
  }

  /// Check microphone permission and start WebView
  /// If already granted → start immediately
  /// If not granted → request permission first → then start
  Future<void> _checkPermissionAndStart() async {
    try {
      // Check current permission status
      final micStatus = await Permission.microphone.status;
      developer.log(
        '🎤 Assistant: Microphone permission status: $micStatus',
        name: 'Assistant',
      );

      if (micStatus.isGranted) {
        // Permission already granted, start WebView immediately
        developer.log(
          '✅ Assistant: Microphone permission already granted, starting WebView',
          name: 'Assistant',
        );
        await _initWebView();
      } else {
        // Request permission
        developer.log(
          '🎤 Assistant: Requesting microphone permission...',
          name: 'Assistant',
        );
        final result = await Permission.microphone.request();
        developer.log(
          '🎤 Assistant: Permission result: $result',
          name: 'Assistant',
        );

        if (result.isGranted) {
          developer.log(
            '✅ Assistant: Permission granted, starting WebView',
            name: 'Assistant',
          );
        } else if (result.isPermanentlyDenied && mounted) {
          // Show dialog to open settings
          _showPermissionDeniedDialog();
        }

        // Start WebView regardless (it will work without mic, just no voice)
        await _initWebView();
      }
    } catch (e) {
      developer.log(
        '❌ Assistant: Error checking permissions: $e',
        name: 'Assistant',
      );
      // Still try to initialize WebView
      await _initWebView();
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: const Text(
          'The AI Assistant needs microphone access for voice features. '
          'Please enable microphone permission in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  // Removed _initAnimations

  // Removed _initGlowAnimation

  Future<void> _initWebView() async {
    try {
      // Get tokens and user data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      _userId = prefs.getString('user_id');

      developer.log('🤖 Assistant: Initializing WebView', name: 'Assistant');
      developer.log(
        '🤖 Assistant: store_id: ${widget.storeId}',
        name: 'Assistant',
      );
      developer.log(
        '🤖 Assistant: access_token: ${_accessToken != null ? "${_accessToken!.substring(0, 20)}..." : "NULL"}',
        name: 'Assistant',
      );
      developer.log('🤖 Assistant: user_id: $_userId', name: 'Assistant');

      // Build the URL with query parameters
      final url = _buildChatUrl();

      developer.log('🚀 Assistant: Built URL: $url', name: 'Assistant');

      // Platform-specific WebView parameters
      late final PlatformWebViewControllerCreationParams params;

      if (WebViewPlatform.instance is WebKitWebViewPlatform) {
        // iOS/macOS specific configuration
        params = WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        );
      } else {
        // Android and other platforms
        params = const PlatformWebViewControllerCreationParams();
      }

      // Initialize WebView controller with platform-specific params
      final controller = WebViewController.fromPlatformCreationParams(params);

      // Configure the controller
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.transparent);

      // Set a proper User-Agent
      await controller.setUserAgent(
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 ExanorApp/1.0',
      );

      // Android-specific configuration
      if (controller.platform is AndroidWebViewController) {
        final androidController =
            controller.platform as AndroidWebViewController;
        await androidController.setMediaPlaybackRequiresUserGesture(false);
        await androidController.setGeolocationEnabled(true);
        // Enable debugging for Chrome DevTools
        await AndroidWebViewController.enableDebugging(true);

        // Add JavaScript console message listener
        await androidController.setOnConsoleMessage((message) {
          developer.log(
            '📱 WebView Console [${message.level.name}]: ${message.message}',
            name: 'WebViewConsole',
          );
        });

        // Grant permissions for audio/video (Microphone)
        await androidController.setOnPlatformPermissionRequest((
          PlatformWebViewPermissionRequest request,
        ) {
          developer.log(
            '🎤 Assistant: WebView requesting permission for ${request.types}',
            name: 'Assistant',
          );
          request.grant();
        });

        developer.log(
          '🤖 Assistant: Android WebView configured with debugging, console logging, and permissions',
          name: 'Assistant',
        );
      }

      // iOS-specific configuration
      if (controller.platform is WebKitWebViewController) {
        final webkitController = controller.platform as WebKitWebViewController;
        await webkitController.setAllowsBackForwardNavigationGestures(true);

        developer.log(
          '🤖 Assistant: iOS WebView configured',
          name: 'Assistant',
        );
      }

      await controller.setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            developer.log(
              '🔄 Assistant: Page started loading: $url',
              name: 'Assistant',
            );
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (String url) {
            developer.log(
              '✅ Assistant: Page finished loading: $url',
              name: 'Assistant',
            );
            // Inject CSS to make background transparent
            _injectTransparentBackground();
            // Inject console log interceptor
            _injectConsoleLogInterceptor();

            // Wait slightly for CSS to apply before revealing
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            });
          },
          onWebResourceError: (WebResourceError error) {
            developer.log(
              '❌ Assistant: WebView error: ${error.description} (code: ${error.errorCode}, type: ${error.errorType})',
              name: 'Assistant',
            );
            // Only show error for main frame errors, not subresource errors
            if (error.isForMainFrame ?? true) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasError = true;
                  _errorMessage =
                      '${error.description}\n(Error code: ${error.errorCode})';
                });
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            developer.log(
              '🔗 Assistant: Navigation request: ${request.url}',
              name: 'Assistant',
            );
            return NavigationDecision.navigate;
          },
          onHttpError: (HttpResponseError error) {
            developer.log(
              '❌ Assistant: HTTP error: ${error.response?.statusCode}',
              name: 'Assistant',
            );
          },
          onUrlChange: (UrlChange change) {
            developer.log(
              '🔗 Assistant: URL changed to: ${change.url}',
              name: 'Assistant',
            );
          },
        ),
      );

      // Add JavaScript channel to receive messages from WebView
      await controller.addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          developer.log(
            '📩 Assistant: JS Message received: ${message.message}',
            name: 'Assistant',
          );
        },
      );

      await controller.enableZoom(false);

      // Load the URL
      developer.log(
        '🚀 Assistant: Loading request for URL: $url',
        name: 'Assistant',
      );
      await controller.loadRequest(Uri.parse(url));

      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
        });
      }

      developer.log(
        '🚀 Assistant: WebView initialized and loading URL',
        name: 'Assistant',
      );
    } catch (e, stack) {
      developer.log(
        '❌ Assistant: Failed to initialize WebView: $e',
        name: 'Assistant',
      );
      developer.log('❌ Assistant: Stack trace: $stack', name: 'Assistant');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  String _buildChatUrl() {
    const baseUrl = 'https://chat.exanor.com/chat-window';
    final params = <String, String>{
      'store_id': widget.storeId,
      if (_accessToken != null) 'access_token': _accessToken!,
      if (_userId != null) 'user_id': _userId!,
    };

    final uri = Uri.parse(baseUrl).replace(queryParameters: params);
    return uri.toString();
  }

  Future<void> _injectTransparentBackground() async {
    if (_controller == null) return;

    try {
      // Powerful script to enforce transparency using MutationObserver
      // This fights against framework hydration (React/Next.js) resetting styles
      await _controller!.runJavaScript('''
        (function() {
          function clearBackground() {
             document.body.style.backgroundColor = 'transparent';
             document.documentElement.style.backgroundColor = 'transparent';
             
             // Target common roots
             const roots = document.querySelectorAll('#root, #__next, #app, .App, body > div');
             roots.forEach(el => el.style.backgroundColor = 'transparent');
          }

          // 1. Clear immediately
          clearBackground();
          
          // 2. Add persistent style override
          const style = document.createElement('style');
          style.innerHTML = `
            html, body, #root, #__next, #app { background-color: transparent !important; }
            * { background-color: rgba(0,0,0,0) !important; } /* Nuclear option for backgrounds */
            /* Restore backgrounds for actual content elements if needed, but for now force clear */
            button, input, textarea, card, .card, .content { background-color: revert; } 
          `;
          document.head.appendChild(style);

          // 3. Watch for changes and re-clear (MutationObserver)
          const observer = new MutationObserver((mutations) => {
            clearBackground();
          });
          
          observer.observe(document.body, { 
            attributes: true, 
            attributeFilter: ['style', 'class'],
            childList: true,
            subtree: true 
          });
          
          console.log("Transparency Enforcer Active");
        })();
      ''');

      developer.log(
        '✅ Assistant: Transparency Enforcer Injected',
        name: 'Assistant',
      );
    } catch (e) {
      developer.log(
        '⚠️ Assistant: Failed to inject transparency: $e',
        name: 'Assistant',
      );
    }
  }

  Future<void> _injectConsoleLogInterceptor() async {
    if (_controller == null) return;

    try {
      // Intercept console.log/error/warn and send to Flutter
      await _controller!.runJavaScript('''
        (function() {
          var oldLog = console.log;
          var oldError = console.error;
          var oldWarn = console.warn;
          
          console.log = function() {
            oldLog.apply(console, arguments);
            try {
              if (window.FlutterBridge) {
                FlutterBridge.postMessage('LOG: ' + Array.from(arguments).join(' '));
              }
            } catch(e) {}
          };
          
          console.error = function() {
            oldError.apply(console, arguments);
            try {
              if (window.FlutterBridge) {
                FlutterBridge.postMessage('ERROR: ' + Array.from(arguments).join(' '));
              }
            } catch(e) {}
          };
          
          console.warn = function() {
            oldWarn.apply(console, arguments);
            try {
              if (window.FlutterBridge) {
                FlutterBridge.postMessage('WARN: ' + Array.from(arguments).join(' '));
              }
            } catch(e) {}
          };
          
          // Also catch unhandled errors
          window.onerror = function(msg, url, lineNo, columnNo, error) {
            try {
              if (window.FlutterBridge) {
                FlutterBridge.postMessage('UNCAUGHT ERROR: ' + msg + ' at ' + url + ':' + lineNo);
              }
            } catch(e) {}
            return false;
          };
        })();
      ''');
      developer.log(
        '✅ Assistant: Console log interceptor injected',
        name: 'Assistant',
      );
    } catch (e) {
      developer.log(
        '⚠️ Assistant: Failed to inject console interceptor: $e',
        name: 'Assistant',
      );
    }
  }

  Future<void> _refreshWebView() async {
    if (_controller == null) {
      await _initWebView();
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      await _controller!.reload();
    } catch (e) {
      developer.log(
        '❌ Assistant: Failed to reload WebView: $e',
        name: 'Assistant',
      );
      // Try reinitializing
      await _initWebView();
    }
  }

  /// Stop the assistant - disconnect WebView and reset state
  Future<void> stopAssistant() async {
    developer.log('🛑 Assistant: Stopping assistant...', name: 'Assistant');

    if (_controller != null) {
      try {
        // First, try to close any WebSocket connections via JavaScript
        await _controller!.runJavaScript('''
          if (window.geminiLive) {
            window.geminiLive.disconnect();
          }
          // Close any WebSocket connections
          if (window.ws) {
            window.ws.close();
          }
        ''');
      } catch (e) {
        developer.log(
          '⚠️ Assistant: Error disconnecting: $e',
          name: 'Assistant',
        );
      }

      try {
        // Load blank page to stop all activity
        await _controller!.loadRequest(Uri.parse('about:blank'));
      } catch (e) {
        developer.log(
          '⚠️ Assistant: Error loading blank page: $e',
          name: 'Assistant',
        );
      }
    }

    // Reset state
    if (mounted) {
      setState(() {
        _controller = null;
        _isInitialized = false;
        _isLoading = true; // Show loading state for restart
        _hasError = false;
        _errorMessage = '';
        _isStopped = true; // Mark as stopped for restart detection
      });
    }

    developer.log('✅ Assistant: Stopped', name: 'Assistant');
  }

  @override
  void dispose() {
    // Stop the assistant when disposed
    stopAssistant();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. WebView Content (Full Screen)
          // Use Stack to keep WebView mounted but hidden while loading
          Positioned.fill(
            child: Stack(
              children: [
                // The WebView
                if (_isInitialized && _controller != null)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOut,
                    opacity: _isLoading ? 0.0 : 1.0,
                    child: WebViewWidget(controller: _controller!),
                  ),

                // CSS Style Block Loader
                if (_isLoading || !_isInitialized)
                  const Center(child: CSSLoader()),

                // Error Widget
                if (_hasError) _buildErrorWidget(theme, isDark),
              ],
            ),
          ),

          // REMOVED: Border Overlay (User requested removal)

          // 3. Floating Controls (Bottom)
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: SafeArea(
              // Ensure controls are in safe area
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Close Button
                  _buildFloatingButton(
                    icon: Icons.close,
                    color: Colors.redAccent,
                    onPressed: widget.onClose,
                    tooltip: 'Exit',
                  ),

                  const SizedBox(width: 20),

                  // Retry Button
                  if (_hasError)
                    _buildFloatingButton(
                      icon: Icons.refresh,
                      color: Colors.white,
                      onPressed: _refreshWebView,
                      tooltip: 'Retry',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: color, size: 30),
          padding: const EdgeInsets.all(16),
          tooltip: tooltip,
        ),
      ),
    );
  }

  // Removed _buildLoadingWidget

  Widget _buildErrorWidget(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon with subtle animation
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.red.withOpacity(0.2)
                    : Colors.red.withOpacity(0.1),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 40,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to load Assistant',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage.isNotEmpty
                  ? _errorMessage
                  : 'Please check your internet connection and try again.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _initWebView,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// End of file

// -----------------------------------------------------------------------------
//  CSS LOADER (Replica of User Request)
// -----------------------------------------------------------------------------
class CSSLoader extends StatefulWidget {
  const CSSLoader({Key? key}) : super(key: key);

  @override
  State<CSSLoader> createState() => _CSSLoaderState();
}

class _CSSLoaderState extends State<CSSLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Theme color
    final color = Theme.of(context).primaryColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: CSSLoaderPainter(progress: _controller.value, color: color),
          size: const Size(60, 60),
        );
      },
    );
  }
}

class CSSLoaderPainter extends CustomPainter {
  final double progress;
  final Color color;

  CSSLoaderPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // 100px container (from CSS).
    // We have 60x60 canvas.
    // Content 40px? Let's scale.
    // Moving object 40px? On 100px container? 100px - 20px padding = 80px space?
    // If element is 40px, translate(100%, 0) means move 40px right.
    // Total width covered = 40 (start) + 40 (move) = 80px. Fits in 80px space.
    // So visual size is 40px moves in 40px grid.

    // In 60x60 canvas:
    // Box size = 20px?
    // Move 20px.
    // Total bounds 40px. Centered.

    final double boxSize = 25.0;
    final double moveDist = 25.0;

    // Path function: 0->1 loops square.
    Offset getPos(double t) {
      // t = t % 1.0;
      if (t < 0.25) {
        // Top: (0,0) -> (1,0)
        double local = (t / 0.25);
        local = Curves.easeInOut.transform(local);
        return Offset(moveDist * local, 0);
      } else if (t < 0.50) {
        // Right: (1,0) -> (1,1)
        double local = (t - 0.25) / 0.25;
        local = Curves.easeInOut.transform(local);
        return Offset(moveDist, moveDist * local);
      } else if (t < 0.75) {
        // Bottom: (1,1) -> (0,1)
        double local = (t - 0.50) / 0.25;
        local = Curves.easeInOut.transform(local);
        return Offset(moveDist * (1 - local), moveDist);
      } else {
        // Left: (0,1) -> (0,0)
        double local = (t - 0.75) / 0.25;
        local = Curves.easeInOut.transform(local);
        return Offset(0, moveDist * (1 - local));
      }
    }

    final Paint circlePaint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        5,
      ); // Simulate Blur for goo

    // Center the whole animation in 60x60
    // Total width occupied = boxSize + moveDist = 50.
    // Offset to center = (60 - 50) / 2 = 5.
    canvas.save();
    canvas.translate(5, 5);

    // Object 1
    Offset p1 = getPos(progress);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(p1.dx, p1.dy, boxSize, boxSize),
        const Radius.circular(12),
      ),
      circlePaint,
    );

    // Object 2 (Offset by 0.5 -> 50%)
    double t2 = (progress + 0.5) % 1.0;
    Offset p2 = getPos(t2);

    // Use slightly different color for blend? Or same? CSS uses same #ffff00.
    // But 'hue-rotate(300deg)' makes it uniform color.
    // Using same color + blur merges them.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(p2.dx, p2.dy, boxSize, boxSize),
        const Radius.circular(12),
      ),
      circlePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CSSLoaderPainter old) =>
      old.progress != progress;
}
