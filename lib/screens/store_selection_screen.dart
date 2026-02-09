import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/screens/store_owner_dashboard_screen.dart';
import 'package:exanor/screens/create_store_screen.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/services/notification_service.dart';
import 'dart:ui';
import 'dart:math' as math;
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

  double get _headerHeight => 200.0;

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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning,';
    } else if (hour < 17) {
      return 'Good Afternoon,';
    } else {
      return 'Good Evening,';
    }
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
                  : _buildStoreList(),
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

  Widget _buildCreativeHeader() {
    final lightBlueBg = const Color(0xFFEFF6FF);
    final watermarkColor = const Color(0xFFDBEAFE);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: lightBlueBg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF94A3B8).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: Stack(
          children: [
            // Watermark
            Positioned(
              right: -30,
              top: -10,
              child: Transform.rotate(
                angle: -math.pi / 6,
                child: Icon(
                  Icons.storefront_rounded,
                  size: 180,
                  color: watermarkColor.withOpacity(0.6),
                ),
              ),
            ),

            // MAIN CONTENT
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // TEXT SECTION
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Greeting
                            Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getGreeting(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blueGrey[700],
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            // Select Store Text
                            RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Select ',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w300,
                                      color: Color(0xFF0F172A),
                                      fontFamily: 'Roboto',
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Store',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black,
                                      fontFamily: 'Roboto',
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // BUTTONS SECTION
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // LOGOUT BUTTON
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "LOGOUT",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[500],
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () async {
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.clear();
                                  if (context.mounted) {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const LoginScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                    border: Border.all(
                                      color: Colors.red.withOpacity(0.1),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.logout_rounded,
                                    color: Colors.red[400],
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // NEW STORE BUTTON
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "NEW STORE",
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blue[300],
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CreateStoreScreen(),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF2563EB,
                                        ).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // SEARCH BAR
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1F4C6B).withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        prefixIcon: const Icon(
                          CupertinoIcons.search,
                          color: Color(0xFF94A3B8),
                          size: 22,
                        ),
                        hintText: 'Search for an outlet...',
                        hintStyle: TextStyle(
                          color: const Color(0xFF94A3B8).withOpacity(0.8),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFF1F5F9),
                          ),
                          child: const Icon(
                            Icons.mic_none_rounded,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                        ),
                      ), // TextField
                    ), // Container
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
              mainAxisExtent: 320, // Taller structure for vertical cards
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
                height: 300, // Fixed height for vertical card
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

    // Role Theming
    final isOwner = roleName.contains('ADMIN') || roleName.contains('OWNER');
    final roleBg = isOwner
        ? const Color(0xFFEFF6FF)
        : const Color(0xFFF0FDF4); // Blue/Green
    final roleText = isOwner
        ? const Color(0xFF1E40AF)
        : const Color(0xFF15803D);

    // Responsive Flex
    final int imageFlex = isTable ? 65 : 60;
    final int contentFlex = isTable ? 35 : 40;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.12),
            offset: const Offset(0, 10),
            blurRadius: 30,
            spreadRadius: -5,
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
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
                                        Colors.blue[50]!,
                                        Colors.blue[100]!.withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                ),
                                Center(
                                  child: Icon(
                                    Icons.storefront_rounded,
                                    size: 48,
                                    color: Colors.blue[200],
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, thickness: 1, color: Colors.grey[200]),

              // 2. CONTENT AREA
              Expanded(
                flex: contentFlex,
                child: Container(
                  color: const Color(
                    0xFFF8FAFC,
                  ), // Slate 50 - Premium light grey
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // HEADER SECTION
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      storeName,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                        letterSpacing: -0.5,
                                        height: 1.1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          size: 8,
                                          color: Color(0xFF166534),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          "Active",
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF166534),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      fullAddress,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // FOOTER SECTION (Role Tag)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: roleBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              roleName,
                              style: TextStyle(
                                fontSize: 11, // Increased from 10
                                fontWeight: FontWeight.w700,
                                color: roleText,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // FLOAT BUTTON
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28, // Shrunk from 32
                          height: 28, // Shrunk from 32
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F172A).withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 14, // Shrunk from 16
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
      ),
    );
  }
}
