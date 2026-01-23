import 'package:flutter/material.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/screens/location_selection_screen.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/components/universal_translation_wrapper.dart';
import 'package:exanor/services/enhanced_translation_service.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _addresses = [];
  List<Map<String, dynamic>> _filteredAddresses = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Track expanded cards
  final Set<String> _expandedCards = <String>{};

  // Enhanced translation service for API responses
  final EnhancedTranslationService _enhancedTranslation =
      EnhancedTranslationService.instance;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterAddresses(_searchController.text);
  }

  void _filterAddresses(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredAddresses = List.from(_addresses);
      } else {
        _filteredAddresses = _addresses.where((address) {
          final searchText = query.toLowerCase();

          // Search across multiple fields
          final addressName = (address['address_name'] ?? '')
              .toString()
              .toLowerCase();
          final attendeeName = (address['attendee_name'] ?? '')
              .toString()
              .toLowerCase();
          final addressLine1 = (address['address_line_1'] ?? '')
              .toString()
              .toLowerCase();
          final addressLine2 = (address['address_line_2'] ?? '')
              .toString()
              .toLowerCase();
          final locality = (address['locality'] ?? '').toString().toLowerCase();
          final city = (address['city'] ?? '').toString().toLowerCase();
          final state = (address['state'] ?? '').toString().toLowerCase();
          final district = (address['district'] ?? '').toString().toLowerCase();
          final area = (address['area'] ?? '').toString().toLowerCase();
          final pincode = (address['pincode'] ?? 0).toString();

          return addressName.contains(searchText) ||
              attendeeName.contains(searchText) ||
              addressLine1.contains(searchText) ||
              addressLine2.contains(searchText) ||
              locality.contains(searchText) ||
              city.contains(searchText) ||
              state.contains(searchText) ||
              district.contains(searchText) ||
              area.contains(searchText) ||
              pincode.contains(searchText);
        }).toList();
      }
    });
  }

  Future<void> _fetchAddresses() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Send POST request to /user-address/ with bearer token
      final response = await ApiService.post(
        '/user-address/',
        body: {"query": {}},
        useBearerToken: true,
      );

      if (mounted) {
        if (response['data'] != null && response['data']['status'] == 200) {
          final rawAddresses = List<Map<String, dynamic>>.from(
            response['data']['response'] ?? [],
          );

          // Translate API response data (addresses, areas, localities, etc.)
          final translatedAddresses = await _enhancedTranslation
              .translateApiResponseList(
                rawAddresses,
                translateUserNames:
                    false, // Don't translate address IDs/phone numbers
                forceIncludeFields: [
                  'address_name',
                  'address_line_1',
                  'address_line_2',
                  'locality',
                  'city',
                  'area',
                  'district',
                  'state',
                  'attendee_name',
                ],
                excludeFields: ['id', 'phone_number', 'pincode', 'lat', 'lng'],
              );

          setState(() {
            _addresses = translatedAddresses;
            _filteredAddresses = List.from(_addresses);
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to load addresses';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Network error: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            TranslatedText(
              'Select a location',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
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
      ),
      body: UniversalTranslationWrapper(
        excludePatterns: [
          '@',
          '.com',
          '+',
          'ID:',
        ], // Don't translate emails, URLs, phone numbers, IDs
        child: RefreshIndicator(
          onRefresh: _fetchAddresses,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.3),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for area, street name...',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: theme.colorScheme.primary,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.6,
                                ),
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Search Results Info
                if (_searchController.text.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: TranslatedText(
                      '${_filteredAddresses.length} address${_filteredAddresses.length != 1 ? 'es' : ''} found',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],

                // Add Address Option
                _buildActionTile(
                  icon: Icons.add,
                  iconColor: theme.colorScheme.primary,
                  title: 'Add address',
                  onTap: () async {
                    // Navigate to location selection screen
                    final result = await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LocationSelectionScreen(),
                      ),
                    );

                    // If address was selected, refresh the addresses list
                    if (result != null) {
                      _fetchAddresses();
                    }
                  },
                ),

                const SizedBox(height: 32),

                // Saved Addresses Section
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_errorMessage != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          TranslatedText(
                            _errorMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchAddresses,
                            child: const TranslatedText('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  TranslatedText(
                    'SAVED ADDRESSES',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_filteredAddresses.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              _searchController.text.isNotEmpty
                                  ? Icons.search_off
                                  : Icons.location_off,
                              size: 48,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TranslatedText(
                              _searchController.text.isNotEmpty
                                  ? 'No addresses found'
                                  : 'No saved addresses',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.7,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TranslatedText(
                              _searchController.text.isNotEmpty
                                  ? 'Try searching with different keywords'
                                  : 'Add your first address to get started',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredAddresses.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final address = _filteredAddresses[index];
                        return _buildAddressCard(address, theme);
                      },
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TranslatedText(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    TranslatedText(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> address, ThemeData theme) {
    // Extract address data based on the new API response structure
    final String addressId = address['id'] ?? '';
    final String addressName = address['address_name'] ?? 'Address';
    final String attendeeName = address['attendee_name'] ?? '';
    final String addressLine1 = address['address_line_1'] ?? '';
    final String addressLine2 = address['address_line_2'] ?? '';
    final String locality = address['locality'] ?? '';
    final String state = address['state'] ?? '';
    final String district = address['district'] ?? '';
    final String city = address['city'] ?? '';
    final String area = address['area'] ?? '';
    final int pincode = address['pincode'] ?? 0;
    final int phoneNumber = address['phone_number'] ?? 0;

    // Check if this card is expanded
    final bool isExpanded = _expandedCards.contains(addressId);

    // Build short address for collapsed view
    List<String> shortAddressParts = [];
    if (addressLine1.isNotEmpty) shortAddressParts.add(addressLine1);
    if (area.isNotEmpty) shortAddressParts.add(area);
    if (locality.isNotEmpty) shortAddressParts.add(locality);
    final String shortAddress = shortAddressParts.join(', ');

    // Build full address string for expanded view
    List<String> fullAddressParts = [];
    if (addressLine1.isNotEmpty) fullAddressParts.add(addressLine1);
    if (addressLine2.isNotEmpty) fullAddressParts.add(addressLine2);
    if (area.isNotEmpty) fullAddressParts.add(area);
    if (locality.isNotEmpty) fullAddressParts.add(locality);
    if (district.isNotEmpty) fullAddressParts.add(district);
    if (city.isNotEmpty) fullAddressParts.add(city);
    if (state.isNotEmpty) fullAddressParts.add(state);
    if (pincode > 0) fullAddressParts.add(pincode.toString());
    final String fullAddress = fullAddressParts.join(', ');

    IconData addressIcon;
    Color iconColor = theme.colorScheme.primary;

    // Determine icon based on address type
    switch (addressName.toLowerCase()) {
      case 'home':
        addressIcon = Icons.home;
        iconColor = Colors.green;
        break;
      case 'work':
        addressIcon = Icons.work;
        iconColor = Colors.blue;
        break;
      case 'office':
        addressIcon = Icons.business;
        iconColor = Colors.blue;
        break;
      case 'friends and family':
      case 'friends':
      case 'family':
        addressIcon = Icons.people;
        iconColor = Colors.orange;
        break;
      default:
        addressIcon = Icons.location_on;
        iconColor = theme.colorScheme.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isExpanded) {
              _expandedCards.remove(addressId);
            } else {
              _expandedCards.add(addressId);
            }
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row - Always visible
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(addressIcon, color: iconColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TranslatedText(
                          addressName.toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: iconColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (attendeeName.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          TranslatedText(
                            attendeeName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // More options button
                      IconButton(
                        onPressed: () {
                          _showAddressOptions(address);
                        },
                        icon: Icon(
                          Icons.more_vert,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          size: 20,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      // Expand/Collapse button
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Short Address - Always visible
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TranslatedText(
                      shortAddress.isNotEmpty ? shortAddress : fullAddress,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                        height: 1.4,
                      ),
                      maxLines: isExpanded ? null : 2,
                      overflow: isExpanded ? null : TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Expandable Content
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Full Address (only if different from short)
                    if (fullAddress != shortAddress) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(
                            0.3,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.map_outlined,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.6,
                              ),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TranslatedText(
                                    'FULL ADDRESS',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TranslatedText(
                                    fullAddress,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.9),
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Contact Information
                    if (phoneNumber > 0) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '+91 ${phoneNumber.toString()}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Address Details Grid
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(
                          0.3,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          if (locality.isNotEmpty || district.isNotEmpty)
                            Row(
                              children: [
                                if (locality.isNotEmpty) ...[
                                  Expanded(
                                    child: _buildDetailItem(
                                      'Locality',
                                      locality,
                                      theme,
                                    ),
                                  ),
                                ],
                                if (locality.isNotEmpty && district.isNotEmpty)
                                  const SizedBox(width: 16),
                                if (district.isNotEmpty) ...[
                                  Expanded(
                                    child: _buildDetailItem(
                                      'District',
                                      district,
                                      theme,
                                    ),
                                  ),
                                ],
                              ],
                            ),

                          if ((locality.isNotEmpty || district.isNotEmpty) &&
                              (city.isNotEmpty || state.isNotEmpty))
                            const SizedBox(height: 8),

                          if (city.isNotEmpty || state.isNotEmpty)
                            Row(
                              children: [
                                if (city.isNotEmpty) ...[
                                  Expanded(
                                    child: _buildDetailItem(
                                      'City',
                                      city,
                                      theme,
                                    ),
                                  ),
                                ],
                                if (city.isNotEmpty && state.isNotEmpty)
                                  const SizedBox(width: 16),
                                if (state.isNotEmpty) ...[
                                  Expanded(
                                    child: _buildDetailItem(
                                      'State',
                                      state,
                                      theme,
                                    ),
                                  ),
                                ],
                              ],
                            ),

                          if (pincode > 0 &&
                              (city.isNotEmpty ||
                                  state.isNotEmpty ||
                                  locality.isNotEmpty ||
                                  district.isNotEmpty)) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildDetailItem(
                                  'Pincode',
                                  pincode.toString(),
                                  theme,
                                ),
                                const Spacer(),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _selectAddress(address);
                        },
                        icon: const Icon(Icons.my_location, size: 18),
                        label: const TranslatedText('Select This Address'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TranslatedText(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        TranslatedText(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showAddressOptions(Map<String, dynamic> address) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: theme.colorScheme.primary),
              title: const TranslatedText('Edit address'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: TranslatedText('Edit address coming soon!'),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: theme.colorScheme.error),
              title: const TranslatedText('Delete address'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(address);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> address) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const TranslatedText('Delete Address'),
        content: const TranslatedText(
          'Are you sure you want to delete this address?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const TranslatedText('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAddress(address);
            },
            child: const TranslatedText('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteAddress(Map<String, dynamic> address) {
    // Implement delete functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: TranslatedText('Delete functionality coming soon!')),
    );
  }

  void _showSelectionAnimation(BuildContext context, String addressName) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(
                          (value * 50) - 25,
                          -sin(value * pi) * 20,
                        ),
                        child: Transform.rotate(
                          angle: 0.2 * value,
                          child: Icon(
                            Icons.flight_takeoff_rounded,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  TranslatedText(
                    'Flying to $addressName...',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectAddress(Map<String, dynamic> address) async {
    try {
      print('📍 SavedAddresses: Processing address selection...');
      print('   Raw address data: $address');

      // Extract address information
      final String addressName = address['address_name'] ?? 'Address';
      final String addressLine1 = address['address_line_1'] ?? '';
      final String addressLine2 = address['address_line_2'] ?? '';

      // Parse coordinates from strings (API returns lat/lng as strings)
      final double lat =
          double.tryParse(address['lat']?.toString() ?? '0.0') ?? 0.0;
      final double lng =
          double.tryParse(address['lng']?.toString() ?? '0.0') ?? 0.0;

      print('📍 SavedAddresses: Parsed coordinates - Lat: $lat, Lng: $lng');
      print('   Original lat string: "${address['lat']}"');
      print('   Original lng string: "${address['lng']}"');

      // Extract area and city for subtitle
      final String area = address['area'] ?? '';
      final String city = address['city'] ?? '';
      final String locality = address['locality'] ?? '';

      // Build address subtitle with priority: address_lines + area/city
      List<String> addressParts = [];
      if (addressLine1.isNotEmpty) addressParts.add(addressLine1);
      if (addressLine2.isNotEmpty) addressParts.add(addressLine2);

      // Add area or locality, then city for location context
      if (area.isNotEmpty && area != city) {
        addressParts.add(area);
      } else if (locality.isNotEmpty && locality != city) {
        addressParts.add(locality);
      }
      if (city.isNotEmpty) {
        addressParts.add(city);
      }

      final String addressSubtitle = addressParts.join(', ');

      // Save address data to SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Save address title and subtitle for display (using new keys to match HomeScreen)
      await prefs.setString('address_title', addressName.toUpperCase());
      await prefs.setString(
        'address_subtitle',
        addressSubtitle.isNotEmpty ? addressSubtitle : 'Selected address',
      );

      // Save area and city for additional context
      await prefs.setString('display_area', area);
      await prefs.setString('display_city', city);
      await prefs.setString('display_locality', locality);

      // Save latitude and longitude (using new keys to match HomeScreen)
      await prefs.setDouble('latitude', lat);
      await prefs.setDouble('longitude', lng);
      await prefs.setString('lat_string', address['lat']?.toString() ?? '0.0');
      await prefs.setString('lng_string', address['lng']?.toString() ?? '0.0');

      // Save complete address data for future use (using consistent naming)
      await prefs.setString('saved_address_id', address['id'] ?? '');
      await prefs.setString('saved_address_name', addressName);
      await prefs.setString('saved_address_line_1', addressLine1);
      await prefs.setString('saved_address_line_2', addressLine2);
      await prefs.setString('saved_locality', address['locality'] ?? '');
      await prefs.setString('saved_city', address['city'] ?? '');
      await prefs.setString('saved_state', address['state'] ?? '');
      await prefs.setString('saved_district', address['district'] ?? '');
      await prefs.setString('saved_area', address['area'] ?? '');
      await prefs.setInt('saved_pincode', address['pincode'] ?? 0);
      await prefs.setInt('saved_phone_number', address['phone_number'] ?? 0);
      await prefs.setString(
        'saved_attendee_name',
        address['attendee_name'] ?? '',
      );

      print(
        '📍 SavedAddresses: Address data saved to SharedPreferences with NEW KEYS',
      );
      print('   address_title: ${addressName.toUpperCase()}');
      print('   address_subtitle: $addressSubtitle');
      print('   display_area: $area');
      print('   display_city: $city');
      print('   latitude: $lat');
      print('   longitude: $lng');
      print(
        '📍 SavedAddresses: This should match the keys HomeScreen is looking for',
      );

      // Show animation
      if (mounted) {
        _showSelectionAnimation(context, addressName);
      }

      // Wait for animation
      await Future.delayed(const Duration(milliseconds: 1800));

      if (mounted) {
        // Close animation dialog
        Navigator.of(context).pop();

        // Navigate back to previous screen (HomeScreen)
        Navigator.pop(context, {
          'addressSelected': true,
          'addressData': address,
        });
      }
    } catch (e) {
      print('❌ SavedAddresses: Error selecting address: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting address: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
