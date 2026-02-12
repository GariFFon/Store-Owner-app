import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:exanor/components/translation_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:exanor/services/api_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final String storeId;

  const OrderDetailsScreen({
    super.key,
    required this.orderId,
    required this.storeId,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _isLoadingOrder = true;
  bool _isLoadingProducts = true;
  bool _isLoadingStatuses = true;
  Map<String, dynamic>? _orderData;
  List<dynamic> _products = [];
  List<dynamic> _orderStatuses = [];
  List<dynamic> _statusOptions = [];
  List<dynamic> _storeBankDetails = [];
  String? _errorMessage;
  Timer? _statusTimer;
  bool _isUpdatingStatus = false;
  bool _isLoadingStatusOptions = true; // Initialize to true

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    _fetchOrderProducts();
    _startStatusPolling();
  }

  @override
  void dispose() {
    _stopStatusPolling();
    super.dispose();
  }

  void _startStatusPolling() {
    _fetchOrderStatuses(); // Fetch immediately
    _statusTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchOrderStatuses();
    });
  }

  void _stopStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  Future<void> _fetchOrderStatuses() async {
    try {
      final requestBody = {"order_id": widget.orderId, "query": {}};
      // print("🔄 Polling order status...");

      final response = await ApiService.post(
        '/order-status/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null &&
          response['data']['status'] == 200 &&
          mounted) {
        final List<dynamic> statuses = response['data']['response'] ?? [];
        setState(() {
          _orderStatuses = statuses;
          _isLoadingStatuses = false;
        });
      }
    } catch (e) {
      print("❌ Error fetching order statuses: $e");
    }
  }

  Future<void> _fetchStatusOptions() async {
    // Status options are now loaded from order details response
    // This method is kept for compatibility but uses local data
    if (_orderData != null && mounted) {
      setState(() {
        _statusOptions =
            _orderData!['allowed_order_status_options_for_store'] as List? ??
            [];
        _isLoadingStatusOptions = false;
      });
      print(
        "✅ Status options loaded from order data: ${_statusOptions.length} options",
      );
    }
  }

  Future<void> _fetchStoreBankDetails() async {
    try {
      final requestBody = {
        "store_id": widget.storeId,
        "store_access": true,
        "create": false,
        "order_by": "bank_name",
        "limit": 50,
      };

      final response = await ApiService.post(
        '/store-bank-details/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null &&
          response['data']['status'] == 200 &&
          mounted) {
        setState(() {
          _storeBankDetails = response['data']['response'] ?? [];
        });
        print(
          "✅ Store bank details fetched: ${_storeBankDetails.length} items",
        );
      }
    } catch (e) {
      print("❌ Error fetching store bank details: $e");
    }
  }

  Future<void> _updateOrderStatus(
    String status,
    String orderStatusId, {
    String? bankId,
    double? amountPaid,
  }) async {
    setState(() => _isUpdatingStatus = true);

    try {
      final requestBody = {
        "order_id": widget.orderId,
        "store_id": widget.storeId,
        "store_access": true,
        "order_status_id": orderStatusId,
      };

      if (amountPaid != null) {
        requestBody["amount_paid"] = amountPaid;
      }

      if (bankId != null) {
        if (status.contains('order_returned') ||
            status.contains('order_partially_returned')) {
          requestBody["refund_method_store_bank_id"] = bankId;
        } else {
          requestBody["payment_method_store_bank_id"] = bankId;
        }
      }

      final response = await ApiService.put(
        '/orders/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null &&
          (response['data']['status'] == 200 || response['status'] == 200)) {
        if (mounted) {
          Navigator.pop(context); // Close sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: TranslatedText('Order status updated')),
          );
          _fetchOrderDetails(); // Refresh details
          _fetchOrderStatuses(); // Refresh timeline
        }
      } else {
        throw Exception(response['message'] ?? 'Failed to update status');
      }
    } catch (e) {
      print("❌ Error updating order status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TranslatedText('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingStatus = false);
      }
    }
  }

  Future<void> _fetchOrderDetails() async {
    setState(() {
      _isLoadingOrder = true;
      _errorMessage = null;
    });

    try {
      final requestBody = {
        "page": 1,
        "query": {"id": widget.orderId},
        "store_id": widget.storeId,
        "store_access": true,
      };

      print("📦 Fetching order details for: ${widget.orderId}");

      final response = await ApiService.post(
        '/orders/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final orders = response['data']['response'] as List;
        if (orders.isNotEmpty) {
          if (mounted) {
            setState(() {
              _orderData = orders.first;
              // Extract status options from order data
              _statusOptions =
                  _orderData!['allowed_order_status_options_for_store']
                      as List? ??
                  [];
              _isLoadingStatusOptions = false;
              _isLoadingOrder = false;
            });
          }
          print("✅ Order details fetched successfully");
          print("✅ Status options loaded: ${_statusOptions.length} options");
        } else {
          setState(() {
            _errorMessage = "Order not found";
            _isLoadingOrder = false;
            _isLoadingStatusOptions = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = "Failed to fetch order details";
          _isLoadingOrder = false;
          _isLoadingStatusOptions = false;
        });
      }
    } catch (e) {
      print("❌ Error fetching order details: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Error loading order details";
          _isLoadingOrder = false;
        });
      }
    }
  }

  Future<void> _fetchOrderProducts() async {
    setState(() {
      _isLoadingProducts = true;
    });

    try {
      final requestBody = {"order_id": widget.orderId, "query": {}};

      print("📦 Fetching order products for: ${widget.orderId}");

      final response = await ApiService.post(
        '/orderdata-products/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        if (mounted) {
          setState(() {
            _products = response['data']['response'] as List? ?? [];
            _isLoadingProducts = false;
          });
        }
        print("✅ Order products fetched: ${_products.length} items");
      } else {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    } catch (e) {
      print("❌ Error fetching order products: $e");
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  Future<void> _launchInvoice() async {
    if (_orderData?['invoice_url'] != null) {
      final url = Uri.parse(_orderData!['invoice_url']);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: TranslatedText('Could not open invoice')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasInvoice = _orderData?['invoice_url'] != null;
    final hasStatusOptions = _statusOptions.isNotEmpty;

    // Show bottom action if we have content OR if we are still loading (to avoid pop)
    final showBottomAction =
        hasInvoice ||
        hasStatusOptions ||
        _isLoadingOrder ||
        _isLoadingStatusOptions;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildTopBanner(theme),
          Expanded(
            child: _errorMessage != null
                ? _buildErrorView(theme)
                : _isLoadingOrder
                ? _buildLoadingView(theme)
                : _buildOrderDetails(theme),
          ),
          if (showBottomAction) _buildBottomAction(theme),
        ],
      ),
    );
  }

  Widget _buildBottomAction(ThemeData theme) {
    // Determine visibility based on actual data or loading state
    // We assume invoice *might* be available if order is loading.
    // We assume statuses *might* be available if options are loading.
    final showInvoice = _orderData?['invoice_url'] != null || _isLoadingOrder;
    // Always show update status unless explicitly empty after load
    final showStatus = _statusOptions.isNotEmpty || _isLoadingStatusOptions;

    if (!showInvoice && !showStatus) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16, // Added top padding
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          if (showInvoice)
            Expanded(
              flex: 1,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _launchInvoice,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white, // Explicit white
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.shade300, // Stronger border
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.download_rounded,
                          color: theme.colorScheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: TranslatedText(
                            "Download Invoice",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (showInvoice && showStatus) const SizedBox(width: 12),
          if (showStatus)
            Expanded(
              flex: 1,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (_isLoadingStatusOptions)
                      return; // Prevent tap while loading
                    _showUpdateStatusSheet();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          const Color(0xFF2563EB),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isLoadingStatusOptions)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                              size: 16, // Smaller icon
                            ),
                          ),
                        const SizedBox(width: 8), // Reduced spacing
                        const Flexible(
                          child: TranslatedText(
                            "Update Status",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13, // Smaller text size
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 4,
                        ), // Shift text slightly left away from right border
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBanner(ThemeData theme) {
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
                  Icons.receipt_long_rounded,
                  size: 180,
                  color: watermarkColor.withOpacity(0.6),
                ),
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                16 + MediaQuery.of(context).padding.top,
                12,
                16,
              ),
              child: SizedBox(
                height: 64, // Increased height to prevent overflow (60 -> 64)
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Back Button
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.blueGrey.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Padding(
                            padding: EdgeInsets.only(right: 2),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.blueGrey,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_orderData == null)
                            Shimmer.fromColors(
                              baseColor: Colors.blueGrey.withOpacity(0.2),
                              highlightColor: Colors.blueGrey.withOpacity(0.1),
                              child: Container(
                                width: 150,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            )
                          else
                            TranslatedText(
                              _orderData!['user_name'] ??
                                  _orderData!['customer_name'] ??
                                  _orderData!['user_first_name'] ??
                                  _orderData!['name'] ??
                                  (_orderData!['billing_details'] is Map
                                      ? _orderData!['billing_details']['name']
                                      : null) ??
                                  'Guest Customer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B), // Slate 800
                                letterSpacing: -0.5,
                                height: 1.0,
                              ),
                            ),
                          const SizedBox(height: 4),
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
                              'ORDER DETAILS',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1565C0),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashedDivider(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Flex(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            direction: Axis.horizontal,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: dashHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.grey[300]),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  void _showUpdateStatusSheet() {
    _fetchStoreBankDetails();

    // Move state variables outside StatefulBuilder to prevent recreation
    String? selectedStatusId;
    String? selectedStatusValue;
    String? selectedBankId;
    final TextEditingController amountController = TextEditingController();

    // Pre-fill amount with Grand Total
    final double grandTotal =
        double.tryParse(_orderData?['grand_total']?.toString() ?? '0') ?? 0.0;
    amountController.text = grandTotal.toStringAsFixed(2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            final theme = Theme.of(context);

            final isOrderReturned =
                selectedStatusValue != null &&
                (selectedStatusValue!.contains('order_returned') ||
                    selectedStatusValue!.contains('order_partially_returned'));

            final isOrderCompleted =
                selectedStatusValue != null &&
                selectedStatusValue!.contains('order_completed');

            final isOrderPartiallyPaid =
                selectedStatusValue != null &&
                selectedStatusValue!.contains('order_partially_paid');

            final showPaymentOptions =
                isOrderReturned || isOrderCompleted || isOrderPartiallyPaid;
            final showAmountInput = isOrderCompleted || isOrderPartiallyPaid;

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          TranslatedText(
                            'Update Status',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.grey,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: Colors.grey.withOpacity(0.2)),

                    if (_isUpdatingStatus)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              TranslatedText(
                                'Updating order...',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Status Selection List
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _statusOptions.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final option = _statusOptions[index];
                                    final isSelected =
                                        selectedStatusId == option['id'];
                                    final statusColor =
                                        _getStatusColorFromString(
                                          option['status'],
                                        );

                                    return InkWell(
                                      onTap: () {
                                        setStateSheet(() {
                                          selectedStatusId = option['id'];
                                          selectedStatusValue =
                                              option['status'];
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white
                                              : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? statusColor
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: statusColor
                                                        .withOpacity(0.15),
                                                    blurRadius: 12,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: Row(
                                          children: [
                                            // Icon Box
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? statusColor.withOpacity(
                                                        0.1,
                                                      )
                                                    : Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? statusColor.withOpacity(
                                                          0.2,
                                                        )
                                                      : Colors.grey.shade200,
                                                ),
                                              ),
                                              child: Icon(
                                                _getStatusIcon(
                                                  option['status'],
                                                ),
                                                color: isSelected
                                                    ? statusColor
                                                    : Colors.grey.shade400,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  TranslatedText(
                                                    option['status_title_for_seller'] ??
                                                        option['status'],
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 15,
                                                      color: isSelected
                                                          ? const Color(
                                                              0xFF0F172A,
                                                            )
                                                          : Colors
                                                                .grey
                                                                .shade600,
                                                    ),
                                                  ),
                                                  if (isSelected &&
                                                      option['description'] !=
                                                          null)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 4,
                                                          ),
                                                      child: TranslatedText(
                                                        option['description'],
                                                        style: TextStyle(
                                                          color: statusColor,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (isSelected)
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: statusColor,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: statusColor
                                                          .withOpacity(0.4),
                                                      blurRadius: 6,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 14,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                // Payment & Action Section
                                if (selectedStatusId != null) ...[
                                  const SizedBox(height: 24),

                                  // Payment Receipt Card
                                  if (showAmountInput || showPaymentOptions)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 24),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.04,
                                            ),
                                            blurRadius: 16,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        children: [
                                          // Header Pattern
                                          Container(
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    top: Radius.circular(20),
                                                  ),
                                            ),
                                          ),

                                          if (showAmountInput)
                                            Padding(
                                              padding: const EdgeInsets.all(20),
                                              child: Column(
                                                children: [
                                                  TranslatedText(
                                                    'AMOUNT TO COLLECT',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 1.2,
                                                      color:
                                                          Colors.grey.shade500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  IntrinsicWidth(
                                                    child: TextField(
                                                      controller:
                                                          amountController,
                                                      keyboardType:
                                                          const TextInputType.numberWithOptions(
                                                            decimal: true,
                                                          ),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                        fontSize: 32,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Color(
                                                          0xFF0F172A,
                                                        ),
                                                        height: 1.2,
                                                      ),
                                                      decoration:
                                                          const InputDecoration(
                                                            prefixText: '₹',
                                                            prefixStyle:
                                                                TextStyle(
                                                                  fontSize: 32,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w800,
                                                                  color: Color(
                                                                    0xFF94A3B8,
                                                                  ),
                                                                ),
                                                            border: InputBorder
                                                                .none,
                                                            isDense: true,
                                                            contentPadding:
                                                                EdgeInsets.zero,
                                                          ),
                                                    ),
                                                  ),
                                                  Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                          top: 8,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: TranslatedText(
                                                      isOrderCompleted
                                                          ? 'Total: ₹${grandTotal.toStringAsFixed(2)}'
                                                          : 'Max: ₹${grandTotal.toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                          if (showAmountInput &&
                                              showPaymentOptions)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                  ),
                                              child: Row(
                                                children: List.generate(
                                                  30,
                                                  (index) => Expanded(
                                                    child: Container(
                                                      margin:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 2,
                                                          ),
                                                      height: 1,
                                                      color:
                                                          Colors.grey.shade200,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                          if (showPaymentOptions)
                                            Padding(
                                              padding: const EdgeInsets.all(20),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  TranslatedText(
                                                    isOrderReturned
                                                        ? 'REFUND VIA'
                                                        : 'PAYMENT VIA',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 1.2,
                                                      color:
                                                          Colors.grey.shade500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFF1F5F9,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      border: Border.all(
                                                        color: const Color(
                                                          0xFFE2E8F0,
                                                        ),
                                                      ),
                                                    ),
                                                    child: DropdownButtonHideUnderline(
                                                      child: DropdownButton<String>(
                                                        isExpanded: true,
                                                        value: selectedBankId,
                                                        hint: TranslatedText(
                                                          isOrderReturned
                                                              ? 'Select Refund Account'
                                                              : 'Select Payment Account',
                                                          style: TextStyle(
                                                            color: Colors
                                                                .grey
                                                                .shade500,
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        icon: const Icon(
                                                          Icons
                                                              .keyboard_arrow_down_rounded,
                                                          color: Color(
                                                            0xFF64748B,
                                                          ),
                                                        ),
                                                        style: const TextStyle(
                                                          color: Color(
                                                            0xFF0F172A,
                                                          ),
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                        items: _storeBankDetails.map((
                                                          bank,
                                                        ) {
                                                          final name =
                                                              bank['account_holder_name'] ??
                                                              bank['bank_name'] ??
                                                              'Unknown';
                                                          return DropdownMenuItem<
                                                            String
                                                          >(
                                                            value: bank['id'],
                                                            child: Text(name),
                                                          );
                                                        }).toList(),
                                                        onChanged: (value) {
                                                          setStateSheet(() {
                                                            selectedBankId =
                                                                value;
                                                          });
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                  /* Gradient Action Button */
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        colors: [
                                          theme.colorScheme.primary,
                                          theme.colorScheme.primary
                                              .withBlue(255)
                                              .withOpacity(0.8),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      onPressed: () {
                                        final amount = double.tryParse(
                                          amountController.text,
                                        );
                                        _updateOrderStatus(
                                          selectedStatusValue!,
                                          selectedStatusId!,
                                          bankId: selectedBankId,
                                          amountPaid: amount,
                                        );
                                      },
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const TranslatedText(
                                            'Update Status',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 20,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  /* Cancel Button */
                                  SizedBox(
                                    width: double.infinity,
                                    child: TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.grey.shade500,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: const TranslatedText(
                                        'Cancel',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          TranslatedText(
            _errorMessage ?? 'An error occurred',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _fetchOrderDetails();
              _fetchOrderProducts();
            },
            child: const TranslatedText('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
      highlightColor: theme.colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderDetails(ThemeData theme) {
    if (_orderData == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_fetchOrderDetails(), _fetchOrderProducts()]);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;

          if (isWide) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT COLUMN (Info, Billing, Payment)
                      Expanded(
                        flex: 4,
                        child: Column(
                          children: [
                            _buildLiveStatusBanner(theme),
                            const SizedBox(height: 16),
                            _buildOrderInfoCard(theme),
                            const SizedBox(height: 16),
                            if (_orderData!['billing_details'] != null) ...[
                              _buildBillingDetailsCard(theme),
                              const SizedBox(height: 16),
                            ],
                            if (_orderData!['payment_details'] != null) ...[
                              _buildPaymentDetailsCard(theme),
                              const SizedBox(height: 16),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // RIGHT COLUMN (Products, Price)
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            _buildProductsSection(theme),
                            const SizedBox(height: 16),
                            _buildPriceBreakdownCard(theme),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // MOBILE LAYOUT
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLiveStatusBanner(theme),
                    const SizedBox(height: 16),
                    _buildOrderInfoCard(theme),
                    const SizedBox(height: 16),
                    _buildProductsSection(theme),
                    const SizedBox(height: 16),
                    if (_orderData!['billing_details'] != null)
                      _buildBillingDetailsCard(theme),
                    const SizedBox(height: 16),
                    if (_orderData!['payment_details'] != null)
                      _buildPaymentDetailsCard(theme),
                    const SizedBox(height: 16),
                    _buildPriceBreakdownCard(theme),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25), // Strong dark matte shadow
            blurRadius: 6, // Tight but visible blur
            offset: const Offset(0, 3), // Distinct offset
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              TranslatedText(
                'Order Information',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            theme,
            'Customer',
            _orderData!['user_name'] ??
                _orderData!['customer_name'] ??
                _orderData!['user_first_name'] ??
                _orderData!['name'] ??
                (_orderData!['billing_details'] != null
                    ? _orderData!['billing_details']['name']
                    : null) ??
                'Guest Customer',
            Icons.person_rounded,
          ),
          Divider(
            color: theme.colorScheme.outline.withOpacity(0.08),
            height: 24,
            thickness: 1,
          ),
          _buildInfoRow(
            theme,
            'Store',
            _orderData!['store_name'] ?? 'N/A',
            Icons.store_rounded,
          ),
          Divider(
            color: theme.colorScheme.outline.withOpacity(0.08),
            height: 24,
            thickness: 1,
          ),
          _buildInfoRow(
            theme,
            'Order Method',
            _orderData!['order_method_name'] ?? 'N/A',
            Icons.delivery_dining_rounded,
          ),
          Divider(
            color: theme.colorScheme.outline.withOpacity(0.08),
            height: 24,
            thickness: 1,
          ),
          _buildInfoRow(
            theme,
            'Total Items',
            '${_orderData!['total_items'] ?? 0}',
            Icons.shopping_bag_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25), // Strong dark matte shadow
            blurRadius: 6, // Tight but visible blur
            offset: const Offset(0, 3), // Distinct offset
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              TranslatedText(
                'Products Ordered',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16), // Added spacing

          if (_isLoadingProducts)
            const Center(child: CircularProgressIndicator())
          else if (_products.isEmpty)
            Center(
              child: TranslatedText(
                'No products found',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            )
          else
            ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _products.length,
              separatorBuilder: (context, index) => _buildDashedDivider(theme),
              itemBuilder: (context, index) {
                final product = _products[index];
                return _buildProductItem(theme, product);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildProductItem(ThemeData theme, Map<String, dynamic> product) {
    final double quantity =
        double.tryParse(product['quantity']?.toString() ?? '0') ?? 0.0;

    // Clean up product name by removing quantity suffix if present
    // Example: "Dolo-650 - 1 pc" -> "Dolo-650"
    String productName = product['product_name'] ?? 'Unknown Product';
    final nameRegex = RegExp(
      r'^(.+?)\s*-\s*\d+\s*(pc|pcs|pieces?)?$',
      caseSensitive: false,
    );
    final nameMatch = nameRegex.firstMatch(productName);
    if (nameMatch != null && nameMatch.group(1) != null) {
      productName = nameMatch.group(1)!.trim();
    }

    // PRICING FIX:
    // Backend returns `amount_including_tax` as the TOTAL for all items (price × quantity)
    // Backend incorrectly returns `item_total` as `amount_including_tax × quantity` (doubled)
    // So we use `amount_including_tax` as the correct item total
    // And divide by quantity to get the per-piece unit price

    final double amountIncludingTax =
        double.tryParse(product['amount_including_tax']?.toString() ?? '0') ??
        0.0;

    // Calculate unit price: divide total by quantity
    double unitPrice = 0.0;
    if (quantity > 0 && amountIncludingTax > 0) {
      unitPrice = amountIncludingTax / quantity;
    }

    // Item total is `amount_including_tax` (already the correct total)
    // DO NOT multiply again!
    final double calculatedItemTotal = amountIncludingTax;

    final cgst = double.tryParse(product['cgst']?.toString() ?? '0') ?? 0.0;
    final sgst = double.tryParse(product['sgst']?.toString() ?? '0') ?? 0.0;
    final igst = double.tryParse(product['igst']?.toString() ?? '0') ?? 0.0;
    final cess = double.tryParse(product['cess']?.toString() ?? '0') ?? 0.0;
    final amountExcludingTax =
        double.tryParse(product['amount_excluding_tax']?.toString() ?? '0') ??
        0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15), // Matte shadow
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Name - Prominent at top
          Text(
            productName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          // Rate per unit - Subtle info row
          Row(
            children: [
              Icon(
                Icons.sell_outlined,
                size: 14,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(width: 6),
              Text(
                '₹${unitPrice.toStringAsFixed(2)} each',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Quantity and Total - Two equal columns
          Row(
            children: [
              // Quantity Column
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'QTY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary.withOpacity(0.7),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${quantity % 1 == 0 ? quantity.toInt() : quantity}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Total Column
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'TOTAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700.withOpacity(0.7),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${calculatedItemTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (cgst > 0 || sgst > 0 || igst > 0 || cess > 0) ...[
            const SizedBox(height: 12),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                    const SizedBox(width: 6),
                    TranslatedText(
                      'Tax Breakdown',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                children: [
                  _buildTaxRow(theme, 'Base Price', amountExcludingTax),
                  if (cgst > 0) _buildTaxRow(theme, 'CGST', cgst),
                  if (sgst > 0) _buildTaxRow(theme, 'SGST', sgst),
                  if (igst > 0) _buildTaxRow(theme, 'IGST', igst),
                  if (cess > 0) _buildTaxRow(theme, 'Cess', cess),
                  _buildDashedDivider(theme),
                  // Use Calculated Total here as well
                  _buildTaxRow(
                    theme,
                    'Total',
                    calculatedItemTotal,
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaxRow(
    ThemeData theme,
    String label,
    double amount, {
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TranslatedText(
            label,
            style: isTotal
                ? theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                : theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 11,
                  ),
          ),
          TranslatedText(
            '₹${amount.toStringAsFixed(2)}',
            style: isTotal
                ? theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                : theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 11,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillingDetailsCard(ThemeData theme) {
    final billing = _orderData!['billing_details'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25), // Strong dark matte shadow
            blurRadius: 6, // Tight but visible blur
            offset: const Offset(0, 3), // Distinct offset
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              TranslatedText(
                'Billing Address',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TranslatedText(
                      billing['area'] ?? 'N/A',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    TranslatedText(
                      '${billing['state'] ?? ''} - ${billing['pincode'] ?? ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailsCard(ThemeData theme) {
    final payment = _orderData!['payment_details'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25), // Strong dark matte shadow
            blurRadius: 6, // Tight but visible blur
            offset: const Offset(0, 3), // Distinct offset
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              TranslatedText(
                'Payment Details',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            theme,
            'Payment Method',
            payment['payment_method_name'] ?? 'N/A',
            Icons.payment_rounded,
          ),
          Divider(
            color: theme.colorScheme.outline.withOpacity(0.08),
            height: 24,
            thickness: 1,
          ),
          _buildInfoRow(
            theme,
            'Status',
            payment['payment_status'] ?? 'N/A',
            Icons.check_circle_outline_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdownCard(ThemeData theme) {
    final cartTotal = _orderData!['cart_total'] as List? ?? [];
    final platformFees = _orderData!['platform_fees'] as List? ?? [];
    final grandTotal = _orderData!['grand_total'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25), // Strong dark matte shadow
            blurRadius: 6, // Tight but visible blur
            offset: const Offset(0, 3), // Distinct offset
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              TranslatedText(
                'Price Breakdown',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          _buildDashedDivider(theme),

          // Cart Total Items
          ...cartTotal.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TranslatedText(
                    item['title'] ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  TranslatedText(
                    '₹${(item['value'] ?? 0.0).toStringAsFixed(2)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          // Platform Fees
          if (platformFees.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...platformFees.map((item) {
              // Only show numeric platform fees
              if (item['value'] is num ||
                  (item['value'] is String &&
                      double.tryParse(item['value']) != null)) {
                final String title = item['title'] ?? '';
                final bool isDiscount =
                    title.toLowerCase().contains('discount') ||
                    title.toLowerCase().contains('coupon') ||
                    title.toLowerCase().contains('off');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TranslatedText(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDiscount
                              ? Colors.green[700]
                              : theme.colorScheme.onSurface.withOpacity(0.7),
                          fontWeight: isDiscount ? FontWeight.w600 : null,
                        ),
                      ),
                      TranslatedText(
                        '₹${(double.tryParse(item['value'].toString()) ?? 0.0).toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDiscount ? Colors.green[700] : null,
                          fontWeight: isDiscount ? FontWeight.w700 : null,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],

          _buildDashedDivider(theme),

          // Grand Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TranslatedText(
                'Grand Total',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TranslatedText(
                '₹${grandTotal.toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary.withOpacity(0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TranslatedText(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 2),
              TranslatedText(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveStatusBanner(ThemeData theme) {
    if (_isLoadingStatuses && _orderStatuses.isEmpty) {
      return Shimmer.fromColors(
        baseColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        highlightColor: theme.colorScheme.surface,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
    }

    if (_orderStatuses.isEmpty) return const SizedBox.shrink();

    final orderId =
        _orderData?['order_number'] ??
        _orderData?['order_id'] ??
        _orderData?['id'] ??
        widget.orderId;

    // Get current status gradient
    final currentStatus = _orderStatuses.isNotEmpty
        ? _orderStatuses.last
        : {'status': 'Unknown'};
    final statusGradient = _getStatusGradient(currentStatus['status']);
    final statusColor = _getStatusColorFromString(currentStatus['status']);

    return Container(
      width: double.infinity,
      // Premium Status Gradient Decoration
      decoration: BoxDecoration(
        gradient: statusGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle Pattern Overlay
          Positioned(
            right: -20,
            top: -20,
            child: Opacity(
              opacity: 0.1,
              child: Icon(
                _getStatusIcon(currentStatus['status']),
                size: 140,
                color: Colors.white,
              ),
            ),
          ),
          Theme(
            data: theme.copyWith(
              dividerColor: Colors.transparent,
              expansionTileTheme: const ExpansionTileThemeData(
                iconColor: Colors.white,
                collapsedIconColor: Colors.white,
              ),
            ),
            child: ExpansionTile(
              initiallyExpanded: false,
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: const Icon(
                      Icons.timeline_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TranslatedText(
                        'Order Status',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (_orderStatuses.isNotEmpty)
                        TranslatedText(
                          currentStatus['status_title'] ??
                              currentStatus['status'] ??
                              'Unknown',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 16, left: 4),
                child: GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: orderId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: TranslatedText('Order ID copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Order ID: ',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '#$orderId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.copy_rounded,
                          size: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              children: [
                Divider(color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 16),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _orderStatuses.length,
                  itemBuilder: (context, index) {
                    // Reverse order: Newest at top
                    final status =
                        _orderStatuses[_orderStatuses.length - 1 - index];
                    final isFirst = index == 0;
                    final isLast = index == _orderStatuses.length - 1;

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Timestamp Column
                          SizedBox(
                            width: 70,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                TranslatedText(
                                  (status['timestamp'] ?? '').split(' ').first,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                TranslatedText(
                                  (status['timestamp'] ?? '')
                                              .split(' ')
                                              .length >
                                          1
                                      ? (status['timestamp'] ?? '')
                                            .split(' ')
                                            .sublist(1)
                                            .join(' ')
                                      : '',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Timeline Line & Dot
                          Column(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: isFirst
                                      ? Colors.white
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isFirst
                                        ? Colors.white
                                        : Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  boxShadow: isFirst
                                      ? [
                                          BoxShadow(
                                            color: Colors.white.withOpacity(
                                              0.5,
                                            ),
                                            blurRadius: 8,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : [],
                                ),
                              ),
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.white.withOpacity(0.3),
                                          Colors.white.withOpacity(0.05),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Content
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(
                                    status['status_title'] ??
                                        status['status'] ??
                                        '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (status['status_subtitle'] != null) ...[
                                    const SizedBox(height: 4),
                                    SelectableText(
                                      status['status_subtitle'],
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.white.withOpacity(0.7),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColorFromString(String? status) {
    status = status?.toLowerCase() ?? '';
    if (status.contains('placed') || status.contains('confirmed')) {
      return const Color(0xFF2563EB);
    } else if (status.contains('preparing') || status.contains('processing')) {
      return const Color(0xFFEA580C);
    } else if (status.contains('ready') || status.contains('completed')) {
      return const Color(0xFF059669);
    } else if (status.contains('cancelled') || status.contains('rejected')) {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFF7C3AED);
  }

  LinearGradient _getStatusGradient(String? status) {
    status = status?.toLowerCase() ?? '';
    if (status.contains('placed') || status.contains('confirmed')) {
      return const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF3B82F6)], // Royal Blue to Blue
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (status.contains('preparing') || status.contains('processing')) {
      return const LinearGradient(
        colors: [Color(0xFFEA580C), Color(0xFFF97316)], // Orange to Amber
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (status.contains('ready') || status.contains('completed')) {
      return const LinearGradient(
        colors: [Color(0xFF059669), Color(0xFF10B981)], // Emerald to Teal
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (status.contains('cancelled') || status.contains('rejected')) {
      return const LinearGradient(
        colors: [Color(0xFFDC2626), Color(0xFFEF4444)], // Red to Rose
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return const LinearGradient(
      colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)], // Violet to Purple
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  IconData _getStatusIcon(String? status) {
    status = status?.toLowerCase() ?? '';
    if (status.contains('placed') || status.contains('confirmed')) {
      return Icons.check_circle_outline_rounded;
    } else if (status.contains('preparing') || status.contains('processing')) {
      return Icons.soup_kitchen_rounded;
    } else if (status.contains('ready') || status.contains('completed')) {
      return Icons.done_all_rounded;
    } else if (status.contains('cancelled') || status.contains('rejected')) {
      return Icons.cancel_outlined;
    }
    return Icons.info_outline_rounded;
  }
}

class _ProductReviewItem extends StatefulWidget {
  final Map<String, dynamic> product;
  final String orderId;
  final ThemeData theme;

  const _ProductReviewItem({
    required this.product,
    required this.orderId,
    required this.theme,
  });

  @override
  State<_ProductReviewItem> createState() => _ProductReviewItemState();
}

class _ProductReviewItemState extends State<_ProductReviewItem> {
  int _rating = 0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isExpanded = false;
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  Future<void> _submitReview() async {
    if (_rating == 0) return;

    setState(() => _isSubmitting = true);

    try {
      final requestBody = {
        "order_id": widget.orderId,
        "product_combination_id":
            widget.product['product_combination_id'] ?? widget.product['id'],
        "rating": _rating,
        "review": _reviewController.text,
      };

      final response = await ApiService.post(
        '/review-order-product/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['status'] == 200 || response['data']?['status'] == 200) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _isSubmitted = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatedText('Review submitted successfully!'),
            ),
          );
        }
      } else if (response['status'] == 500 &&
          response['response'].toString().toLowerCase().contains(
            "review already exists",
          )) {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _isSubmitted = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatedText('You have already reviewed this item'),
            ),
          );
        }
      } else {
        throw Exception(
          response['message'] ??
              response['response'] ??
              'Failed to submit review',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TranslatedText('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.theme.colorScheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.theme.colorScheme.primary.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: widget.theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: TranslatedText(
                'Thanks for your review!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded
              ? widget.theme.colorScheme.primary.withOpacity(0.5)
              : widget.theme.dividerColor.withOpacity(0.1),
        ),
        boxShadow: [
          if (_isExpanded)
            BoxShadow(
              color: widget.theme.colorScheme.primary.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Info Row (Similar to original)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  size: 20,
                  color: widget.theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TranslatedText(
                      widget.product['product_name'] ?? 'Unknown Product',
                      style: widget.theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TranslatedText(
                      'How was this item?',
                      style: widget.theme.textTheme.bodySmall?.copyWith(
                        color: widget.theme.colorScheme.onSurface.withOpacity(
                          0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Rating Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _rating = index + 1;
                    _isExpanded = true;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AnimatedScale(
                    scale: _rating > index ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      index < _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: index < _rating
                          ? Colors.amber
                          : widget.theme.disabledColor,
                      size: 32,
                    ),
                  ),
                ),
              );
            }),
          ),

          // Review Textbox
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const SizedBox(height: 16),
                TextField(
                  controller: _reviewController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Write your review here...',
                    hintStyle: TextStyle(
                      color: widget.theme.colorScheme.onSurface.withOpacity(
                        0.4,
                      ),
                    ),
                    filled: true,
                    fillColor: widget.theme.scaffoldBackgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const TranslatedText('Submit Review'),
                  ),
                ),
              ],
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

class _ReviewCarousel extends StatefulWidget {
  final List<dynamic> products;
  final String orderId;
  final ThemeData theme;

  const _ReviewCarousel({
    required this.products,
    required this.orderId,
    required this.theme,
  });

  @override
  State<_ReviewCarousel> createState() => _ReviewCarouselState();
}

class _ReviewCarouselState extends State<_ReviewCarousel> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Progress Indicator
        Row(
          children: [
            TranslatedText(
              'Reviewing ${_currentIndex + 1}/${widget.products.length}',
              style: widget.theme.textTheme.bodySmall?.copyWith(
                color: widget.theme.colorScheme.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (widget.products.length > 1) ...[
              IconButton(
                onPressed: _currentIndex > 0
                    ? () => setState(() => _currentIndex--)
                    : null,
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: _currentIndex < widget.products.length - 1
                    ? () => setState(() => _currentIndex++)
                    : null,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Active Review Item
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.1, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_currentIndex),
            child: _ProductReviewItem(
              product: widget.products[_currentIndex],
              orderId: widget.orderId,
              theme: widget.theme,
            ),
          ),
        ),

        // Dots Indicator
        if (widget.products.length > 1) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.products.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentIndex == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentIndex == index
                      ? widget.theme.colorScheme.primary
                      : widget.theme.disabledColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
