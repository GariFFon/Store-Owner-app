import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:exanor/config/theme_config.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;  // Temporarily disabled
import 'package:exanor/screens/location_selection_screen.dart';
import 'package:exanor/screens/saved_addresses_screen.dart';

import 'package:exanor/services/api_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/services/enhanced_translation_service.dart';
import 'package:exanor/components/custom_cached_network_image.dart';
import 'package:exanor/services/interstitial_ads_service.dart';
import 'package:exanor/components/language_selector.dart';
import 'package:exanor/screens/global_search_screen.dart';

class CustomSliverAppBar extends StatelessWidget {
  final String? addressTitle;
  final String? addressSubtitle;
  final String? addressArea;
  final String? addressCity;
  final VoidCallback? onAddressUpdated;
  final VoidCallback? onUserDataUpdated;
  final VoidCallback? onTabsRefresh;
  final VoidCallback? onRefreshNeeded;
  final Function(String, String?, String?)? onSubCategorySelected;
  final String? userImgUrl;
  final String? userName;
  final bool isLoadingUserData;

  const CustomSliverAppBar({
    super.key,
    this.addressTitle,
    this.addressSubtitle,
    this.addressArea,
    this.addressCity,
    this.onAddressUpdated,
    this.onUserDataUpdated,
    this.onTabsRefresh,
    this.onRefreshNeeded,
    this.onSubCategorySelected,
    this.userImgUrl,
    this.userName,
    this.isLoadingUserData = false,
  });

  String _buildAddressExcerpt() {
    if (addressSubtitle == null) {
      return 'Set your location by clicking here.';
    }

    // Build excerpt with address subtitle + area/city context
    List<String> excerptParts = [addressSubtitle!];

    // Add area and city for additional context, avoiding duplicates
    if (addressArea != null &&
        addressArea!.isNotEmpty &&
        !addressSubtitle!.toLowerCase().contains(addressArea!.toLowerCase())) {
      excerptParts.add(addressArea!);
    }

    if (addressCity != null &&
        addressCity!.isNotEmpty &&
        !addressSubtitle!.toLowerCase().contains(addressCity!.toLowerCase()) &&
        (addressArea == null ||
            !addressArea!.toLowerCase().contains(addressCity!.toLowerCase()))) {
      excerptParts.add(addressCity!);
    }

    String fullExcerpt = excerptParts.join(', ');

    // Truncate if too long (keep under ~50 characters for mobile display)
    if (fullExcerpt.length > 50) {
      return '${fullExcerpt.substring(0, 47)}...';
    }

    return fullExcerpt;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverAppBar(
      expandedHeight: 10.0,
      floating: false,
      pinned: false,
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: theme.colorScheme.surface,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 8.0,
                bottom: 4.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row with location and actions
                  Row(
                    children: [
                      // Location icon and text
                      Icon(
                        Icons.location_on,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            // Navigate to SavedAddressesScreen
                            final result =
                                await Navigator.push<Map<String, dynamic>>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SavedAddressesScreen(),
                                  ),
                                );

                            // If address was selected, call the callback to refresh
                            if (result != null &&
                                result['addressSelected'] == true &&
                                onAddressUpdated != null) {
                              onAddressUpdated!();
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  TranslatedText(
                                    addressTitle ?? 'Set Location',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    color: theme.colorScheme.onSurface,
                                    size: 20,
                                  ),
                                ],
                              ),
                              TranslatedText(
                                _buildAddressExcerpt(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Action icons
                      // Action icons
                      GestureDetector(
                        onTap: () {
                          // Profile navigation placeholder
                          print('Profile tapped');
                          if (onUserDataUpdated != null) {
                            onUserDataUpdated!();
                          }
                        },
                        child: isLoadingUserData
                            ? Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.grey[300],
                                ),
                              )
                            : CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.orange,
                                backgroundImage:
                                    userImgUrl != null && userImgUrl!.isNotEmpty
                                    ? NetworkImage(userImgUrl!)
                                    : null,
                                child: userImgUrl == null || userImgUrl!.isEmpty
                                    ? TranslatedText(
                                        userName?.isNotEmpty == true
                                            ? userName!
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                      ),
                      // Language Selector
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          // Show language selector
                          showLanguageSelector(context);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.surface,
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.shadow.withOpacity(
                                  0.1,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.translate,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StoreCategoriesDelegate extends SliverPersistentHeaderDelegate {
  final Function(String) onCategorySelected;
  final String selectedCategoryId;
  final double topPadding;

  const StoreCategoriesDelegate({
    required this.onCategorySelected,
    required this.selectedCategoryId,
    required this.topPadding,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.only(top: topPadding),
      child: StoreCategoriesWidget(
        onCategorySelected: onCategorySelected,
        selectedCategoryId: selectedCategoryId,
      ),
    );
  }

  @override
  double get maxExtent => 200.0 + topPadding;

  @override
  double get minExtent => 200.0 + topPadding;

  @override
  bool shouldRebuild(covariant StoreCategoriesDelegate oldDelegate) {
    return oldDelegate.selectedCategoryId != selectedCategoryId ||
        oldDelegate.topPadding != topPadding;
  }
}

class StoreCategoriesWidget extends StatefulWidget {
  final Function(String) onCategorySelected;
  final String selectedCategoryId;

  const StoreCategoriesWidget({
    super.key,
    required this.onCategorySelected,
    required this.selectedCategoryId,
  });

  @override
  State<StoreCategoriesWidget> createState() => _StoreCategoriesWidgetState();
}

class _StoreCategoriesWidgetState extends State<StoreCategoriesWidget> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    if (!mounted) return;

    try {
      final response = await ApiService.post(
        '/store-categories/',
        body: {'query': {}},
        useBearerToken: true,
      );

      if (!mounted) return;

      if (response['data'] != null && response['data']['status'] == 200) {
        final List<dynamic> data = response['data']['response'] ?? [];

        setState(() {
          _categories = data.map((e) => e as Map<String, dynamic>).toList();

          // Add "All" category at index 0
          _categories.insert(0, {
            'id': 'all',
            'category_name': 'All',
            'category_icon':
                'https://exanor-production-media.s3.ap-south-1.amazonaws.com/exanor-default-assest/store_default_icon.png',
          });

          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error fetching categories: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GlobalSearchScreen(),
                        ),
                      );
                    },
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[900] : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Icon(
                            Icons.search,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          TranslatedText(
                            'Search "ice cream"',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Mic Icon
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[900] : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.mic, color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),

          // Categories List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 20),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final categoryId = category['id'];
                      final isSelected =
                          categoryId == widget.selectedCategoryId ||
                          (widget.selectedCategoryId.isEmpty &&
                              categoryId == 'all');

                      return GestureDetector(
                        onTap: () => widget.onCategorySelected(
                          categoryId == 'all' ? '' : categoryId,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Image Container
                            Container(
                              height: 65,
                              width: 65,
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: NetworkImage(
                                    category['category_icon'] ?? '',
                                  ),
                                  fit: BoxFit.cover,
                                  onError: (exception, stackTrace) {},
                                ),
                              ),
                              child:
                                  (category['category_icon'] == null ||
                                      category['category_icon'] == '')
                                  ? Icon(
                                      Icons.category,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            // Text
                            TranslatedText(
                              category['category_name'] ?? '',
                              style: TextStyle(
                                color: isSelected
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Selection Indicator
                            if (isSelected)
                              Container(
                                height: 3,
                                width: 25,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              )
                            else
                              const SizedBox(height: 3),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
