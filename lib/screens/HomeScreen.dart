import 'package:exanor/components/translation_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // Added for ScrollDirection
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/models/store_model.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/components/custom_sliver_app_bar.dart';
import 'package:exanor/components/liquid_glass_bottom_nav.dart';
import 'package:exanor/screens/store_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // User Data
  String? userName;
  bool _isLoadingUserData = true;

  // Navigation
  int _bottomNavIndex = 0;

  // Store Data & Pagination
  List<Store> _stores = [];
  bool _isLoading = true;
  bool _isMoreLoading = false;
  int _page = 1;
  bool _hasNextPage = true;

  late ScrollController _scrollController;

  // Default constant ID
  final String _constAddressId = "e3d3142b-6065-4052-95f6-854a6bb039e9";
  String _userAddressId = "e3d3142b-6065-4052-95f6-854a6bb039e9";

  String _addressTitle = "Home";
  String _addressSubtitle = "Phagwara, Punjab";

  String _selectedCategoryId = '';

  bool _isBottomNavVisible = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _loadAddressData();
  }

  Future<void> _loadAddressData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAddressId = prefs.getString('saved_address_id');

      setState(() {
        if (savedAddressId != null && savedAddressId.isNotEmpty) {
          _userAddressId = savedAddressId;
          _addressTitle = prefs.getString('address_title') ?? "Home";
          _addressSubtitle =
              prefs.getString('address_subtitle') ?? "Phagwara, Punjab";
        } else {
          _userAddressId = _constAddressId;
          // Keep default title/subtitle or set to constants
        }
      });

      // Fetch stores after address is loaded
      // Reset pagination
      _page = 1;
      _fetchStores();
    } catch (e) {
      print('❌ Home: Error loading address data: $e');
      // Fallback to const ID and fetch
      _userAddressId = _constAddressId;
      _page = 1;
      _fetchStores();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      if (!_isMoreLoading && _hasNextPage) {
        _fetchStores(loadMore: true);
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final firstName = prefs.getString('first_name') ?? '';
      final lastName = prefs.getString('last_name') ?? '';

      setState(() {
        userName = '$firstName $lastName'.trim();
        _isLoadingUserData = false;
      });
    } catch (e) {
      print('❌ Home: Error loading user data: $e');
      setState(() {
        _isLoadingUserData = false;
      });
    }
  }

  Future<void> _fetchStores({bool loadMore = false}) async {
    if (loadMore) {
      setState(() {
        _isMoreLoading = true;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final requestBody = {
        "user_address_id": _userAddressId,
        "radius": 20000,
        "page": _page,
        if (_selectedCategoryId.isNotEmpty)
          "store_category_id": _selectedCategoryId,
      };

      print('🏪 Fetching stores: Page $_page');

      final response = await ApiService.post(
        '/get-stores/',
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final responseData = response['data'];
        final storesList = (responseData['response'] as List)
            .map((item) => Store.fromJson(item))
            .toList();

        final pagination = responseData['pagination'];
        final hasNext = pagination['has_next'] ?? false;

        if (mounted) {
          setState(() {
            if (loadMore) {
              _stores.addAll(storesList);
            } else {
              _stores = storesList;
            }

            _hasNextPage = hasNext;
            _page++;
            _isLoading = false;
            _isMoreLoading = false;
          });
        }
      } else {
        print('❌ Failed to fetch stores: ${response['data']}');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isMoreLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching stores: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isMoreLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      extendBody: true, // Allows content to go under the glass bottom nav
      body: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical) {
            if (notification.direction == ScrollDirection.reverse &&
                _isBottomNavVisible) {
              setState(() {
                _isBottomNavVisible = false;
              });
            } else if (notification.direction == ScrollDirection.forward &&
                !_isBottomNavVisible) {
              setState(() {
                _isBottomNavVisible = true;
              });
            }
          }
          return true;
        },
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadAddressData,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Custom Sliver App Bar
                  CustomSliverAppBar(
                    addressTitle: _addressTitle,
                    addressSubtitle: _addressSubtitle,
                    userName: userName,
                    isLoadingUserData: _isLoadingUserData,
                    onAddressUpdated: () {
                      print("Address updated callback received");
                      _loadAddressData();
                    },
                    onUserDataUpdated: _loadUserData,
                  ),

                  // 2. Store Categories Sticky Header
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: StoreCategoriesDelegate(
                      selectedCategoryId: _selectedCategoryId,
                      topPadding: MediaQuery.of(context).padding.top,
                      onCategorySelected: (categoryId) {
                        setState(() {
                          _selectedCategoryId = categoryId;
                          _page = 1;
                        });
                        _fetchStores();
                      },
                    ),
                  ),

                  // 2. Content Body
                  if (_isLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: 90, // Reduced from 120 since nav bar is smaller
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == _stores.length) {
                              return _isMoreLoading
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _buildStoreCard(_stores[index], theme),
                            );
                          },
                          childCount: _stores.length + (_isMoreLoading ? 1 : 0),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Animated Bottom Navigation
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: 0,
              right: 0,
              bottom: _isBottomNavVisible ? 0 : -100, // Move off screen
              child: SafeArea(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isBottomNavVisible ? 1.0 : 0.0,
                  curve: Curves.easeInOut,
                  child: LiquidGlassBottomNav(
                    currentIndex: _bottomNavIndex,
                    onTap: (index) {
                      setState(() {
                        _bottomNavIndex = index;
                      });
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreCard(Store store, ThemeData theme) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StoreScreen(storeId: store.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  Image.network(
                    store.storeBannerImgUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 140,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: Icon(Icons.image_not_supported),
                        ),
                      );
                    },
                  ),
                  if (store.isFeatured)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TranslatedText(
                          'Featured',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Store Logo
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                      image: DecorationImage(
                        image: NetworkImage(store.storeLogoImgUrl),
                        fit: BoxFit.cover,
                        onError:
                            (exception, stackTrace) {}, // Handled by default
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TranslatedText(
                          store.storeName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        TranslatedText(
                          '${store.category} • ${store.area}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            TranslatedText(
                              store.fulfillmentSpeed,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            if (store.averageRating > 0) ...[
                              const SizedBox(width: 12),
                              Icon(
                                Icons.star_rounded,
                                size: 16,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 2),
                              TranslatedText(
                                store.averageRating.toStringAsFixed(1),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TranslatedText(
                                ' (${store.ratingCount})',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Offer Section (if available)
            if (store.bottomOfferTitle.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.discount_outlined,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TranslatedText(
                        store.bottomOfferTitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
