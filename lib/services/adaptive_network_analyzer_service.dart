// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Adaptive Network Analyzer Service
//
// • Runs in the background and periodically measures actual download speed.
// • Exposes a broadcast [Stream<NetworkSpeedResult>] so any part of the app
//   can reactively observe the current network quality.
// • Singleton pattern – call [AdaptiveNetworkAnalyzerService.instance].
// • Call [start()] once (e.g. in initState) and [stop()] in dispose.
//
// Speed is measured by downloading a small payload from a public CDN and
// computing: speed (Mbps) = (bytes × 8) / (elapsed_ms × 1000).
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:async';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a single network speed measurement.
class NetworkSpeedResult {
  /// Measured download speed in megabits per second (Mbps).
  final double speedMbps;

  /// Qualitative classification of the speed.
  final NetworkQuality quality;

  /// When this measurement was taken.
  final DateTime measuredAt;

  /// Whether the last measurement attempt succeeded (false = timeout / error).
  final bool isReachable;

  const NetworkSpeedResult({
    required this.speedMbps,
    required this.quality,
    required this.measuredAt,
    required this.isReachable,
  });

  /// Convenience: is the speed good enough for the given threshold (Mbps)?
  bool isAboveThreshold(double thresholdMbps) =>
      isReachable && speedMbps >= thresholdMbps;

  @override
  String toString() =>
      'NetworkSpeedResult(${speedMbps.toStringAsFixed(2)} Mbps, $quality, reachable: $isReachable)';
}

/// Qualitative network quality tiers.
enum NetworkQuality {
  /// Speed ≥ 25 Mbps — excellent for all operations.
  excellent,

  /// Speed 10–25 Mbps — good for most operations.
  good,

  /// Speed 5–10 Mbps — acceptable; some heavy uploads may be slow.
  fair,

  /// Speed 1–5 Mbps — poor; heavy operations (e.g. AI scan) should be gated.
  poor,

  /// Speed < 1 Mbps or no connectivity.
  veryPoor,

  /// Not yet measured or last attempt failed with a network error.
  unknown,
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

class AdaptiveNetworkAnalyzerService {
  AdaptiveNetworkAnalyzerService._();

  /// Global singleton.
  static final AdaptiveNetworkAnalyzerService instance =
      AdaptiveNetworkAnalyzerService._();

  // ── Configuration ────────────────────────────────────────────────────────

  /// How often to run a measurement (default: every 15 seconds).
  Duration measurementInterval = const Duration(seconds: 15);

  /// HTTP timeout for each probe request.
  Duration probeTimeout = const Duration(seconds: 8);

  /// Ordered list of CDN URLs used for speed probing.
  /// Index 0 is always tried first; subsequent entries are fallbacks only.
  List<String> probeUrls = const [
    // Primary: Cloudflare speed-test CDN — purpose-built, no throttling.
    // 500 KB gives a stable reading on fast connections.
    'https://speed.cloudflare.com/__down?bytes=524288',
    // Fallback A: httpbin random bytes
    'https://httpbin.org/bytes/524288',
    // Fallback B: fast.com JS bundle (size may vary)
    'https://www.fast.com/app-7b6f4d9c58e6a513.js',
  ];

  // ── Internal state ────────────────────────────────────────────────────────

  final StreamController<NetworkSpeedResult> _controller =
      StreamController<NetworkSpeedResult>.broadcast();

  Timer? _timer;
  bool _isRunning = false;
  int _probeIndex = 0;

  /// The most recently measured result (null before the first measurement).
  NetworkSpeedResult? lastResult;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Broadcast stream of [NetworkSpeedResult] updates.
  Stream<NetworkSpeedResult> get stream => _controller.stream;

  /// Whether the service is currently active.
  bool get isRunning => _isRunning;

  /// Starts continuous background network measurement.
  ///
  /// [measurementInterval] — how often to probe (default 15 s).
  /// [probeTimeout]        — max time per request (default 8 s).
  /// [probeUrls]           — CDN endpoints to download; a small file is
  ///                         sufficient — the service only reads the body size.
  ///
  /// Calling [start()] while already running is a no-op.
  void start({
    Duration? measurementInterval,
    Duration? probeTimeout,
    List<String>? probeUrls,
  }) {
    if (_isRunning) return;

    this.measurementInterval =
        measurementInterval ?? const Duration(seconds: 15);
    this.probeTimeout = probeTimeout ?? const Duration(seconds: 8);
    this.probeUrls = probeUrls ??
        [
          // Primary: Cloudflare speed-test CDN — 500 KB
          'https://speed.cloudflare.com/__down?bytes=524288',
          // Fallback A: httpbin random bytes
          'https://httpbin.org/bytes/524288',
          // Fallback B: fast.com JS bundle
          'https://www.fast.com/app-7b6f4d9c58e6a513.js',
        ];

    _isRunning = true;
    developer.log(
      '🌐 AdaptiveNetworkAnalyzerService started '
      '(interval: ${this.measurementInterval.inSeconds}s)',
      name: 'NetworkAnalyzer',
    );

    // Run immediately, then on every tick.
    _runMeasurement();
    _timer = Timer.periodic(this.measurementInterval, (_) => _runMeasurement());
  }

  /// Stops the periodic background measurement.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    developer.log(
      '🌐 AdaptiveNetworkAnalyzerService stopped.',
      name: 'NetworkAnalyzer',
    );
  }

  /// Runs a one-shot measurement and returns the result.
  /// Also pushes the result onto [stream] and updates [lastResult].
  Future<NetworkSpeedResult> measureOnce() async {
    final result = await _probe();
    lastResult = result;
    if (!_controller.isClosed) _controller.add(result);
    developer.log(
      '📶 Network: ${result.speedMbps.toStringAsFixed(2)} Mbps '
      '(${result.quality.name}) [on-demand]',
      name: 'NetworkAnalyzer',
    );
    return result;
  }

  /// Disposes the service entirely (closes the stream).
  /// After calling this, do not reuse the instance.
  void dispose() {
    stop();
    _controller.close();
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<void> _runMeasurement() async {
    final result = await _probe();
    lastResult = result;
    if (!_controller.isClosed) _controller.add(result);
    developer.log(
      '📶 Network: ${result.speedMbps.toStringAsFixed(2)} Mbps '
      '(${result.quality.name})',
      name: 'NetworkAnalyzer',
    );
  }

  Future<NetworkSpeedResult> _probe() async {
    final urls = probeUrls;
    if (urls.isEmpty) return _unknownResult();

    // Always start from index 0 (Cloudflare) so every call — whether from
    // the background timer or measureOnce() — uses the same primary URL.
    // Subsequent entries are tried only as fallbacks if the primary fails.
    for (int i = 0; i < urls.length; i++) {
      final url = urls[i];

      try {
        final stopwatch = Stopwatch()..start();
        final response = await http
            .get(Uri.parse(url))
            .timeout(probeTimeout);
        stopwatch.stop();

        if (response.statusCode == 200) {
          final bytes = response.bodyBytes.lengthInBytes;
          final elapsedMs = stopwatch.elapsedMilliseconds.clamp(1, 1 << 30);

          // bytes → bits → Mbps
          // Speed (Mbps) = (bytes × 8 bits) / (elapsedMs ÷ 1000 seconds) / 1,000,000
          //              = (bytes × 8) / (elapsedMs × 1000)
          final speedMbps = (bytes * 8.0) / (elapsedMs * 1000.0);

          if (i > 0) {
            developer.log(
              '⚠️ Primary probe failed, used fallback[$i]: $url',
              name: 'NetworkAnalyzer',
            );
          }

          return NetworkSpeedResult(
            speedMbps: speedMbps,
            quality: _classify(speedMbps),
            measuredAt: DateTime.now(),
            isReachable: true,
          );
        }
      } on TimeoutException {
        developer.log(
          '⏱️ Network probe timed out for $url',
          name: 'NetworkAnalyzer',
        );
      } catch (e) {
        developer.log(
          '⚠️ Network probe error for $url: $e',
          name: 'NetworkAnalyzer',
        );
      }
    }

    // All probes failed.
    return NetworkSpeedResult(
      speedMbps: 0,
      quality: NetworkQuality.unknown,
      measuredAt: DateTime.now(),
      isReachable: false,
    );
  }

  NetworkSpeedResult _unknownResult() => NetworkSpeedResult(
        speedMbps: 0,
        quality: NetworkQuality.unknown,
        measuredAt: DateTime.now(),
        isReachable: false,
      );

  NetworkQuality _classify(double mbps) {
    if (mbps >= 25) return NetworkQuality.excellent;
    if (mbps >= 10) return NetworkQuality.good;
    if (mbps >= 5) return NetworkQuality.fair;
    if (mbps >= 1) return NetworkQuality.poor;
    return NetworkQuality.veryPoor;
  }
}
