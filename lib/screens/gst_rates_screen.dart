import 'package:exanor/models/gst_rate_model.dart';
import 'package:exanor/services/gst_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math' as math;

class GstRatesScreen extends StatefulWidget {
  final String storeId;

  const GstRatesScreen({super.key, required this.storeId});

  @override
  State<GstRatesScreen> createState() => _GstRatesScreenState();
}

class _GstRatesScreenState extends State<GstRatesScreen> {
  bool _isLoading = true;
  List<GstRate> _rates = [];
  bool _isSearchExpanded = false;
  int _totalCount = 0;
  final int _limit = 200; // Load more upfront to fill large screens
  int _offset = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _searchQuery = '';
  // Used for debounce
  Timer? _debounce;
  final ScrollController _scrollController = ScrollController();

  // Stats
  int _activeCount = 0;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRates();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreRates();
      }
    }
  }

  /// After data loads, check if content fills the viewport.
  /// If not and there's more data, auto-load the next page.
  void _loadUntilScrollable() {
    if (!mounted || !_hasMore || _isLoadingMore || _isLoading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0 && _hasMore && !_isLoadingMore) {
        _loadMoreRates();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchRates() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _offset = 0;
      _hasMore = true;
    });
    try {
      final response = await GstService.fetchGstRates(
        storeId: widget.storeId,
        limit: _limit,
        offset: _offset,
        searchQuery: _searchQuery,
      );

      if (mounted) {
        setState(() {
          _rates = response.rates;
          _totalCount = response.count;
          _activeCount = _rates.where((r) => r.isActive).length;
          _isLoading = false;
          // Check if we have more to load based on the count returned vs local list size
          // or simply if the response list size < limit
          if (response.rates.length < _limit) {
            _hasMore = false;
          }
        });
        _loadUntilScrollable();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreRates() async {
    if (!mounted) return;
    setState(() => _isLoadingMore = true);

    try {
      final nextOffset = _offset + _limit;
      final response = await GstService.fetchGstRates(
        storeId: widget.storeId,
        limit: _limit,
        offset: nextOffset,
        searchQuery: _searchQuery,
      );

      if (mounted) {
        setState(() {
          if (response.rates.isNotEmpty) {
            _rates.addAll(response.rates);
            _offset = nextOffset;
            _activeCount = _rates.where((r) => r.isActive).length;
          }

          if (response.rates.length < _limit) {
            _hasMore = false;
          }
          _isLoadingMore = false;
        });
        _loadUntilScrollable();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more: ${e.toString()}')),
        );
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
        _offset = 0; // Reset pagination
      });
      _fetchRates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            _buildTopBanner(context),

            // Search Bar (Conditional)
            if (_isSearchExpanded)
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by HSN code or description...',
                    prefixIcon: Icon(
                      Icons.search,
                      color: const Color(0xFF2563EB),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _fetchRates,
                      child: CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  _buildStatsGrid(isDesktop),
                                  const SizedBox(height: 24),
                                ],
                              ),
                            ),
                          ),
                          if (isDesktop)
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              sliver: SliverToBoxAdapter(
                                child: _buildDesktopRatesTable(),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) =>
                                      _buildMobileRateCard(_rates[index]),
                                  childCount: _rates.length,
                                ),
                              ),
                            ),
                          if (_isLoadingMore)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ),
                          if (!_hasMore && !_isLoading && _rates.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24.0,
                                ),
                                child: Center(
                                  child: Text(
                                    "No more rates to load",
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SliverPadding(
                            padding: EdgeInsets.only(bottom: 80),
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

  Widget _buildTopBanner(BuildContext context) {
    const lightBlueBg = Color(0xFFEFF6FF);
    const watermarkColor = Color(0xFFDBEAFE);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: lightBlueBg,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -20,
              child: Transform.rotate(
                angle: -math.pi / 6,
                child: Icon(
                  Icons.percent_rounded,
                  size: 180,
                  color: watermarkColor.withOpacity(0.8),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  children: [
                    Row(
                      children: [
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'GST Rates',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2563EB,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'TAX CONFIGURATION',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2563EB),
                                    letterSpacing: 0.5,
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
                              Text(
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
                                      _searchQuery = '';
                                      _fetchRates();
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
                      ],
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

  Widget _buildStatsGrid(bool isDesktop) {
    final cards = [
      _buildStatCard(
        "Total Rates",
        _totalCount.toString(),
        Icons.list_alt_rounded,
        Colors.blue,
      ),
      _buildStatCard(
        "Active Rates",
        _activeCount.toString(),
        Icons.check_circle_outline_rounded,
        Colors.green,
      ),
      _buildStatCard(
        "Current View",
        _rates.length.toString(),
        Icons.visibility_outlined,
        Colors.orange,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 16),
          Expanded(child: cards[1]),
          const SizedBox(width: 16),
          Expanded(child: cards[2]),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 12),
        cards[2],
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopRatesTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.2), // HSN
          1: FlexColumnWidth(2.5), // Desc
          2: FlexColumnWidth(1), // CGST
          3: FlexColumnWidth(1), // SGST
          4: FlexColumnWidth(1), // IGST
          5: FlexColumnWidth(1), // CESS
          6: FlexColumnWidth(1.2), // Effective From
          7: FlexColumnWidth(0.8), // Status
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            children: [
              for (var h in [
                "HSN Code",
                "Description",
                "CGST",
                "SGST",
                "IGST",
                "CESS",
                "Effective From",
                "Status",
              ])
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    h,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ),
            ],
          ),
          ..._rates.map((rate) {
            return TableRow(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[100]!)),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    rate.hsnCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB),
                      fontSize: 13,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    rate.hsnDescription,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _desktopTaxCell("${rate.cgstPercent}%"),
                _desktopTaxCell("${rate.sgstPercent}%"),
                _desktopTaxCell("${rate.igstPercent}%"),
                _desktopTaxCell("${rate.cessPercent}%"),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    rate.effectiveTo.isNotEmpty
                        ? "${rate.effectiveFrom} To: ${rate.effectiveTo}"
                        : rate.effectiveFrom,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _statusBadge(rate.isActive),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _desktopTaxCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2563EB),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildMobileRateCard(GstRate rate) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  rate.hsnCode,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              _statusBadge(rate.isActive),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            rate.hsnDescription,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _mobileTaxColumn("CGST", "${rate.cgstPercent}%"),
              _mobileTaxColumn("SGST", "${rate.sgstPercent}%"),
              _mobileTaxColumn("IGST", "${rate.igstPercent}%"),
              _mobileTaxColumn("CESS", "${rate.cessPercent}%"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobileTaxColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey[400],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.green[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isActive
              ? Colors.green.withOpacity(0.2)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Text(
        isActive ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.green[700] : Colors.grey[600],
        ),
      ),
    );
  }
}
