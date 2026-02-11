import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/models/coupon.dart';
import 'package:exanor/screens/create_coupon_bottom_sheet.dart';
import 'package:exanor/screens/edit_coupon_bottom_sheet.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class CouponsScreen extends StatefulWidget {
  final String storeId;

  const CouponsScreen({super.key, required this.storeId});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  List<Coupon> _coupons = [];
  int _currentPage = 1;
  bool _hasNextPage = false;
  bool _isLoadMoreRunning = false;

  // Search state
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchCoupons();
    _scrollController.addListener(_loadMore);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_loadMore);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCoupons({String? query}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> queryParams = {};
      if (query != null && query.isNotEmpty) {
        queryParams['coupon_code'] = query;
      }

      final response = await StoreOwnerApiService.getCoupons(
        storeId: widget.storeId,
        page: 1,
        query: queryParams,
      );

      final List<dynamic> couponsJson = response['response'] ?? [];
      final pagination = response['pagination'];

      setState(() {
        _coupons = couponsJson.map((json) => Coupon.fromJson(json)).toList();
        _hasNextPage = pagination != null ? pagination['has_next'] : false;
        _isLoading = false;
        _currentPage = 1;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TranslatedText('Error fetching coupons: $e')),
      );
    }
  }

  Future<void> _loadMore() async {
    if (_hasNextPage &&
        !_isLoading &&
        !_isLoadMoreRunning &&
        _scrollController.hasClients) {
      // Check if near the end - use larger threshold for grid view
      final position = _scrollController.position;
      final isNearEnd =
          position.extentAfter < 500 ||
          position.pixels >= position.maxScrollExtent - 200;

      if (!isNearEnd) return;

      setState(() {
        _isLoadMoreRunning = true;
      });

      try {
        final Map<String, dynamic> queryParams = {};
        if (_searchController.text.isNotEmpty) {
          queryParams['coupon_code'] = _searchController.text;
        }

        final nextPage = _currentPage + 1;
        final response = await StoreOwnerApiService.getCoupons(
          storeId: widget.storeId,
          page: nextPage,
          query: queryParams,
        );

        final List<dynamic> couponsJson = response['response'] ?? [];
        final pagination = response['pagination'];

        setState(() {
          _coupons.addAll(
            couponsJson.map((json) => Coupon.fromJson(json)).toList(),
          );
          _hasNextPage = pagination != null ? pagination['has_next'] : false;
          _currentPage = nextPage;
          _isLoadMoreRunning = false;
        });
      } catch (e) {
        setState(() {
          _isLoadMoreRunning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TranslatedText('Error loading more coupons: $e')),
        );
      }
    }
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
        extendBodyBehindAppBar: true,
        primary: false,
        backgroundColor: Colors.grey[50], // Consistent background
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Expanded Banner (With NEW button)
            _buildExpandedBanner(theme),

            // 2. Search Bar (Conditional)
            if (_isSearchExpanded)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search coupons...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (value) => _fetchCoupons(query: value),
                ),
              ),

            // 3. Main Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => await _fetchCoupons(),
                child: _buildBody(theme),
              ),
            ),
          ],
        ),
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
                  Icons.local_offer_outlined,
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
                  // ROW 1: HEADER
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
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
                                color: Colors.black87,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TranslatedText(
                              'Coupons',
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
                                'MANAGEMENT',
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

                      // Search Button
                      SizedBox(
                        width: 70,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TranslatedText(
                              'SEARCH',
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
                              onTap: () {
                                setState(() {
                                  _isSearchExpanded = !_isSearchExpanded;
                                  if (!_isSearchExpanded) {
                                    _searchController.clear();
                                    _fetchCoupons(query: '');
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(
                                    color: Colors.white,
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
                                  _isSearchExpanded
                                      ? Icons.close
                                      : Icons.search_rounded,
                                  size: 24,
                                  color: Colors.blueGrey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Create Coupon Button (In Banner)
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
                              onTap: () async {
                                final result = await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => CreateCouponBottomSheet(
                                    storeId: widget.storeId,
                                  ),
                                );

                                if (result == true) {
                                  _fetchCoupons();
                                }
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.primaryColor,
                                  border: Border.all(
                                    color: Colors.transparent,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.all(2.0),
                                      child: Icon(
                                        Icons.local_offer_rounded,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: theme.primaryColor,
                                            width: 1,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          size: 10,
                                          color: theme.primaryColor,
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
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_coupons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_offer_outlined,
                size: 64,
                color: Colors.black.withOpacity(0.2),
              ),
            ),
            const SizedBox(height: 24),
            TranslatedText(
              'No Coupons Found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.black.withOpacity(0.4),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 600) {
          // Tablet Layout
          return GridView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              100,
            ), // Extra bottom padding
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisExtent: 230, // Reduced for horizontal card layout
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _coupons.length + (_isLoadMoreRunning ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _coupons.length) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildHorizontalTicketCard(theme, _coupons[index]);
            },
          );
        } else {
          // Mobile Layout
          return ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _coupons.length + (_isLoadMoreRunning ? 1 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              if (index == _coupons.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _buildHorizontalTicketCard(theme, _coupons[index]);
            },
          );
        }
      },
    );
  }

  Widget _buildHorizontalTicketCard(ThemeData theme, Coupon coupon) {
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(
      coupon.expiryTimestamp * 1000,
    );
    final isExpired = expiryDate.isBefore(DateTime.now());

    // Calculate days left
    final now = DateTime.now();
    final daysLeft = expiryDate.difference(now).inDays;

    return Container(
      height: 230,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isExpired
            ? Border.all(color: Colors.red.withOpacity(0.3), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: Image
            SizedBox(
              width: 130,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      coupon.imgUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF3B82F6),
                        child: Center(
                          child: Icon(
                            Icons.confirmation_number_outlined,
                            color: Colors.white.withOpacity(0.5),
                            size: 40,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(color: Colors.black.withOpacity(0.1)),
                  ),
                ],
              ),
            ),

            // Right: Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Code + Copy
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            coupon.couponCode,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(
                              ClipboardData(text: coupon.couponCode),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Copied: ${coupon.couponCode}'),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.content_copy_rounded,
                              size: 16,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Discount
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '₹${coupon.amount.toStringAsFixed(0)} OFF',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    if (coupon.description.isNotEmpty) ...[
                      Text(
                        coupon.description,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Badges
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (!isExpired && daysLeft >= 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFFBBF24).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              daysLeft > 365
                                  ? '>1y left'
                                  : daysLeft > 30
                                  ? '${daysLeft ~/ 30}m left'
                                  : '${daysLeft}d left',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFD97706),
                              ),
                            ),
                          ),
                        if (coupon.isUniversal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDEEAFF),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFF3B82F6).withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              'Universal',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const Spacer(),
                    Divider(height: 12, color: Colors.grey[200]),

                    // Details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMiniDetail(
                          'Min Order',
                          '₹${coupon.minimumAmount.toInt()}',
                        ),
                        _buildMiniDetail(
                          'Max Disc.',
                          '₹${coupon.maximumDiscountAmountLimit.toInt()}',
                        ),
                        _buildMiniDetail(
                          'Expires',
                          DateFormat('dd MMM').format(expiryDate),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expires:',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('dd MMM yyyy').format(expiryDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: isExpired
                                    ? Colors.red
                                    : const Color(0xFF1E293B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Edit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) =>
                              EditCouponBottomSheet(coupon: coupon),
                        );

                        if (result == true) {
                          _fetchCoupons();
                        }
                      },
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text(
                        'Edit Coupon',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Edit Button
                    SizedBox(
                      height: 30,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final result = await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) =>
                                EditCouponBottomSheet(coupon: coupon),
                          );

                          if (result == true) {
                            _fetchCoupons();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: const Text(
                          'Edit Coupon',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }

  Widget _buildMiniDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
