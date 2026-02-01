import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/models/coupon.dart';
import 'package:exanor/screens/create_coupon_bottom_sheet.dart';
import 'package:exanor/services/store_owner_api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CouponsScreen extends StatefulWidget {
  final String storeId;

  const CouponsScreen({super.key, required this.storeId});

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  bool _isLoading = true;
  List<Coupon> _coupons = [];
  int _currentPage = 1;
  bool _hasNextPage = false;
  bool _isLoadMoreRunning = false;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

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
        _scrollController.position.extentAfter < 300) {
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const TranslatedText(
          'Coupons Management',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) =>
                    CreateCouponBottomSheet(storeId: widget.storeId),
              );

              if (result == true) {
                _fetchCoupons();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50], // Very light grey background
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by coupon code...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (value) => _fetchCoupons(query: value),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () =>
                        _fetchCoupons(query: _searchController.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1), // Indigo
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      elevation: 0,
                    ),
                    child: const TranslatedText(
                      'Search',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _coupons.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.confirmation_number_outlined,
                            size: 48,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const TranslatedText(
                          'No Coupons Found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TranslatedText(
                          'Try a different search term',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GridView.builder(
                      controller: _scrollController,
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 400,
                            childAspectRatio: 0.60,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: _coupons.length + (_hasNextPage ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _coupons.length) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final coupon = _coupons[index];
                        return _buildCouponCard(coupon);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard(Coupon coupon) {
    // Calculate days left
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(
      coupon.expiryTimestamp * 1000,
    );
    final daysLeft = expiryDate.difference(DateTime.now()).inDays;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        // Subtle shadow as per modern design
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Image Section
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                coupon.imgUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFEBEFFD), // Light lilac background
                  child: Center(
                    child: Text(
                      coupon.couponCode,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5B3FD8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Content Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Copy Icon
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          coupon.couponCode,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827), // Dark grey
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          // TODO: Implement copy to clipboard
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: TranslatedText(
                                'Copied ${coupon.couponCode} to clipboard',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.content_copy_rounded,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Discount Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFA855F7), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '₹${coupon.amount} OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    coupon.description,
                    style: const TextStyle(
                      color: Color(0xFF4B5563), // Slate 600
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 12),

                  // Days Left Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7), // Green 100
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF86EFAC),
                      ), // Green 300
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: Color(0xFF166534), // Green 800
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${daysLeft}d left',
                          style: const TextStyle(
                            color: Color(0xFF166534),
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),
                  const Divider(height: 24),

                  // Details Grid
                  _buildDetailRow('Min Amount:', '₹${coupon.minimumAmount}'),
                  const SizedBox(height: 4),
                  _buildDetailRow(
                    'Max Discount:',
                    '₹${coupon.maximumDiscountAmountLimit}',
                  ),
                  const SizedBox(height: 4),
                  _buildDetailRow(
                    'Expires:',
                    DateFormat('MMM dd, yyyy').format(expiryDate),
                  ),

                  const SizedBox(height: 16),

                  // Edit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Edit functionality
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: TranslatedText('Edit Coupon Clicked'),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const TranslatedText(
                        'Edit Coupon',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1), // Indigo 500
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF374151), // Slate 700
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
