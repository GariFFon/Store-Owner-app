import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/screens/store_owner_pos_screen.dart';
import 'package:exanor/services/api_service.dart';

class StoreSelectionScreen extends StatefulWidget {
  const StoreSelectionScreen({super.key});

  @override
  State<StoreSelectionScreen> createState() => _StoreSelectionScreenState();
}

class _StoreSelectionScreenState extends State<StoreSelectionScreen> {
  List<dynamic> _stores = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingStoreSelection();
  }

  Future<void> _checkExistingStoreSelection() async {
    try {
      // Check if a store is already selected
      final prefs = await SharedPreferences.getInstance();
      final selectedStoreId = prefs.getString('selected_store_id');
      final selectedStoreName = prefs.getString('selected_store_name');

      if (selectedStoreId != null && selectedStoreName != null) {
        // Navigate directly to POS screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => StoreOwnerPOSScreen(
                storeId: selectedStoreId,
                storeName: selectedStoreName,
              ),
            ),
          );
        }
      } else {
        // Fetch stores from API
        await _fetchStores();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking store selection: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStores() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Fetch all stores from /user-stores/ endpoint (POST method)
      final response = await ApiService.post(
        '/user-stores/',
        useBearerToken: true,
      );

      if (response['statusCode'] == 200 && response['data'] != null) {
        final data = response['data'];

        if (data['status'] == 200 && data['response'] != null) {
          setState(() {
            _stores = data['response'] is List ? data['response'] : [];
            _isLoading = false;
          });

          // If only one store, auto-select it
          if (_stores.length == 1) {
            await _selectStore(_stores[0]);
          }
        } else {
          setState(() {
            _errorMessage = 'No stores found';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to fetch stores';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching stores: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _selectStore(dynamic store) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storeId = store['id'] ?? store['store_id'] ?? '';
      final storeName = store['name'] ?? store['store_name'] ?? 'Store';

      // Save selected store
      await prefs.setString('selected_store_id', storeId);
      await prefs.setString('selected_store_name', storeName);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                StoreOwnerPOSScreen(storeId: storeId, storeName: storeName),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting store: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingView(theme)
            : _errorMessage != null
            ? _buildErrorView(theme)
            : _buildStoreList(theme),
      ),
    );
  }

  Widget _buildLoadingView(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your stores...',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchStores,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreList(ThemeData theme) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Your Store',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a store to manage',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),

        // Store List
        Expanded(
          child: _stores.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.store_outlined,
                        size: 64,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No stores available',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _stores.length,
                  itemBuilder: (context, index) {
                    final store = _stores[index];
                    return _buildStoreCard(theme, store);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStoreCard(ThemeData theme, dynamic store) {
    final storeName = store['name'] ?? store['store_name'] ?? 'Store';
    final storeAddress = store['address'] ?? store['location'] ?? '';
    final storeType = store['type'] ?? store['store_type'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _selectStore(store),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Store Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.store, size: 32, color: theme.primaryColor),
              ),
              const SizedBox(width: 16),

              // Store Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (storeType.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        storeType,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (storeAddress.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        storeAddress,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withOpacity(
                            0.6,
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow Icon
              Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
