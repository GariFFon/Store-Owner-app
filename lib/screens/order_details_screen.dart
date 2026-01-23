import 'dart:async';
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
  String? _errorMessage;
  Timer? _statusTimer;

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
              _isLoadingOrder = false;
            });
          }
          print("✅ Order details fetched successfully");
        } else {
          setState(() {
            _errorMessage = "Order not found";
            _isLoadingOrder = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = "Failed to fetch order details";
          _isLoadingOrder = false;
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

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const TranslatedText('Order Details'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_orderData?['invoice_url'] != null)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              onPressed: _launchInvoice,
              tooltip: 'Download Invoice',
            ),
        ],
      ),
      body: _errorMessage != null
          ? _buildErrorView(theme)
          : _isLoadingOrder
          ? _buildLoadingView(theme)
          : _buildOrderDetails(theme),
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
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live Order Status Banner
            _buildLiveStatusBanner(theme),
            const SizedBox(height: 16),

            // Store & Order Info
            _buildOrderInfoCard(theme),
            const SizedBox(height: 16),

            // Products Ordered
            _buildProductsSection(theme),
            const SizedBox(height: 16),

            // Billing Details
            if (_orderData!['billing_details'] != null)
              _buildBillingDetailsCard(theme),
            const SizedBox(height: 16),

            // Payment Details
            if (_orderData!['payment_details'] != null)
              _buildPaymentDetailsCard(theme),
            const SizedBox(height: 16),

            // Price Breakdown
            _buildPriceBreakdownCard(theme),
            const SizedBox(height: 16),

            // Invoice Button
            if (_orderData!['invoice_url'] != null) _buildInvoiceButton(theme),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfoCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            'Order Information',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            theme,
            'Store',
            _orderData!['store_name'] ?? 'N/A',
            Icons.store_rounded,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            theme,
            'Order Method',
            _orderData!['order_method_name'] ?? 'N/A',
            Icons.delivery_dining_rounded,
          ),
          const Divider(height: 24),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            'Products Ordered',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
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
              separatorBuilder: (context, index) => const Divider(height: 24),
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
    final quantity = product['quantity'] ?? 0;
    final itemTotal =
        double.tryParse(product['item_total']?.toString() ?? '0') ?? 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TranslatedText(
            '${quantity}x',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TranslatedText(
                product['product_name'] ?? 'Unknown Product',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              TranslatedText(
                '₹${itemTotal.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        TranslatedText(
          '₹${itemTotal.toStringAsFixed(2)}',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildBillingDetailsCard(ThemeData theme) {
    final billing = _orderData!['billing_details'] as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            'Billing Address',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            'Payment Details',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            theme,
            'Payment Method',
            payment['payment_method_name'] ?? 'N/A',
            Icons.payment_rounded,
          ),
          const Divider(height: 24),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            'Price Breakdown',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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
            const Divider(height: 24),
            ...platformFees.map((item) {
              // Only show numeric platform fees
              if (item['value'] is num ||
                  (item['value'] is String &&
                      double.tryParse(item['value']) != null)) {
                return Padding(
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
                        '₹${(double.tryParse(item['value'].toString()) ?? 0.0).toStringAsFixed(2)}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],

          const Divider(height: 24),

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

  Widget _buildInvoiceButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _launchInvoice,
        icon: const Icon(Icons.download_rounded),
        label: const TranslatedText('Download Invoice'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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
    Color statusColor = _getStatusColorFromString(status);
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
// ... (existing code for _ProductReviewItem will be appended to the file)

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
