import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:exanor/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:exanor/components/custom_cached_network_image.dart';

class ImageCarousel extends StatefulWidget {
  const ImageCarousel({super.key});

  @override
  State<ImageCarousel> createState() => ImageCarouselState();
}

class ImageCarouselState extends State<ImageCarousel> {
  final CarouselSliderController _carouselController =
      CarouselSliderController();
  int _currentPage = 0;
  List<Map<String, dynamic>> _carouselData = [];
  bool _isLoading = true;
  bool _hasError = false;
  int _currentRetryCount = 0;

  // Fallback images if API fails
  final List<String> _fallbackImages = [
    "https://res.cloudinary.com/anurupmillan/image/upload/v1752340668/exanor/3_MONTHS_3_f2jk6i.png",
  ];

  @override
  void initState() {
    super.initState();
    _fetchCarouselData();
  }

  /// Public method to refresh carousel data - can be called from parent widgets
  Future<void> refreshCarouselData() async {
    print('🎠 ImageCarousel: Refreshing carousel data...');
    // Reset retry count when manually refreshing
    _currentRetryCount = 0;
    await _fetchCarouselData();
  }

  Future<void> _fetchCarouselData({int retryCount = 0}) async {
    const int maxRetries = 5;

    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _currentRetryCount = retryCount;
      });

      if (retryCount > 0) {
        print('🔄 ImageCarousel: Retry attempt $retryCount/$maxRetries');
      }

      // Add a timeout to prevent infinite loading
      final response =
          await ApiService.post(
            '/get-carousel/',
            body: {},
            useBearerToken: true,
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('API timeout');
            },
          );

      if (response['data'] != null && response['data']['status'] == 200) {
        final List<dynamic> carouselList = response['data']['data'] ?? [];

        final filteredData = carouselList
            .map(
              (item) => {
                'id': item['id'] ?? '',
                'title': item['title'] ?? '',
                'description': item['description'] ?? '',
                'img_url': item['img_url'] ?? '',
                'navigate_to': item['navigate_to'] ?? '',
                'is_active': item['is_active'] ?? true,
                'is_featured': item['is_featured'] ?? false,
              },
            )
            .where(
              (item) => item['is_active'] == true && item['img_url'].isNotEmpty,
            )
            .toList();

        setState(() {
          _carouselData = filteredData;
          _isLoading = false;
          _hasError = false;
          _currentRetryCount = 0; // Reset retry count on success
        });

        print(
          '🎠 ImageCarousel: Loaded ${_carouselData.length} carousel items',
        );

        // Success after retries
        if (retryCount > 0) {
          print('✅ ImageCarousel: Successful after $retryCount retries');
        }
      } else {
        throw Exception('Invalid response format or status');
      }
    } catch (e) {
      print(
        '❌ ImageCarousel: Error loading carousel data (attempt ${retryCount + 1}/${maxRetries + 1}): $e',
      );

      if (retryCount < maxRetries) {
        // Wait before retrying (exponential backoff)
        final delaySeconds = (retryCount + 1) * 2; // 2, 4, 6, 8, 10 seconds
        print('⏳ ImageCarousel: Retrying in $delaySeconds seconds...');

        await Future.delayed(Duration(seconds: delaySeconds));

        if (mounted) {
          await _fetchCarouselData(retryCount: retryCount + 1);
        }
      } else {
        print(
          '❌ ImageCarousel: All retry attempts failed, using fallback images',
        );
        _handleError();
      }
    }
  }

  void _handleError() {
    print('🎠 ImageCarousel: Using fallback images due to error');
    setState(() {
      _isLoading = false;
      _hasError = true;
      _currentRetryCount = 0; // Reset retry count when using fallback
      // Use fallback images on error
      _carouselData = _fallbackImages
          .map(
            (url) => {
              'id': '',
              'title': '',
              'description': '',
              'img_url': url,
              'navigate_to': '',
              'is_active': true,
              'is_featured': false,
            },
          )
          .toList();
    });
  }

  Future<void> _handleCarouselTap(Map<String, dynamic> carouselItem) async {
    final String navigateTo = carouselItem['navigate_to'] ?? '';

    if (navigateTo.isEmpty) {
      print('🎠 ImageCarousel: No navigate_to value for carousel item');
      return;
    }

    try {
      // First, try to parse as URL
      final Uri uri = Uri.parse(navigateTo);

      // Check if it's a valid URL (has scheme like http/https)
      if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication, // Open in default browser
          );
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Unable to open link'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        // If not a valid URL, treat as route
        await _handleRouteNavigation(navigateTo);
      }
    } catch (e) {
      // If parsing fails, also try as route
      await _handleRouteNavigation(navigateTo);
    }
  }

  Future<void> _handleRouteNavigation(String route) async {
    if (!mounted) return;

    try {
      switch (route) {
        case '/my_businesses':
          Navigator.pushNamed(context, '/my_businesses');
          break;
        case '/my_profile':
          Navigator.pushNamed(context, '/my_profile');
          break;
        case '/subscription':
          Navigator.pushNamed(context, '/subscription');
          break;
        case '/refer_and_earn':
          Navigator.pushNamed(context, '/refer_and_earn');
          break;
        case '/employee_profile_onboarding':
          Navigator.pushNamed(context, '/employee_profile_onboarding');
          break;
        case '/professional_profile_onboarding':
          Navigator.pushNamed(context, '/professional_profile_onboarding');
          break;
        case '/business_profile_onboarding':
          Navigator.pushNamed(context, '/business_profile_onboarding');
          break;
        default:
          // Try to navigate to the route anyway
          try {
            Navigator.pushNamed(context, route);
          } catch (e) {
            // If route doesn't exist, show error
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Route not found: $route'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          break;
      }
    } catch (e) {
      print('🎠 ImageCarousel: Error navigating to route $route: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error navigating to: $route'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 180,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                  strokeWidth: 2,
                ),
                const SizedBox(height: 8),
                Text(
                  _currentRetryCount == 0
                      ? 'Loading carousel images...'
                      : 'Retrying... (${_currentRetryCount}/5)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentRetryCount == 0
                      ? 'Please wait'
                      : 'Attempting to reconnect',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_carouselData.isEmpty) {
      return const SizedBox.shrink(); // Hide carousel if no data
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Carousel using carousel_slider package with on-demand building
          CarouselSlider.builder(
            carouselController: _carouselController,
            itemCount: _carouselData.length,
            itemBuilder:
                (BuildContext context, int itemIndex, int pageViewIndex) {
                  final carouselItem = _carouselData[itemIndex];
                  final String imageUrl = carouselItem['img_url'] ?? '';

                  return Container(
                    width: MediaQuery.of(context).size.width,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _handleCarouselTap(carouselItem),
                        child: CustomCachedNetworkImage(
                          imgUrl: imageUrl,
                          width: MediaQuery.of(context).size.width,
                          height: 180,
                          borderRadius: 16,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image,
                                    size: 40,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Image unavailable',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          placeholderColor: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  );
                },
            options: CarouselOptions(
              height: 180,
              viewportFraction: 0.9,
              enableInfiniteScroll: true,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 3),
              autoPlayAnimationDuration: const Duration(milliseconds: 800),
              autoPlayCurve: Curves.fastOutSlowIn,
              enlargeCenterPage: true,
              enlargeFactor: 0.2,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentPage = index;
                });
              },
              scrollDirection: Axis.horizontal,
            ),
          ),

          const SizedBox(height: 12),

          // Page indicators
          if (_carouselData.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_carouselData.length, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
