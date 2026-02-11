import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/screens/store_owner_dashboard_screen.dart';
import 'package:exanor/screens/create_store_screen.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/notification_service.dart';
import 'dart:ui';

import 'package:exanor/screens/auth/login_screen.dart';

class StoreSelectionScreen extends StatefulWidget {
  const StoreSelectionScreen({super.key});

  @override
  State<StoreSelectionScreen> createState() => _StoreSelectionScreenState();
}

class _StoreSelectionScreenState extends State<StoreSelectionScreen> {
  List<dynamic> _allStores = [];
  List<dynamic> _filteredStores = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterStores() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredStores = List.from(_allStores);
      } else {
        _filteredStores = _allStores.where((store) {
          final name = (store['name'] ?? store['store_name'] ?? '')
              .toString()
              .toLowerCase();
          final city = (store['city'] ?? '').toString().toLowerCase();
          final area = (store['area'] ?? '').toString().toLowerCase();
          return name.contains(query) ||
              city.contains(query) ||
              area.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _checkExistingStoreSelection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final selectedStoreId = prefs.getString('selected_store_id');
      final selectedStoreName = prefs.getString('selected_store_name');

      if (selectedStoreId != null && selectedStoreName != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => StoreOwnerDashboardScreen(
                storeId: selectedStoreId,
                storeName: selectedStoreName,
              ),
            ),
          );
        }
      } else {
        await _fetchStores();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error checking store selection: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchStores() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await ApiService.post(
        '/user-stores/',
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          if (mounted) {
            final stores = data['response'] is List ? data['response'] : [];
            setState(() {
              _allStores = stores;
              _filteredStores = stores;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _errorMessage = 'No stores found';
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to fetch stores';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error fetching stores: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectStore(dynamic store) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storeId = store['id'] ?? store['store_id'] ?? '';
      final storeName = store['name'] ?? store['store_name'] ?? 'Store';

      await prefs.setString('selected_store_id', storeId);
      await prefs.setString('selected_store_name', storeName);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StoreOwnerDashboardScreen(
              storeId: storeId,
              storeName: storeName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting store: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. CONTENT
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: _headerHeight),
              child: _isLoading
                  ? _buildLoadingView()
                  : _errorMessage != null
                  ? _buildErrorView()
                  : RefreshIndicator(
                      onRefresh: _fetchStores,
                      child: _buildStoreList(),
                    ),
            ),
          ),

          // 2. HEADER
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _headerHeight,
            child: _buildCreativeHeader(),
          ),
        ],
      ),
    );
  }

  double get _headerHeight => 212.0;

  @override
  void initState() {
    super.initState();
    _checkExistingStoreSelection();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _searchController.addListener(_filterStores);

    // Create notification token after authentication
    NotificationService.createNotificationToken();
  }

  // ... (keeping other methods as is, but replacing _buildCreativeHeader fully)

  // NOTE: I'm skipping intermediate methods in this view, so I will replace from _headerHeight down to end of _buildCreativeHeader.
  // Wait, the tool requires exact match.
  // I will replace `_headerHeight` line separately if I can, or include `initState` etc.
  // But strictly, let's just target the `_buildCreativeHeader` method and the `_headerHeight` line using a StartLine/EndLine block that covers both if they are close?
  // They are far apart (Line 27 vs 219).
  // I will use replace_file_content for TWO chunks? The tool says "single contiguous block".
  // I will make two tool calls? "Do NOT make multiple parallel calls to this tool".
  // I will use `multi_replace_file_content`.

  // Wait, I can't use multi_replace.
  // I'll stick to replacing the big chunk `_buildCreativeHeader` first, then `_headerHeight` in a second call?
  // No, I'll do `_buildCreativeHeader` fully now. The height change is minor (280 -> 260), I can do it in next turn or separate call.
  // Actually, if I don't change height, it might still have whitespace.
  // I'll start with `_buildCreativeHeader` proper rework.

  // Let's replace from line 219 (`Widget _buildCreativeHeader() {`) down to line 500 (end of Search Bar logic).

  Widget _buildCreativeHeader() {
    // Current date for display
    final now = DateTime.now();
    final month = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][now.month - 1];
    final dateStr = "${now.day} $month, ${now.year}";

    // Greeting logic
    final hour = now.hour;
    String greetingText = hour < 12
        ? 'Good morning,'
        : hour < 17
        ? 'Good afternoon,'
        : 'Good evening,';

    return Container(
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // Matching Order Details Light Blue
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Watermark (Restored)
          Positioned(
            right: -30,
            top: -20,
            child: Transform.rotate(
              angle: -0.5, // Approx -30 degrees
              child: Icon(
                Icons.store_mall_directory_rounded,
                size: 200,
                color: const Color(0xFFDBEAFE).withOpacity(0.6),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Greeting & Date
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Innovative Text Greeting
                    Text(
                      greetingText.toUpperCase(), // Includes comma now
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: Colors.blueGrey[500],
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                    // Date Capsule
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 12,
                            color: Colors.blue[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.blueGrey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Row 2: Title & Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Big Title
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w400,
                            color: Colors.blueGrey[400],
                            height: 1.0,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Store Outlet',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                            height: 1.2,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ],
                    ),

                    // Actions
                    Row(
                      children: [
                        _buildActionButton(
                          label: "LOGOUT",
                          icon: Icons.logout_rounded,
                          color: Colors.red[400]!,
                          bgColor: Colors.white,
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();
                            if (context.mounted) {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 16),
                        _buildActionButton(
                          label: "NEW STORE",
                          icon: Icons.add_business_rounded,
                          color: Colors.white,
                          bgColor: const Color(0xFF2563EB),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const CreateStoreScreen(),
                              ),
                            );
                          },
                          isPrimary: true,
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Bottom: Search Bar
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    textAlignVertical: TextAlignVertical.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Search for an outlet...',
                      hintStyle: TextStyle(
                        color: Colors.blueGrey[300],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.blueGrey[300],
                        size: 22,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label ABOVE the button
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isPrimary ? const Color(0xFF2563EB) : Colors.blueGrey[400],
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isPrimary
                      ? const Color(0xFF2563EB).withOpacity(0.3)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: isPrimary
                  ? null
                  : Border.all(color: Colors.blueGrey[50]!, width: 1),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF1E293B)),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Unable to load stores',
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          TextButton(onPressed: _fetchStores, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildStoreList() {
    if (_filteredStores.isEmpty) {
      if (_isLoading) {
        return Container();
      }
      return Center(
        child: Text(
          'No stores found',
          style: TextStyle(
            color: Colors.grey[400],
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isBroad = constraints.maxWidth > 700;

        if (isBroad) {
          // Tablet / Desktop: Grid Layout
          return GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisSpacing: 24,
              crossAxisSpacing: 24,
              mainAxisExtent: 330,
            ),
            itemCount: _filteredStores.length,
            itemBuilder: (context, index) {
              return _buildPremiumStoreCard(
                _filteredStores[index],
                isTable: true,
              );
            },
          );
        } else {
          // Mobile: List Layout
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            itemCount: _filteredStores.length,
            separatorBuilder: (context, index) => const SizedBox(height: 24),
            itemBuilder: (context, index) {
              return SizedBox(
                height: 320,
                child: _buildPremiumStoreCard(
                  _filteredStores[index],
                  isTable: false,
                ),
              );
            },
          );
        }
      },
    );
  }

  Widget _buildPremiumStoreCard(dynamic store, {bool isTable = false}) {
    final storeName = store['name'] ?? store['store_name'] ?? 'Store';
    final storeImage = store['store_logo_img_url'];
    final String city = store['city'] ?? 'City N/A';
    final String area = store['area'] ?? 'Area';
    final String fullAddress = area.isNotEmpty ? '$area, $city' : city;
    final String category = store['store_category_name'] ?? 'Retail';
    final roleName = (store['role_name'] ?? 'ADMIN').toString().toUpperCase();

    final bool hasImage =
        storeImage != null &&
        storeImage.isNotEmpty &&
        storeImage != 'undefined';

    // Role Theming - Premium Colors
    final isOwner = roleName.contains('ADMIN') || roleName.contains('OWNER');
    // Using sophisticated color palettes
    final Color roleBg = isOwner
        ? const Color(0xFFEEF2FF) // Indigo 50
        : const Color(0xFFFDF4FF); // Fuchsia 50
    final Color roleText = isOwner
        ? const Color(0xFF4338CA) // Indigo 700
        : const Color(0xFFA21CAF); // Fuchsia 700
    final Color roleBorder = isOwner
        ? const Color(0xFFC7D2FE) // Indigo 200
        : const Color(0xFFF0ABFC); // Fuchsia 200

    // Responsive Flex — image takes more space for a bigger visual
    final int imageFlex = isTable ? 68 : 68;
    final int contentFlex = isTable ? 32 : 32;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.08),
            offset: const Offset(0, 12),
            blurRadius: 24,
            spreadRadius: -4,
          ),
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.04),
            offset: const Offset(0, 4),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _selectStore(store),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. HERO IMAGE AREA
              Expanded(
                flex: imageFlex,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        image: hasImage
                            ? DecorationImage(
                                image: NetworkImage(storeImage),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: !hasImage
                          ? Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFFF8FAFC), // Slate 50
                                        const Color(0xFFE2E8F0), // Slate 200
                                      ],
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Icon(
                                    Icons.storefront_rounded,
                                    size: 48,
                                    color: Colors.blueGrey[200],
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),

                    // Gradient Overlay for depth
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.05),
                              Colors.black.withOpacity(0.2),
                            ],
                            stops: const [0.6, 0.8, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // CATEGORY TAG - Premium Style
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. CONTENT AREA
              Expanded(
                flex: contentFlex,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        const Color(0xFFF8FAFC),
                        const Color(0xFFF1F5F9).withOpacity(0.6),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // TOP SECTION: Name + Location
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Store Name & Active Dot
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  storeName,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                    letterSpacing: -0.4,
                                    height: 1.1,
                                  ),
                                  maxLines: 1, // Single line enforced
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Premium Active Indicator
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFDCFCE7),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF16A34A),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      "ACTIVE",
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF15803D),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // Location
                          Row(
                            children: [
                              Icon(
                                CupertinoIcons.location_solid,
                                size: 14,
                                color: const Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  fullAddress,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: const Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // BOTTOM ROW: Role Tag & Arrow
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Role: Premium Colored Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: roleBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: roleBorder.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              roleName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: roleText,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),

                          // Square Black Arrow
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 14,
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
      ),
    );
  }
}
