import 'dart:async';
import 'package:exanor/components/store_main_drawer.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/screens/add_purchase_order_screen.dart';
import 'package:exanor/screens/product_details_screen.dart';
import 'package:exanor/screens/purchase_details_screen.dart';
import 'package:exanor/screens/supplier_details_screen.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:exanor/screens/intelligence_upload_dialog.dart';
import 'package:exanor/services/adaptive_network_analyzer_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class PurchaseScreen extends StatefulWidget {
  final String storeId;
  final String? storeName;
  final VoidCallback? onMenuPressed;

  const PurchaseScreen({
    super.key,
    required this.storeId,
    this.storeName,
    this.onMenuPressed,
  });

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  List<dynamic> _vouchers = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasNextPage = false;
  int _limit = 200; // Load more upfront to fill large screens
  int _offset = 0;
  int _count = 0;

  // ── Network speed monitoring ───────────────────────────────────────────────
  /// Latest measured download speed in Mbps. null = not yet measured.
  double? _networkSpeedMbps;
  StreamSubscription<NetworkSpeedResult>? _networkSub;

  // ── Threshold below which AI Scan Invoice is disabled ─────────────────────
  static const double _scanMinSpeedMbps = 5.0;

  bool get _isScanEnabled => true; // Network speed gate disabled for now

  DateTimeRange? _selectedDateRange;
  String? _errorMessage;
  String? _selectedPaymentFilter; // null = All

  // Local filtering
  List<dynamic> get _filteredVouchers {
    if (_selectedPaymentFilter == null) return _vouchers;
    return _vouchers.where((v) {
      final status = (v['payment_info']?['payment_status'] ?? '')
          .toString()
          .toUpperCase();
      return status == _selectedPaymentFilter;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _fetchPurchases();

    // ── Start Adaptive Network Analyzer ─────────────────────────────────────
    final analyzer = AdaptiveNetworkAnalyzerService.instance;
    analyzer.start(measurementInterval: const Duration(seconds: 15));
    _networkSub = analyzer.stream.listen((result) {
      if (mounted) {
        setState(() => _networkSpeedMbps = result.speedMbps);
      }
    });
    // Seed with last known value if already running
    if (analyzer.lastResult != null) {
      _networkSpeedMbps = analyzer.lastResult!.speedMbps;
    }
  }

  @override
  void dispose() {
    _networkSub?.cancel();
    AdaptiveNetworkAnalyzerService.instance.stop();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasNextPage) {
      _fetchPurchases(isLoadMore: true);
    }
  }

  /// After data loads, check if content fills the viewport.
  /// If not and there's more data, auto-load the next page.
  void _loadUntilScrollable() {
    if (!mounted || !_hasNextPage || _isLoadingMore || _isLoading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0 && _hasNextPage && !_isLoadingMore) {
        _fetchPurchases(isLoadMore: true);
      }
    });
  }

  Future<void> _fetchPurchases({bool isLoadMore = false}) async {
    if (isLoadMore) {
      if (_isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final filters = <String, dynamic>{};
      if (_selectedDateRange != null) {
        filters['start_date'] = DateFormat(
          'yyyy-MM-dd',
        ).format(_selectedDateRange!.start);
        filters['end_date'] = DateFormat(
          'yyyy-MM-dd',
        ).format(_selectedDateRange!.end);
      }

      final result = await StoreOwnerApiService.getPurchaseEntries(
        widget.storeId,
        filters: filters,
        limit: _limit,
        offset: isLoadMore ? _offset + _limit : 0,
      );

      final vouchers = result['vouchers'] as List<dynamic>? ?? [];
      final count = result['count'] as int? ?? 0;
      // ignore: unused_local_variable
      final returned = result['returned'] as int? ?? 0;

      if (mounted) {
        setState(() {
          if (isLoadMore) {
            _vouchers.addAll(vouchers);
            _offset += _limit;
          } else {
            _vouchers = vouchers;
            _offset = 0;
          }
          _count = count;
          _hasNextPage = _vouchers.length < _count;
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = null;
        });
        _loadUntilScrollable();
      }
    } catch (e) {
      print('Error fetching purchases: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _fetchPurchases();
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return Colors.green;
      case 'PENDING':
        return Colors.orange;
      case 'PARTIAL':
        return Colors.blue;
      case 'CREDIT':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handleAiPurchase() async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => IntelligenceUploadDialog(storeId: widget.storeId),
    );

    debugPrint('[AI Purchase] dialog result: $result');

    if (result != null && result is Map<String, dynamic> && mounted) {
      final supplierResult = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) =>
              SupplierDetailsScreen(data: result, storeId: widget.storeId),
        ),
      );

      if (supplierResult != null &&
          supplierResult['continue'] == true &&
          mounted) {
        final supplierStoreId = supplierResult['supplierStoreId']?.toString();

        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailsScreen(
                data: result,
                storeId: widget.storeId,
                supplierStoreId: supplierStoreId,
              ),
            ),
          );
          // Refresh list after AI purchase flow completes
          if (mounted) _fetchPurchases();
        }
      }
    }
  }

  Widget _buildAddOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isFeatured = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFeatured
              ? color.withOpacity(0.3)
              : Colors.grey.withOpacity(0.15),
          width: isFeatured ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          if (isFeatured)
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          if (isFeatured) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'AI POWERED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey[300],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddPurchaseMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        // Capture the speed at the moment the sheet opens.
        final bool scanEnabled = _isScanEnabled;
        final double? speed = _networkSpeedMbps;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 40,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Add New Purchase',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how you want to add this record',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 32),

                  // ── Scan Invoice (AI) ──────────────────────────────────────
                  _buildScanInvoiceOption(
                    enabled: scanEnabled,
                    speedMbps: speed,
                    onTap: () {
                      Navigator.pop(context);
                      _handleAiPurchase();
                    },
                  ),

                  // ── Manual Entry ───────────────────────────────────────────
                  _buildAddOption(
                    title: 'Manual Entry',
                    subtitle: 'Fill in purchase details form manually',
                    icon: Icons.edit_note_rounded,
                    color: const Color(0xFF64748B),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddPurchaseOrderScreen(storeId: widget.storeId),
                        ),
                      );
                      // Refresh list after returning from manual entry
                      if (mounted) _fetchPurchases();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Dedicated card for "Scan Invoice" that shows network quality feedback.
  Widget _buildScanInvoiceOption({
    required bool enabled,
    required double? speedMbps,
    required VoidCallback onTap,
  }) {
    const color = Color(0xFF2563EB);
    final bool measuring = speedMbps == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: enabled ? const Color(0xFFDBEAFE) : const Color(0xFFE2E8F0),
          width: enabled ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: enabled
                        ? const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: enabled ? null : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: enabled ? Colors.white : Colors.grey[400],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Text column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Scan Invoice',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: enabled
                                  ? const Color(0xFF1E293B)
                                  : Colors.grey[400],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: enabled
                                  ? const Color(0xFFDBEAFE)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'AI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: enabled ? color : Colors.grey[400],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (enabled)
                        Text(
                          'Extract details automatically',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () => _showSlowNetworkDialog(
                            context,
                            currentSpeedMbps: speedMbps,
                          ),
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                                height: 1.3,
                              ),
                              children: [
                                const TextSpan(text: 'Network too slow — '),
                                TextSpan(
                                  text: 'Learn more',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (measuring) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Checking network speed…',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: enabled ? Colors.grey[300] : Colors.grey[200],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Slow-network info dialog ──────────────────────────────────────────────
  void _showSlowNetworkDialog(
    BuildContext context, {
    required double? currentSpeedMbps,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        // ── Shared mutable state ────────────────────────────────────────────
        double? liveSpeed = currentSpeedMbps;
        int countdown = 5;
        bool isMeasuring = false;
        Timer? countdownTimer;
        StreamSubscription<NetworkSpeedResult>? streamSub;

        StateSetter? _ss;

        void Function()? startCountdown;
        Future<void> Function()? refreshSpeed;

        refreshSpeed = () async {
          countdownTimer?.cancel();
          countdownTimer = null;
          _ss?.call(() {
            isMeasuring = true;
            countdown = 5;
          });

          // Trigger a fresh probe. The result will arrive via the stream
          // subscription below, ensuring the dialog and debug log always
          // show the same value (same Cloudflare call).
          await AdaptiveNetworkAnalyzerService.instance.measureOnce();

          // isMeasuring is reset inside the stream listener.
          // Restart countdown after probe completes.
          if (ctx.mounted) startCountdown?.call();
        };

        startCountdown = () {
          countdownTimer?.cancel();
          countdownTimer = null;

          countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
            if (!ctx.mounted) {
              t.cancel();
              return;
            }
            _ss?.call(() {
              if (countdown > 1) {
                countdown--;
              } else {
                t.cancel();
                countdownTimer = null;
                refreshSpeed?.call();
              }
            });
          });
        };

        return StatefulBuilder(
          builder: (ctx2, setState) {
            _ss = setState;

            // Subscribe to the service stream exactly once.
            // This ensures the dialog always shows the same value as the
            // debug log — both read from the same Cloudflare probe result.
            streamSub ??= AdaptiveNetworkAnalyzerService.instance.stream.listen(
              (result) {
                if (!ctx2.mounted) return;
                _ss?.call(() {
                  liveSpeed = result.speedMbps;
                  isMeasuring = false;
                  // Also keep parent page state in sync.
                  if (mounted) {
                    this.setState(() => _networkSpeedMbps = result.speedMbps);
                  }
                });
              },
            );

            // Boot the loop exactly once on first build.
            if (countdownTimer == null && !isMeasuring) {
              startCountdown?.call();
            }

            final String currentLabel = liveSpeed == null
                ? 'Measuring…'
                : '${liveSpeed!.toStringAsFixed(1)} Mbps';
            final double fraction = liveSpeed == null
                ? 0
                : (liveSpeed! / _scanMinSpeedMbps).clamp(0.0, 1.0);
            final bool isAbove =
                liveSpeed != null && liveSpeed! >= _scanMinSpeedMbps;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 40,
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header ──────────────────────────────────────────────
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.wifi_off_rounded,
                              color: Colors.redAccent,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Slow Internet Detected',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              countdownTimer?.cancel();
                              streamSub?.cancel();
                              Navigator.of(ctx).pop();
                            },
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.grey[400],
                              size: 22,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 20),

                      // ── Why disabled? ────────────────────────────────────────
                      _dialogSection(
                        icon: Icons.info_outline_rounded,
                        iconColor: const Color(0xFF2563EB),
                        title: 'Why is this feature disabled?',
                        body:
                            'The AI-powered Scan Invoice feature uploads your invoice image to our servers for intelligent data extraction. This process requires a stable connection of at least $_scanMinSpeedMbps Mbps to complete within a reasonable time.',
                      ),

                      const SizedBox(height: 16),

                      // ── Current speed card ───────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isAbove
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFFFF1F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isAbove
                                ? Colors.green.withOpacity(0.25)
                                : Colors.red.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Current speed',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                if (isMeasuring)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Color(0xFF2563EB),
                                    ),
                                  )
                                else
                                  Text(
                                    currentLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isAbove
                                          ? Colors.green[600]
                                          : Colors.red[400],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Speed bar
                            LayoutBuilder(
                              builder: (_, c) {
                                return Stack(
                                  children: [
                                    Container(
                                      height: 6,
                                      width: c.maxWidth,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 400,
                                      ),
                                      height: 6,
                                      width: c.maxWidth * fraction,
                                      decoration: BoxDecoration(
                                        color: isAbove
                                            ? Colors.green
                                            : Colors.redAccent,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    // Required threshold marker
                                    Positioned(
                                      left: c.maxWidth * 1.0 - 1,
                                      child: Container(
                                        width: 2,
                                        height: 6,
                                        color: const Color(0xFF2563EB),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '0 Mbps',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[400],
                                  ),
                                ),
                                Text(
                                  'Required: $_scanMinSpeedMbps Mbps',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF2563EB),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Auto-refresh countdown ───────────────────────────────
                      Center(
                        child: isMeasuring
                            ? Text(
                                'Measuring speed…',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.refresh_rounded,
                                    size: 14,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Refreshing in ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    transitionBuilder: (child, anim) =>
                                        SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0, -0.5),
                                            end: Offset.zero,
                                          ).animate(anim),
                                          child: FadeTransition(
                                            opacity: anim,
                                            child: child,
                                          ),
                                        ),
                                    child: Text(
                                      '$countdown',
                                      key: ValueKey(countdown),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    's…',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                      ),

                      const SizedBox(height: 16),

                      // ── Tips ────────────────────────────────────────────────
                      _dialogSection(
                        icon: Icons.tips_and_updates_outlined,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Tips to improve your connection',
                        body: null,
                        bullets: const [
                          'Move closer to your Wi-Fi router',
                          'Switch from mobile data to Wi-Fi (or vice versa)',
                          'Close background apps that consume bandwidth',
                          'Restart your router or toggle Airplane mode',
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Alternative / Good-to-go ─────────────────────────
                      if (isAbove) ...[
                        // Speed is now sufficient — show success banner
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_outline_rounded,
                                color: Colors.green,
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Your connection is now fast enough! You can scan your invoice.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF166534),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        // Speed still too low — show manual-entry hint
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_note_rounded,
                                color: Color(0xFF2563EB),
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'You can still add purchases manually using the Manual Entry option.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1E40AF),
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ── Primary action button ─────────────────────────────
                      if (isAbove) ...[
                        // Speed OK → offer Scan Invoice directly
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              countdownTimer?.cancel();
                              streamSub?.cancel();
                              Navigator.of(ctx).pop();
                              _handleAiPurchase();
                            },
                            icon: const Icon(Icons.auto_awesome, size: 18),
                            label: const Text(
                              'Scan Invoice',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              countdownTimer?.cancel();
                              streamSub?.cancel();
                              Navigator.of(ctx).pop();
                            },
                            child: Text(
                              'Close',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[500],
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        // Speed too low → dismiss only
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              countdownTimer?.cancel();
                              streamSub?.cancel();
                              Navigator.of(ctx).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Got it',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Helper: builds a labelled section inside the slow-network dialog.
  Widget _dialogSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String? body,
    List<String>? bullets,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (body != null)
          Text(
            body,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        if (bullets != null)
          ...bullets.map(
            (b) => Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  Expanded(
                    child: Text(
                      b,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        drawer: StoreMainDrawer(
          storeId: widget.storeId,
          storeName: widget.storeName ?? 'Store',
        ),
        extendBodyBehindAppBar: true,
        primary: false,
        backgroundColor: Colors.grey[50],
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildExpandedBanner(theme),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchPurchases,
                child: _buildBody(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String rawValue, Color color) {
    // Parse and format large numbers
    final double? numValue = double.tryParse(rawValue);
    String displayValue = rawValue;

    if (numValue != null && numValue > 999) {
      if (numValue >= 10000000) {
        displayValue = '${(numValue / 1000000).toStringAsFixed(0)}M';
      } else if (numValue >= 1000000) {
        displayValue = '${(numValue / 1000000).toStringAsFixed(1)}M';
      } else if (numValue >= 10000) {
        displayValue = '${(numValue / 1000).toStringAsFixed(0)}k';
      } else if (numValue >= 1000) {
        displayValue = '${(numValue / 1000).toStringAsFixed(1)}k';
      }
    }

    return Tooltip(
      message: '$title: $rawValue',
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2), // Reduced gap
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                displayValue,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(bool isMobile) {
    final cardWidth = isMobile ? null : 140.0;

    // Helper for responsive card
    Widget responsiveCard(String t, String v, Color c) {
      final card = _buildSummaryCard(t, v, c);
      if (isMobile) return Expanded(child: card);
      return SizedBox(width: cardWidth, child: card);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        mainAxisAlignment: isMobile
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.center,
        children: [
          responsiveCard(
            isMobile ? 'Total' : 'Total Purchases',
            _count.toString(),
            Colors.blue,
          ),
          const SizedBox(width: 4),
          responsiveCard(
            'Paid',
            _vouchers
                .where(
                  (v) =>
                      (v['payment_info']?['payment_status'] ?? '')
                          .toString()
                          .toUpperCase() ==
                      'PAID',
                )
                .length
                .toString(),
            Colors.green,
          ),
          const SizedBox(width: 4),
          responsiveCard(
            'Partial',
            _vouchers
                .where(
                  (v) =>
                      (v['payment_info']?['payment_status'] ?? '')
                          .toString()
                          .toUpperCase() ==
                      'PARTIAL',
                )
                .length
                .toString(),
            Colors.orange,
          ),
          const SizedBox(width: 4),
          responsiveCard(
            'Credit',
            _vouchers
                .where(
                  (v) =>
                      (v['payment_info']?['payment_status'] ?? '')
                          .toString()
                          .toUpperCase() ==
                      'CREDIT',
                )
                .length
                .toString(),
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedBanner(ThemeData theme) {
    const lightBlueBg = Color(0xFFEFF6FF);
    const watermarkColor = Color(0xFFDBEAFE);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: lightBlueBg,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRect(
        child: Stack(
          children: [
            // Watermark
            Positioned(
              right: -30,
              top: -10,
              child: Transform.rotate(
                angle: -math.pi / 6,
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 180,
                  color: watermarkColor.withOpacity(0.6),
                ),
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                MediaQuery.of(context).padding.top + 8,
                12,
                12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ROW 1: HEADER (Back/Menu, Title, filters)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Menu Button (Replaced Back)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TranslatedText(
                            'MENU',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.blueGrey[400],
                              letterSpacing: 1.2,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.menu_rounded,
                              color: Colors.blueGrey,
                              size: 32,
                            ),
                            onPressed: () {
                              if (widget.onMenuPressed != null) {
                                widget.onMenuPressed!();
                              } else {
                                _scaffoldKey.currentState?.openDrawer();
                              }
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TranslatedText(
                              'Purchases',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.5,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.2),
                                ),
                              ),
                              child: const TranslatedText(
                                'HISTORY',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.blue,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Date Filter Button
                      SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TranslatedText(
                              _selectedDateRange != null ? 'CLEAR' : 'DATE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: _selectedDateRange != null
                                    ? Colors.red[400]
                                    : Colors.blueGrey[400],
                                letterSpacing: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () {
                                if (_selectedDateRange != null) {
                                  setState(() {
                                    _selectedDateRange = null;
                                  });
                                  _fetchPurchases();
                                } else {
                                  _selectDateRange();
                                }
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _selectedDateRange != null
                                      ? Colors.red[50]
                                      : Colors.white,
                                  border: Border.all(
                                    color: _selectedDateRange != null
                                        ? Colors.red.withOpacity(0.2)
                                        : Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blueGrey.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _selectedDateRange != null
                                      ? Icons.close
                                      : Icons.calendar_today_rounded,
                                  size: 24,
                                  color: _selectedDateRange != null
                                      ? Colors.red
                                      : Colors.blueGrey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Refresh Button — desktop only
                      if (MediaQuery.of(context).size.width > 600)
                        SizedBox(
                          width: 70,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TranslatedText(
                                'REFRESH',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blueGrey[400],
                                  letterSpacing: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: _fetchPurchases,
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(
                                      color: Colors.blueGrey.withOpacity(0.2),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blueGrey.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.refresh_rounded,
                                    size: 24,
                                    color: Colors.blueGrey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (MediaQuery.of(context).size.width > 600)
                        const SizedBox(width: 8),

                      // New Purchase Button (Enhanced)
                      SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TranslatedText(
                              'NEW',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.blueGrey[400],
                                letterSpacing: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: _showAddPurchaseMenu,
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.transparent,
                                    width: 2,
                                  ),
                                  color: theme.primaryColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  size: 24,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Payment Status Filter Bar
                  _buildPaymentFilterBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentFilterBar() {
    final List<Map<String, dynamic>> filterOptions = [
      {
        'label': 'All',
        'id': null,
        'icon': Icons.grid_view_rounded,
        'color': Colors.blue,
      },
      {
        'label': 'Paid',
        'id': 'PAID',
        'icon': Icons.check_circle_outline,
        'color': Colors.green,
      },
      {
        'label': 'Partial',
        'id': 'PARTIAL',
        'icon': Icons.timelapse_rounded,
        'color': Colors.orange,
      },
      {
        'label': 'Credit',
        'id': 'CREDIT',
        'icon': Icons.money_off_rounded,
        'color': Colors.red,
      },
      {
        'label': 'Pending',
        'id': 'PENDING',
        'icon': Icons.hourglass_empty_rounded,
        'color': Colors.amber,
      },
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: filterOptions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final opt = filterOptions[index];
          final isSelected = _selectedPaymentFilter == opt['id'];
          return Center(
            child: InkWell(
              onTap: () {
                if (!isSelected) {
                  setState(() {
                    _selectedPaymentFilter = opt['id'];
                  });
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[700] : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(
                    color: isSelected ? Colors.blue[800]! : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Text(
                  opt['label'] ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.blueGrey[700],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _fetchPurchases(),
              child: const TranslatedText('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredVouchers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.black.withOpacity(0.1),
            ),
            const SizedBox(height: 16),
            TranslatedText(
              'No purchases found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.black.withOpacity(0.4),
              ),
            ),
            if (_selectedDateRange != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedDateRange = null;
                  });
                  _fetchPurchases();
                },
                child: const TranslatedText('Clear Filter'),
              ),
            ],
          ],
        ),
      );
    }

    final filtered = _filteredVouchers;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          // Table Layout for larger screens
          return Column(
            children: [
              _buildStatsSection(false),
              // Table Header
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9), // Painted title background
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _buildTableHeaderText('DATE')),
                    Expanded(flex: 2, child: _buildTableHeaderText('VOUCHER')),
                    Expanded(flex: 4, child: _buildTableHeaderText('SUPPLIER')),
                    Expanded(flex: 2, child: _buildTableHeaderText('AMOUNT')),
                    Expanded(flex: 2, child: _buildTableHeaderText('PAYMENT')),
                    Expanded(
                      flex: 2,
                      child: _buildTableHeaderText('VERIFICATION'),
                    ),
                    const SizedBox(width: 40), // Action
                  ],
                ),
              ),
              // Table Body
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _fetchPurchases(),
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey[200],
                    ),
                    itemBuilder: (context, index) {
                      if (index == filtered.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final voucher = filtered[index];
                      return _buildTabletPurchaseRow(
                        theme,
                        voucher,
                        index == filtered.length - 1,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        } else {
          // Mobile List Layout
          return ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              bottom: 30,
              left: 16,
              right: 16,
              top: 16,
            ),
            // +1 for Stats section, +1 for loading indicator if needed
            itemCount: filtered.length + 1 + (_isLoadingMore ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              // Item 0 is the Stats Section
              if (index == 0) {
                return _buildStatsSection(true);
              }

              // Adjust index for vouchers
              final voucherIndex = index - 1;

              // Last item loading indicator
              if (voucherIndex == filtered.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              return _buildPremiumPurchaseCard(theme, filtered[voucherIndex]);
            },
          );
        }
      },
    );
  }

  Widget _buildTableHeaderText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTabletPurchaseRow(
    ThemeData theme,
    dynamic voucher,
    bool isLast,
  ) {
    final paymentStatus =
        voucher['payment_info']?['payment_status'] ?? 'UNKNOWN';
    final statusColor = _getStatusColor(paymentStatus);
    final supplierName = voucher['supplier']?['name'] ?? 'Unknown Supplier';
    final voucherNumber = voucher['voucher_number'] ?? 'N/A';
    final verificationStatus = voucher['status'] ?? '';
    final grandTotal = voucher['grand_total'];
    final amount = '₹${grandTotal ?? 0}';
    final dateStr = voucher['date'] ?? '';

    // Determine verification badge details
    Color verifyColor = Colors.grey;
    String verifyText = '';
    IconData verifyIcon = Icons.help_outline;

    if (verificationStatus == 'PENDING') {
      verifyColor = Colors.orange;
      verifyText = 'Pending';
      verifyIcon = Icons.hourglass_empty_rounded;
    } else if (verificationStatus == 'VERIFIED') {
      verifyColor = Colors.green;
      verifyText = 'Verified';
      verifyIcon = Icons.verified_rounded;
    } else if (verificationStatus == 'REJECTED') {
      verifyColor = Colors.red;
      verifyText = 'Rejected';
      verifyIcon = Icons.cancel_outlined;
    }

    return Material(
      color: Colors.white,
      shape: isLast
          ? const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
            )
          : null,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PurchaseDetailsScreen(
                storeId: widget.storeId,
                purchaseData: voucher as Map<String, dynamic>,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[200]!),
              left: BorderSide(color: Colors.grey[200]!),
              right: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            children: [
              // Date
              Expanded(
                flex: 2,
                child: Text(
                  dateStr,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Voucher
              Expanded(
                flex: 2,
                child: Text(
                  "#$voucherNumber",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Supplier
              Expanded(
                flex: 4,
                child: Text(
                  supplierName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Amount
              Expanded(
                flex: 2,
                child: Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Payment Status
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      paymentStatus,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ),
              // Verification Status
              Expanded(
                flex: 2,
                child: verifyText.isNotEmpty
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: verifyColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(verifyIcon, size: 12, color: verifyColor),
                              const SizedBox(width: 4),
                              Text(
                                verifyText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: verifyColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox(),
              ),
              // Action
              SizedBox(
                width: 40,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumPurchaseCard(
    ThemeData theme,
    dynamic voucher, {
    bool isGrid = false,
  }) {
    final paymentStatus =
        voucher['payment_info']?['payment_status'] ?? 'UNKNOWN';
    final statusColor = _getStatusColor(paymentStatus);
    final supplierName = voucher['supplier']?['name'] ?? 'Unknown Supplier';
    final voucherNumber = voucher['voucher_number'] ?? 'N/A';
    final verificationStatus = voucher['status'] ?? '';

    final grandTotal = voucher['grand_total'];
    final amount = '₹${grandTotal ?? 0}';
    final dateStr = voucher['date'] ?? '';

    // Determine verification badge details
    Color verifyColor = Colors.grey;
    String verifyText = '';
    IconData verifyIcon = Icons.help_outline;

    if (verificationStatus == 'PENDING') {
      verifyColor = Colors.orange;
      verifyText = 'Pending';
      verifyIcon = Icons.hourglass_empty_rounded;
    } else if (verificationStatus == 'VERIFIED') {
      verifyColor = Colors.green;
      verifyText = 'Verified';
      verifyIcon = Icons.verified_rounded;
    } else if (verificationStatus == 'REJECTED') {
      verifyColor = Colors.red;
      verifyText = 'Rejected';
      verifyIcon = Icons.cancel_outlined;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PurchaseDetailsScreen(
                  storeId: widget.storeId,
                  purchaseData: voucher as Map<String, dynamic>,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Date & Voucher
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#$voucherNumber',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Supplier Name
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF), // Light blue
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          supplierName.isNotEmpty
                              ? supplierName[0].toUpperCase()
                              : 'S',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        supplierName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Colors.grey.withOpacity(0.2), // Fainter line
                ),
                const SizedBox(height: 12),

                // Footer: Amount & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          amount,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildModernStatusBadge(
                          text: paymentStatus,
                          color: statusColor,
                          icon: Icons.payments_rounded,
                        ),
                        if (verifyText.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: verifyColor.withOpacity(0.1),
                              border: Border.all(
                                color: verifyColor.withOpacity(0.2),
                              ),
                            ),
                            child: Icon(
                              verifyIcon,
                              size: 14,
                              color: verifyColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernStatusBadge({
    required String text,
    required Color color,
    required IconData icon,
    bool isOutlined = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOutlined ? Colors.transparent : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOutlined ? color.withOpacity(0.5) : color.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    const double dashWidth = 4;
    const double dashSpace = 4;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
