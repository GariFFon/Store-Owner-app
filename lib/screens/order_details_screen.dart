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
        _statusOptions = _orderData!['allowed_order_status_options_for_store'] as List? ?? [];
        _isLoadingStatusOptions = false;
      });
      print("✅ Status options loaded from order data: ${_statusOptions.length} options");
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
              _statusOptions = _orderData!['allowed_order_status_options_for_store'] as List? ?? [];
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

            // Reset amount controller when switching to partially paid (user should enter amount)
            // But validation logic is complex in build(), so we handle initial values carefully or rely on user editing.
            // For completed, we pre-fill full amount. For partial, we might want it empty or 0.
            // A simple approach is handled in the UI logic below or just letting user edit.

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                padding: const EdgeInsets.only(top: 20, bottom: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TranslatedText(
                            'Change Order Status',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),

                    if (_isUpdatingStatus)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      // Status Selection List
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  10,
                                  20,
                                  10,
                                ),
                                child: TranslatedText(
                                  'Select New Status *',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal:
                                      10, // Adjusted margin for grid/list
                                ),
                                child: ListView.separated(
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
                                              ? statusColor.withOpacity(0.1)
                                              : theme.cardColor,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? statusColor
                                                : theme.dividerColor
                                                      .withOpacity(0.1),
                                            width: isSelected ? 2 : 1,
                                          ),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: statusColor
                                                        .withOpacity(0.2),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : [],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? statusColor
                                                    : theme.disabledColor
                                                          .withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                _getStatusIcon(
                                                  option['status'],
                                                ),
                                                color: isSelected
                                                    ? Colors.white
                                                    : theme.iconTheme.color
                                                          ?.withOpacity(0.5),
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
                                                    style: theme
                                                        .textTheme
                                                        .titleMedium
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isSelected
                                                              ? theme
                                                                    .colorScheme
                                                                    .onSurface
                                                              : theme
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withOpacity(
                                                                      0.7,
                                                                    ),
                                                        ),
                                                  ),
                                                  if (isSelected) ...[
                                                    const SizedBox(height: 4),
                                                    TranslatedText(
                                                      option['description'] ??
                                                          'Tap Update to confirm',
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color: theme
                                                                .colorScheme
                                                                .onSurface
                                                                .withOpacity(
                                                                  0.5,
                                                                ),
                                                          ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            if (isSelected)
                                              Icon(
                                                Icons.check_circle_rounded,
                                                color: statusColor,
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Info Banner for selected status
                              if (selectedStatusId != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            TranslatedText(
                                              selectedStatusValue ?? '',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.blue.shade800,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            TranslatedText(
                                              _statusOptions.firstWhere(
                                                    (e) =>
                                                        e['id'] ==
                                                        selectedStatusId,
                                                  )['description'] ??
                                                  'Status update',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: Colors.blue.shade900,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Amount Paid Input (For order_completed & order_partially_paid)
                              if (showAmountInput) ...[
                                const SizedBox(height: 20),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Row(
                                    children: [
                                      TranslatedText(
                                        'Amount Paid',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: theme.colorScheme.onSurface
                                                  .withOpacity(0.6),
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Divider(
                                          color: theme.dividerColor.withOpacity(
                                            0.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: TextField(
                                    controller: amountController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: theme.dividerColor.withOpacity(
                                            0.2,
                                          ),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: theme.dividerColor.withOpacity(
                                            0.2,
                                          ),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                    ),
                                    onTap: () {
                                      // Make it easier to edit by selecting all if pre-filled
                                      amountController.selection =
                                          TextSelection(
                                            baseOffset: 0,
                                            extentOffset:
                                                amountController.text.length,
                                          );
                                    },
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 4,
                                  ),
                                  child: TranslatedText(
                                    isOrderCompleted
                                        ? 'Full amount (₹${grandTotal.toStringAsFixed(2)}) will be recorded as paid'
                                        : 'Maximum: ₹${grandTotal.toStringAsFixed(2)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.5),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],

                              // Payment/Refund Method (Bank Account) Dropdown
                              if (showPaymentOptions) ...[
                                const SizedBox(height: 20),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TranslatedText(
                                          isOrderReturned
                                              ? 'Refund Method (Bank Account)'
                                              : 'Payment Method (Bank Account)',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Divider(
                                          color: Colors.blue.withOpacity(0.3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.5),
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: ButtonTheme(
                                      alignedDropdown: true,
                                      child: DropdownButton<String>(
                                        isExpanded: true,
                                        value: selectedBankId,
                                        hint: TranslatedText(
                                          isOrderReturned
                                              ? 'Select Refund Account'
                                              : 'Select Payment Account',
                                        ),
                                        items: _storeBankDetails.map((bank) {
                                          final name =
                                              bank['account_holder_name'] ??
                                              bank['bank_name'] ??
                                              'Unknown Account';
                                          final number =
                                              bank['account_number_or_upi_id'] ??
                                              '';
                                          return DropdownMenuItem<String>(
                                            value: bank['id'],
                                            child: Text('$name ($number)'),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setStateSheet(() {
                                            selectedBankId = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 4,
                                  ),
                                  child: TranslatedText(
                                    'Optional - defaults to cash if not selected',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 30),

                              // Update Button
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const TranslatedText('CANCEL'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            theme.colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: selectedStatusId == null
                                          ? null
                                          : () {
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
                                      child: const TranslatedText(
                                        'UPDATE STATUS',
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
          _buildDashedDivider(theme),
          _buildInfoRow(
            theme,
            'Store',
            _orderData!['store_name'] ?? 'N/A',
            Icons.store_rounded,
          ),
          _buildDashedDivider(theme),
          _buildInfoRow(
            theme,
            'Order Method',
            _orderData!['order_method_name'] ?? 'N/A',
            Icons.delivery_dining_rounded,
          ),
          _buildDashedDivider(theme),
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
          else if (_orderData?['status'] == 'order_completed' &&
              _products.length > 1)
            _ReviewCarousel(
              products: _products,
              orderId: widget.orderId,
              theme: theme,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _products.length,
              separatorBuilder: (context, index) => _buildDashedDivider(theme),
              itemBuilder: (context, index) {
                final product = _products[index];
                // Check if order is completed to show review items
                final isCompleted = _orderData?['status'] == 'order_completed';

                if (isCompleted) {
                  return _ProductReviewItem(
                    product: product,
                    orderId: widget.orderId,
                    theme: theme,
                  );
                }

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
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Name - Prominent at top
          Text(
            product['product_name'] ?? 'Unknown Product',
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
          _buildDashedDivider(theme),
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
          const SizedBox(height: 16),

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
            const SizedBox(height: 8), // Replaced Divider with minimal spacing
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
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }

    if (_orderStatuses.isEmpty) return const SizedBox.shrink();

    final latestStatus = _orderStatuses.last;
    final pastStatuses = _orderStatuses.length > 1
        ? _orderStatuses.sublist(0, _orderStatuses.length - 1).reversed.toList()
        : [];

    final bannerColor = _getStatusColorFromString(latestStatus['status']);
    final orderId =
        _orderData?['order_number'] ??
        _orderData?['order_id'] ??
        _orderData?['id'] ??
        widget.orderId;
    final timestamp = latestStatus['timestamp'] ?? '';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main Status
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnimatedStatusIcon(theme, latestStatus['status']),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TranslatedText(
                        latestStatus['status_title'] ?? 'Updating...',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TranslatedText(
                        latestStatus['status_subtitle'] ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (timestamp.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                  const SizedBox(width: 6),
                                  TranslatedText(
                                    latestStatus['timestamp'] ?? '',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: orderId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: TranslatedText(
                                    'Order ID copied to clipboard',
                                  ),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.receipt_long_rounded,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                  const SizedBox(width: 6),
                                  TranslatedText(
                                    'Order ID: ${orderId.toString().length > 12 ? "${orderId.toString().substring(0, 8)}..." : orderId}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 12,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider if there are past statuses
          if (pastStatuses.isNotEmpty)
            Divider(height: 1, color: Colors.white.withOpacity(0.2)),

          // Expandable Past Statuses
          if (pastStatuses.isNotEmpty)
            Theme(
              data: theme.copyWith(
                dividerColor: Colors.transparent,
                expansionTileTheme: ExpansionTileThemeData(
                  iconColor: Colors.white,
                  collapsedIconColor: Colors.white,
                  textColor: Colors.white,
                  collapsedTextColor: Colors.white,
                ),
              ),
              child: ExpansionTile(
                title: TranslatedText(
                  'Past Updates',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: pastStatuses.length,
                    itemBuilder: (context, index) {
                      final status = pastStatuses[index];
                      final isLast = index == pastStatuses.length - 1;
                      return _buildTimelineItem(
                        theme,
                        status,
                        isLast: isLast,
                        isDarkBg: true,
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

  Widget _buildAnimatedStatusIcon(ThemeData theme, String? status) {
    IconData iconData = _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
      ),
      child: Icon(iconData, color: Colors.white, size: 24),
    );
  }

  Widget _buildTimelineItem(
    ThemeData theme,
    dynamic status, {
    bool isLast = false,
    bool isDarkBg = false,
  }) {
    Color statusColor = _getStatusColorFromString(
      status['status']?.toString().toLowerCase(),
    );

    // If on dark background, use white for text and lighter status color
    final titleColor = isDarkBg
        ? Colors.white
        : theme.textTheme.bodyMedium?.color;
    final subtitleColor = isDarkBg
        ? Colors.white.withOpacity(0.8)
        : theme.colorScheme.onSurface.withOpacity(0.6);
    final timestampColor = isDarkBg
        ? Colors.white.withOpacity(0.6)
        : theme.colorScheme.onSurface.withOpacity(0.4);
    final dotColor = isDarkBg ? Colors.white : statusColor;
    final lineColor = isDarkBg
        ? Colors.white.withOpacity(0.2)
        : theme.dividerColor.withOpacity(0.1);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor.withOpacity(0.8),
                  shape: BoxShape.circle,
                  border: isDarkBg
                      ? Border.all(color: Colors.white, width: 1.5)
                      : null,
                ),
              ),
              if (!isLast)
                Expanded(child: Container(width: 2, color: lineColor)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(
                    status['status_title'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TranslatedText(
                    status['status_subtitle'] ?? '',
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  TranslatedText(
                    status['timestamp'] ?? '',
                    style: TextStyle(color: timestampColor, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColorFromString(String? status) {
    status = status?.toLowerCase() ?? '';
    if (status.contains('placed') || status.contains('confirmed')) {
      return Colors.green;
    } else if (status.contains('preparing') || status.contains('processing')) {
      return Colors.orange;
    } else if (status.contains('ready') || status.contains('completed')) {
      return Colors.blue;
    } else if (status.contains('cancelled') || status.contains('rejected')) {
      return Colors.red;
    }
    return Colors.purple;
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
