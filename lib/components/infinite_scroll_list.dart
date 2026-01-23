import 'package:flutter/material.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/config/theme_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reusable infinite scroll list component that can handle different API endpoints
/// and data types for professional, employee, and business categories
class InfiniteScrollList extends StatefulWidget {
  final String apiEndpoint;
  final Map<String, dynamic> baseRequestBody;
  final Widget Function(Map<String, dynamic> item, int index) itemBuilder;
  final String? subCategoryId;
  final String categoryDisplayName;
  final bool enabled;
  final VoidCallback? onRefresh;

  const InfiniteScrollList({
    super.key,
    required this.apiEndpoint,
    required this.baseRequestBody,
    required this.itemBuilder,
    required this.categoryDisplayName,
    this.subCategoryId,
    this.enabled = true,
    this.onRefresh,
  });

  @override
  State<InfiniteScrollList> createState() => InfiniteScrollListState();
}

class InfiniteScrollListState extends State<InfiniteScrollList> {
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _data = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;

  // Pagination variables
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _setupScrollListener();
    if (widget.enabled) {
      _fetchData(isRefresh: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(InfiniteScrollList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Refresh data if key parameters changed
    if (oldWidget.apiEndpoint != widget.apiEndpoint ||
        oldWidget.subCategoryId != widget.subCategoryId ||
        oldWidget.enabled != widget.enabled) {
      if (widget.enabled) {
        _fetchData(isRefresh: true);
      } else {
        _clearData();
      }
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Check if user has scrolled to 80% of the content
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.8) {
        _loadMoreData();
      }
    });
  }

  /// Clear all data and reset state
  void _clearData() {
    setState(() {
      _data.clear();
      _isLoading = false;
      _isLoadingMore = false;
      _errorMessage = null;
      _currentPage = 1;
      _totalPages = 1;
      _hasMoreData = true;
    });
  }

  /// Fetch initial data or refresh
  Future<void> _fetchData({bool isRefresh = false}) async {
    if (!widget.enabled) return;

    print(
      '🔍 InfiniteScrollList: Fetching ${widget.categoryDisplayName} data - isRefresh: $isRefresh, endpoint: ${widget.apiEndpoint}',
    );

    try {
      setState(() {
        if (isRefresh) {
          _isLoading = true;
          _currentPage = 1;
          _data.clear();
          _hasMoreData = true;
        } else {
          _isLoading = true;
        }
        _errorMessage = null;
      });

      // Get location data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('latitude') ?? 40.7128; // Default to NYC
      final lng = prefs.getDouble('longitude') ?? -74.0060; // Default to NYC

      print('📍 InfiniteScrollList: Location data - Lat: $lat, Lng: $lng');

      // Prepare request body by merging base body with pagination and location
      final requestBody = {
        ...widget.baseRequestBody,
        'lat': lat,
        'lng': lng,
        'page': _currentPage,
        'page_size': 20,
      };

      // Add subcategory filter if provided and not "all"
      print(
        '🏷️ InfiniteScrollList: SubCategory ID: "${widget.subCategoryId}"',
      );

      if (widget.subCategoryId != null &&
          widget.subCategoryId!.isNotEmpty &&
          widget.subCategoryId!.toLowerCase() != 'all') {
        requestBody['sub_category_id'] = widget.subCategoryId!;
        print(
          '✅ InfiniteScrollList: Added sub_category_id to request: ${widget.subCategoryId}',
        );
      } else {
        print(
          '🚫 InfiniteScrollList: Not adding sub_category_id (value: "${widget.subCategoryId}")',
        );
      }

      print(
        '📤 InfiniteScrollList: Sending request to ${widget.apiEndpoint}: $requestBody',
      );

      final response = await ApiService.post(
        widget.apiEndpoint,
        body: requestBody,
        useBearerToken: true,
      );

      print(
        '📥 InfiniteScrollList: Response for ${widget.categoryDisplayName}: ${response['statusCode']}',
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final List<dynamic> responseData = response['data']['data'] ?? [];
        final pagination = response['data']['pagination'] ?? {};

        print(
          '📊 InfiniteScrollList: ${widget.categoryDisplayName} data loaded - ${responseData.length} items',
        );

        setState(() {
          if (isRefresh) {
            _data = responseData.cast<Map<String, dynamic>>();
          } else {
            _data.addAll(responseData.cast<Map<String, dynamic>>());
          }

          // Update pagination info
          _totalPages = pagination['total_pages'] ?? 1;
          _hasMoreData = pagination['has_next'] ?? false;
          _currentPage = pagination['current_page'] ?? 1;

          _isLoading = false;
        });

        print(
          '✅ InfiniteScrollList: ${widget.categoryDisplayName} state updated - ${_data.length} total items, hasMore: $_hasMoreData',
        );
      } else {
        setState(() {
          _errorMessage =
              response['data']?['message'] ??
              'Failed to load ${widget.categoryDisplayName.toLowerCase()} data';
          _isLoading = false;
        });
        print(
          '❌ InfiniteScrollList: ${widget.categoryDisplayName} fetch failed: ${response['data']?['message']}',
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      print(
        '❌ InfiniteScrollList: Exception fetching ${widget.categoryDisplayName} data: $e',
      );
    }
  }

  /// Load more data for pagination
  Future<void> _loadMoreData() async {
    // Prevent multiple simultaneous calls
    if (_isLoadingMore ||
        !_hasMoreData ||
        _errorMessage != null ||
        !widget.enabled)
      return;

    print(
      '📄 InfiniteScrollList: Loading more ${widget.categoryDisplayName} data - Page: ${_currentPage + 1}',
    );

    try {
      setState(() {
        _isLoadingMore = true;
      });

      _currentPage++;

      // Get location data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('latitude') ?? 40.7128;
      final lng = prefs.getDouble('longitude') ?? -74.0060;

      print(
        '📍 InfiniteScrollList: Load more - Location data - Lat: $lat, Lng: $lng',
      );

      // Prepare request body by merging base body with pagination and location
      final requestBody = {
        ...widget.baseRequestBody,
        'lat': lat,
        'lng': lng,
        'page': _currentPage,
        'page_size': 20,
      };

      // Add subcategory filter if provided and not "all"
      if (widget.subCategoryId != null &&
          widget.subCategoryId!.isNotEmpty &&
          widget.subCategoryId!.toLowerCase() != 'all') {
        requestBody['sub_category_id'] = widget.subCategoryId!;
        print(
          '✅ InfiniteScrollList: Load more - Added sub_category_id: ${widget.subCategoryId}',
        );
      } else {
        print(
          '🚫 InfiniteScrollList: Load more - Not adding sub_category_id (value: "${widget.subCategoryId}")',
        );
      }

      print(
        '📤 InfiniteScrollList: Load more request to ${widget.apiEndpoint}: $requestBody',
      );

      final response = await ApiService.post(
        widget.apiEndpoint,
        body: requestBody,
        useBearerToken: true,
      );

      if (response['data'] != null && response['data']['status'] == 200) {
        final List<dynamic> responseData = response['data']['data'] ?? [];
        final pagination = response['data']['pagination'] ?? {};

        setState(() {
          _data.addAll(responseData.cast<Map<String, dynamic>>());
          _hasMoreData = pagination['has_next'] ?? false;
          _isLoadingMore = false;
        });

        print(
          '✅ InfiniteScrollList: Loaded more ${widget.categoryDisplayName} data - ${responseData.length} new items, Total: ${_data.length}, hasMore: $_hasMoreData',
        );
      } else {
        setState(() {
          _currentPage--; // Revert page increment on error
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        // Revert page increment on error
        _currentPage--;
        _isLoadingMore = false;
      });

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load more ${widget.categoryDisplayName.toLowerCase()}: $e',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(label: 'Retry', onPressed: _loadMoreData),
          ),
        );
      }

      print(
        '❌ InfiniteScrollList: Exception loading more ${widget.categoryDisplayName} data: $e',
      );
    }
  }

  /// Public method to refresh data - can be called from parent widgets
  Future<void> refreshData() async {
    await _fetchData(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!widget.enabled) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    if (_isLoading && _data.isEmpty) {
      // Initial loading state
      return SliverToBoxAdapter(
        child: Container(
          height: 400,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Loading ${widget.categoryDisplayName.toLowerCase()}...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null && _data.isEmpty) {
      // Error state with retry option
      return SliverToBoxAdapter(
        child: Container(
          height: 400,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading ${widget.categoryDisplayName.toLowerCase()}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _fetchData(isRefresh: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_data.isEmpty) {
      // No data found state
      return SliverToBoxAdapter(
        child: Container(
          height: 400,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No ${widget.categoryDisplayName} found',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Try changing your location or filters',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _fetchData(isRefresh: true),
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    // Data list with infinite scroll
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        // Show loading indicator at the end if loading more
        if (index == _data.length) {
          if (_isLoadingMore) {
            return Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                color: theme.colorScheme.primary,
              ),
            );
          } else if (!_hasMoreData) {
            return Container(
              padding: const EdgeInsets.all(16),
              alignment: Alignment.center,
              child: Text(
                'No more ${widget.categoryDisplayName.toLowerCase()} to load',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        }

        // Build item using the provided itemBuilder
        return widget.itemBuilder(_data[index], index);
      }, childCount: _data.length + (_isLoadingMore || !_hasMoreData ? 1 : 0)),
    );
  }
}
