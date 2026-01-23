import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exanor/services/api_service.dart';
import 'package:exanor/screens/HomeScreen.dart';
import 'package:exanor/components/translation_widget.dart';
import 'package:exanor/components/universal_translation_wrapper.dart';
import 'package:exanor/services/enhanced_translation_service.dart';

class LocationSelectionScreen extends StatefulWidget {
  const LocationSelectionScreen({super.key});

  @override
  State<LocationSelectionScreen> createState() =>
      _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  String selectedLocation = "Locating...";
  String selectedAddress = "Getting address...";
  bool isCurrentLocation = true;
  double distanceKm = 0.0;
  final TextEditingController _searchController = TextEditingController();

  // Google Maps controller
  GoogleMapController? _mapController;

  // Default location (New Delhi) - fallback if location permission denied
  static const CameraPosition _fallbackCameraPosition = CameraPosition(
    target: LatLng(28.6139, 77.2090),
    zoom: 14.0,
  );

  // Current camera position - will be set to user location or fallback
  CameraPosition _currentCameraPosition = _fallbackCameraPosition;

  // Timer for address lookup
  Timer? _addressTimer;

  // Loading state
  bool _isLoadingAddress = false;
  bool _isGettingLocation = true;

  // User's current position
  Position? _userPosition;

  // Plus Code (compound code)
  String _plusCode = '';

  // Store administrative level components
  String _storedNeighborhood = '';
  String _storedLocality = '';
  String _storedAdminLevel1 = '';
  String _storedAdminLevel2 = '';
  String _storedAdminLevel3 = '';
  String _storedPincode = '';

  // Method to check if we have valid location data for confirming
  bool get _hasValidLocationData {
    return !_isGettingLocation &&
        !_isLoadingAddress &&
        selectedLocation != "Locating..." &&
        selectedLocation != "Getting your location..." &&
        selectedLocation != "Requesting location access..." &&
        selectedAddress != "Getting address..." &&
        selectedAddress != "This may take a few seconds" &&
        selectedAddress != "Please allow location access" &&
        selectedLocation.isNotEmpty &&
        selectedAddress.isNotEmpty &&
        (_storedAdminLevel1.isNotEmpty ||
            _storedAdminLevel2
                .isNotEmpty); // Must have at least state or city info
  }

  // Search suggestions
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _isSearching = false;
  bool _showSuggestions = false;
  Timer? _searchTimer;
  bool _isKeyboardVisible = false;

  final List<Map<String, dynamic>> _sampleLocations = [
    {
      'name': 'Block B',
      'address':
          'Block B, Mahipalpur Village, Mahipalpur, New Delhi, Delhi 110037, India',
      'isCurrentLocation': true,
      'distance': 0.0,
      'latLng': LatLng(28.5562, 77.1482),
    },
    {
      'name': 'Borjhar',
      'address': 'Kahikuchi, Assam, India. (Borjhar)',
      'isCurrentLocation': false,
      'distance': 55.9,
      'latLng': LatLng(26.1445, 91.7362),
    },
    {
      'name': 'Connaught Place',
      'address': 'Connaught Place, New Delhi, Delhi 110001, India',
      'isCurrentLocation': false,
      'distance': 12.3,
      'latLng': LatLng(28.6315, 77.2167),
    },
    {
      'name': 'India Gate',
      'address': 'India Gate, Rajpath, New Delhi, Delhi 110001, India',
      'isCurrentLocation': false,
      'distance': 15.7,
      'latLng': LatLng(28.6129, 77.2295),
    },
  ];

  int _currentLocationIndex = 0;

  // Enhanced translation service for API responses
  final EnhancedTranslationService _enhancedTranslation =
      EnhancedTranslationService.instance;

  // Method to translate address text from Google Maps API
  Future<String> _translateAddress(String address) async {
    try {
      // Use the translation service to translate the address
      return await _enhancedTranslation.translateText(address);
    } catch (e) {
      print('❌ Error translating address: $e');
      return address; // Return original if translation fails
    }
  }

  @override
  void initState() {
    super.initState();
    _requestLocationPermissionAndGetLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    _addressTimer?.cancel();
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestLocationPermissionAndGetLocation() async {
    print('🎯 Starting location permission request...');
    try {
      setState(() {
        _isGettingLocation = true;
        selectedLocation = "Requesting location access...";
        selectedAddress = "Please allow location access";
      });

      // Check if location services are enabled with better error handling
      bool serviceEnabled = false;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        print('📍 Location services enabled: $serviceEnabled');
      } catch (e) {
        print('❌ Error checking location services: $e');
        _showLocationServicesDialog();
        return;
      }

      if (!serviceEnabled) {
        print('❌ Location services disabled');
        _showLocationServicesDialog();
        return;
      }

      // Check location permission with enhanced error handling
      LocationPermission permission;
      try {
        permission = await Geolocator.checkPermission();
        print('🔐 Current permission status: $permission');
      } catch (e) {
        print('❌ Error checking location permission: $e');
        _setFallbackLocation();
        return;
      }

      if (permission == LocationPermission.denied) {
        print('🔐 Requesting permission...');
        try {
          permission = await Geolocator.requestPermission();
          print('🔐 Permission after request: $permission');
        } catch (e) {
          print('❌ Error requesting permission: $e');
          _setFallbackLocation();
          return;
        }

        if (permission == LocationPermission.denied) {
          print('❌ Permission denied');
          _setFallbackLocation();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Permission denied forever');
        _showPermissionDeniedDialog();
        return;
      }

      // Get current position with enhanced error handling
      setState(() {
        selectedLocation = "Getting your location...";
        selectedAddress = "This may take a few seconds";
      });

      print('📍 Getting current position...');
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15), // Increased timeout
          ),
        );
      } catch (e) {
        print('❌ Error getting current position: $e');
        // Try with medium accuracy as fallback
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 10),
            ),
          );
        } catch (e2) {
          print('❌ Error getting position with medium accuracy: $e2');
          _setFallbackLocation();
          return;
        }
      }

      print('✅ Got position: ${position.latitude}, ${position.longitude}');
      _userPosition = position;
      LatLng userLatLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentCameraPosition = CameraPosition(target: userLatLng, zoom: 16.0);
        isCurrentLocation = true;
        _isGettingLocation = false;
      });

      print('📱 Moving camera to user location...');
      // Move camera to user location
      if (_mapController != null) {
        try {
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(_currentCameraPosition),
            duration: const Duration(milliseconds: 1000),
          );
        } catch (e) {
          print('❌ Error animating camera: $e');
          // Continue without animation
        }
      }

      // Get address for user location
      _getAddressFromCoordinates(userLatLng);
    } catch (e) {
      print('❌ Unexpected error in location request: $e');
      _setFallbackLocation();
    }
  }

  void _setFallbackLocation() {
    setState(() {
      _currentCameraPosition = _fallbackCameraPosition;
      selectedLocation = "Default Location";
      selectedAddress = "Location access denied - using default location";
      isCurrentLocation = false;
      distanceKm = 0.0;
      _isGettingLocation = false;
    });

    // Get address for fallback location
    Timer(const Duration(milliseconds: 500), () {
      _getAddressFromCoordinates(_fallbackCameraPosition.target);
    });
  }

  void _showLocationServicesDialog() {
    setState(() {
      _isGettingLocation = false;
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const TranslatedText('Location Services Disabled'),
          content: const TranslatedText(
            'Please enable location services in your device settings to use this feature. We\'ll use a default location for now.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _setFallbackLocation();
              },
              child: const TranslatedText('Use Default'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _requestLocationPermissionAndGetLocation();
              },
              child: const TranslatedText('Retry'),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionDeniedDialog() {
    setState(() {
      _isGettingLocation = false;
    });

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const TranslatedText('Location Permission Required'),
          content: const TranslatedText(
            'Location access has been permanently denied. Please enable it in your device settings or use the default location.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _setFallbackLocation();
              },
              child: const TranslatedText('Use Default'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const TranslatedText('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  void _getAddressFromCoordinates(LatLng position) async {
    setState(() {
      _isLoadingAddress = true;
      selectedLocation = "Locating...";
      selectedAddress = "Getting address...";
    });

    try {
      print(
        '🗺️ Getting address for: ${position.latitude}, ${position.longitude}',
      );

      // Use Google Maps Geocoding API with API key from environment
      final String? apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        print('❌ Google Maps API key not found in environment');
        _setFallbackAddress(position);
        return;
      }

      final String url =
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$apiKey';

      print('🌐 Making request to geocoding API');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📍 Response: ${data.toString()}');

        if (data['status'] == 'OK' &&
            data['results'] != null &&
            data['results'].isNotEmpty) {
          final result = data['results'][0];

          // Get formatted address and plus code
          String formattedAddress = result['formatted_address'] ?? '';
          String plusCode = '';

          // Extract Plus Code (compound code)
          if (result['plus_code'] != null) {
            plusCode =
                result['plus_code']['compound_code'] ??
                result['plus_code']['global_code'] ??
                '';
          }

          // Extract specific address components
          String locationName = 'Unknown Location';
          String neighborhood = '';
          String adminLevel2 = ''; // District/County
          String adminLevel3 = ''; // Sub-district
          String adminLevel1 = ''; // State/Province
          String locality = '';
          String route = '';
          String pincode = '';

          if (result['address_components'] != null) {
            final components = result['address_components'] as List;

            // Parse all components
            for (var component in components) {
              final types = component['types'] as List;
              final longName = component['long_name'] as String? ?? '';

              if (longName.isNotEmpty) {
                // Location name priority: establishment > point_of_interest > premise > route
                if (types.contains('establishment') ||
                    types.contains('point_of_interest') ||
                    types.contains('premise')) {
                  if (locationName == 'Unknown Location') {
                    locationName = longName;
                  }
                }

                // Route (street name)
                if (types.contains('route') && route.isEmpty) {
                  route = longName;
                  if (locationName == 'Unknown Location') {
                    locationName = longName;
                  }
                }

                // Neighborhood
                if (types.contains('neighborhood') ||
                    types.contains('sublocality_level_1') ||
                    types.contains('sublocality')) {
                  if (neighborhood.isEmpty) {
                    neighborhood = longName;
                  }
                  if (locationName == 'Unknown Location') {
                    locationName = longName;
                  }
                }

                // Locality (city)
                if (types.contains('locality') && locality.isEmpty) {
                  locality = longName;
                }

                // Administrative area level 3 (sub-district) - for district
                if (types.contains('administrative_area_level_3') &&
                    adminLevel3.isEmpty) {
                  adminLevel3 = longName;
                }

                // Administrative area level 2 (district/county) - for city
                if (types.contains('administrative_area_level_2') &&
                    adminLevel2.isEmpty) {
                  adminLevel2 = longName;
                }

                // Administrative area level 1 (state/province)
                if (types.contains('administrative_area_level_1') &&
                    adminLevel1.isEmpty) {
                  adminLevel1 = longName;
                }

                // Postal code (pincode)
                if (types.contains('postal_code') && pincode.isEmpty) {
                  pincode = longName;
                }
              }
            }
          }

          // Build address in priority order: neighborhood > district > state
          List<String> addressParts = [];

          if (neighborhood.isNotEmpty && neighborhood != locationName) {
            addressParts.add(neighborhood);
          }

          if (adminLevel2.isNotEmpty && !addressParts.contains(adminLevel2)) {
            addressParts.add(adminLevel2);
          }

          if (adminLevel1.isNotEmpty && !addressParts.contains(adminLevel1)) {
            addressParts.add(adminLevel1);
          }

          // Add locality if nothing else is available
          if (addressParts.isEmpty && locality.isNotEmpty) {
            addressParts.add(locality);
          }

          String finalAddress = addressParts.isNotEmpty
              ? addressParts.join(', ')
              : formattedAddress.split(',').take(3).join(', ');

          // Translate the address before setting it
          final String translatedAddress = await _translateAddress(
            finalAddress.isNotEmpty ? finalAddress : "Address not found",
          );

          setState(() {
            selectedLocation = locationName;
            selectedAddress = translatedAddress;
            _plusCode = plusCode;
            _isLoadingAddress = false;
            distanceKm = isCurrentLocation ? 0.0 : 2.5;
          });

          // Store administrative level components for later use
          _storeAddressComponents(
            neighborhood: neighborhood,
            locality: locality,
            adminLevel1: adminLevel1,
            adminLevel2: adminLevel2,
            adminLevel3: adminLevel3,
            pincode: pincode,
          );

          print('✅ Final address: $selectedLocation - $selectedAddress');
          print(
            '📍 Components - Neighborhood: $neighborhood, Locality: $locality, District: $adminLevel3, City: $adminLevel2, State: $adminLevel1, Pincode: $pincode',
          );
          print('🗺️ Plus Code: $plusCode');
        } else {
          print('⚠️ No results from Google Geocoding API');
          _setFallbackAddress(position);
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        _setFallbackAddress(position);
      }
    } catch (e) {
      print('❌ Error getting address: $e');
      _setFallbackAddress(position);
    }
  }

  void _setFallbackAddress(LatLng position) {
    setState(() {
      selectedLocation = "Location Found";
      selectedAddress =
          "Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}";
      _plusCode = '';
      _isLoadingAddress = false;
      distanceKm = 2.5;
    });
  }

  void _storeAddressComponents({
    required String neighborhood,
    required String locality,
    required String adminLevel1,
    required String adminLevel2,
    required String adminLevel3,
    required String pincode,
  }) {
    _storedNeighborhood = neighborhood;
    _storedLocality = locality;
    _storedAdminLevel1 = adminLevel1;
    _storedAdminLevel2 = adminLevel2;
    _storedAdminLevel3 = adminLevel3;
    _storedPincode = pincode;

    print('🗺️ Stored address components:');
    print('   Neighborhood: $_storedNeighborhood');
    print('   Locality: $_storedLocality');
    print('   State (Admin L1): $_storedAdminLevel1');
    print('   City (Admin L2): $_storedAdminLevel2');
    print('   District (Admin L3): $_storedAdminLevel3');
    print('   Pincode: $_storedPincode');
  }

  void _changeLocation() {
    setState(() {
      _currentLocationIndex =
          (_currentLocationIndex + 1) % _sampleLocations.length;
      final location = _sampleLocations[_currentLocationIndex];

      // Update camera position
      _currentCameraPosition = CameraPosition(
        target: location['latLng'],
        zoom: 14.0,
      );

      // Move camera to new location with optimized animation
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(_currentCameraPosition),
        duration: const Duration(
          milliseconds: 500,
        ), // Reduce animation duration
      );

      // Get address for the new location
      _getAddressFromCoordinates(location['latLng']);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    // If we already have a user location, move to it
    if (_userPosition != null) {
      LatLng userLatLng = LatLng(
        _userPosition!.latitude,
        _userPosition!.longitude,
      );
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: userLatLng, zoom: 16.0),
        ),
        duration: const Duration(milliseconds: 500),
      );
    }
    // If we're still getting location, don't override anything
    // If we've set a fallback location, that's already in _currentCameraPosition
  }

  void _onCameraMove(CameraPosition position) {
    setState(() {
      _currentCameraPosition = position;
    });

    // Cancel any existing timer
    _addressTimer?.cancel();

    // Start a new timer for 1 second
    _addressTimer = Timer(const Duration(seconds: 1), () {
      _getAddressFromCoordinates(position.target);
    });
  }

  void _onCameraIdle() {
    // This is called when the camera stops moving
    // We can use this as additional confirmation
    _getAddressFromCoordinates(_currentCameraPosition.target);
  }

  bool _shouldShowAddressCard() {
    // Don't show address card when keyboard is visible and user is searching
    return !(_isKeyboardVisible &&
        (_showSuggestions || _searchController.text.isNotEmpty));
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _showSuggestions = false;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final String? apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        print('❌ Google Maps API key not found for Places search');
        return;
      }

      // Use Google Places API Text Search
      final String url =
          'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(query)}&key=$apiKey';

      print('🔍 Searching places for: $query');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final List results = data['results'] ?? [];

          setState(() {
            _searchSuggestions = results
                .take(5)
                .map<Map<String, dynamic>>(
                  (place) => {
                    'name': place['name'] ?? '',
                    'formatted_address': place['formatted_address'] ?? '',
                    'place_id': place['place_id'] ?? '',
                    'geometry': place['geometry'] ?? {},
                    'types': place['types'] ?? [],
                  },
                )
                .toList();
            _showSuggestions = _searchSuggestions.isNotEmpty;
            _isSearching = false;
          });

          print('✅ Found ${_searchSuggestions.length} place suggestions');
        } else {
          print('❌ Places API error: ${data['status']}');
          setState(() {
            _isSearching = false;
            _showSuggestions = false;
          });
        }
      } else {
        print('❌ HTTP error: ${response.statusCode}');
        setState(() {
          _isSearching = false;
          _showSuggestions = false;
        });
      }
    } catch (e) {
      print('❌ Error searching places: $e');
      setState(() {
        _isSearching = false;
        _showSuggestions = false;
      });
    }
  }

  void _selectPlace(Map<String, dynamic> place) async {
    final geometry = place['geometry'];
    if (geometry != null && geometry['location'] != null) {
      final location = geometry['location'];
      final LatLng placeLocation = LatLng(
        location['lat']?.toDouble() ?? 0.0,
        location['lng']?.toDouble() ?? 0.0,
      );

      // Update search controller and hide suggestions
      _searchController.text = place['name'] ?? '';
      setState(() {
        _showSuggestions = false;
        _searchSuggestions = [];
        selectedLocation = place['name'] ?? '';
        selectedAddress = place['formatted_address'] ?? '';
        isCurrentLocation = false;
        _currentCameraPosition = CameraPosition(
          target: placeLocation,
          zoom: 16.0,
        );
      });

      // Remove focus from search text field
      FocusScope.of(context).unfocus();

      // Animate camera to the selected place
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(_currentCameraPosition),
        duration: const Duration(milliseconds: 800),
      );

      print(
        '📍 Selected place: ${place['name']} at ${placeLocation.latitude}, ${placeLocation.longitude}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Check if keyboard is visible
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    _isKeyboardVisible = keyboardHeight > 0;

    return Scaffold(
      body: UniversalTranslationWrapper(
        excludePatterns: [
          '+',
          '°',
          'API',
          'GPS',
        ], // Don't translate coordinates, technical terms
        child: GestureDetector(
          onTap: () {
            // Hide suggestions when tapping outside
            if (_showSuggestions) {
              setState(() {
                _showSuggestions = false;
              });
            }
            // Dismiss keyboard when tapping outside
            FocusScope.of(context).unfocus();
          },
          child: Stack(
            children: [
              // Google Maps
              GoogleMap(
                onMapCreated: _onMapCreated,
                onCameraMove: _onCameraMove,
                onCameraIdle: _onCameraIdle,
                initialCameraPosition: _currentCameraPosition,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: false, // Disable to reduce rendering load
                buildingsEnabled: false, // Disable to reduce memory usage
                trafficEnabled: false,
                mapType: MapType.normal,
                // Performance optimizations
                liteModeEnabled: false,
                cameraTargetBounds: CameraTargetBounds.unbounded,
                minMaxZoomPreference: const MinMaxZoomPreference(10.0, 20.0),
                rotateGesturesEnabled: true,
                scrollGesturesEnabled: true,
                tiltGesturesEnabled: false, // Disable tilt to reduce complexity
                zoomGesturesEnabled: true,
                indoorViewEnabled: false, // Disable indoor maps
                fortyFiveDegreeImageryEnabled: false, // Disable 45° imagery
              ),

              // Top Search Bar
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    // Back Button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: theme.colorScheme.onSurface,
                          size: 20,
                        ),
                      ),
                    ),

                    SizedBox(width: 12),

                    // Search Bar
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.shadow.withOpacity(0.1),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) {
                                  // Cancel previous timer
                                  _searchTimer?.cancel();

                                  // Set new timer for debounced search
                                  _searchTimer = Timer(
                                    Duration(milliseconds: 500),
                                    () {
                                      _searchPlaces(value);
                                    },
                                  );

                                  // Update state immediately for address card visibility
                                  setState(() {});
                                },
                                onSubmitted: (value) {
                                  _searchTimer?.cancel();
                                  if (value.isNotEmpty) {
                                    _searchPlaces(value);
                                  }
                                },
                                onTap: () {
                                  // Show suggestions when tapping on search bar
                                  if (_searchController.text.isNotEmpty &&
                                      _searchSuggestions.isNotEmpty) {
                                    setState(() {
                                      _showSuggestions = true;
                                    });
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: 'Search places, areas or addresses',
                                  hintStyle: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                    fontSize: 16,
                                  ),
                                  border: InputBorder.none,
                                  suffixIcon: _isSearching
                                      ? Padding(
                                          padding: EdgeInsets.all(12),
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    theme.colorScheme.primary,
                                                  ),
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            if (!_isSearching)
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: GestureDetector(
                                  onTap: () {
                                    if (_searchController.text.isNotEmpty) {
                                      // Clear search
                                      _searchController.clear();
                                      setState(() {
                                        _searchSuggestions = [];
                                        _showSuggestions = false;
                                      });
                                    }
                                  },
                                  child: Icon(
                                    _searchController.text.isNotEmpty
                                        ? Icons.clear
                                        : Icons.search,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                    size: 24,
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

              // Search Suggestions Overlay
              if (_showSuggestions && _searchSuggestions.isNotEmpty)
                Positioned(
                  top: 120, // Below the search bar
                  left: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withOpacity(0.15),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: _searchSuggestions.map((suggestion) {
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _selectPlace(suggestion),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.place,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          suggestion['name'] ?? '',
                                          style: TextStyle(
                                            color: theme.colorScheme.onSurface,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (suggestion['formatted_address'] !=
                                                null &&
                                            suggestion['formatted_address']
                                                .isNotEmpty)
                                          Padding(
                                            padding: EdgeInsets.only(top: 4),
                                            child: Text(
                                              suggestion['formatted_address'],
                                              style: TextStyle(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.6),
                                                fontSize: 14,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

              // Center Location Pin
              if (_shouldShowAddressCard())
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Location Pin - Lottie Animation
                      Container(
                        width: 80,
                        height: 80,
                        child: Lottie.asset(
                          'assets/lottie/location_marker.json',
                          width: 80,
                          height: 80,
                          fit: BoxFit.contain,
                          repeat: true,
                          animate: true,
                          onLoaded: (composition) {
                            print('✅ Lottie animation loaded successfully');
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('❌ Lottie loading failed: $error');
                            // Fallback to default pin if Lottie fails to load
                            return Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 30,
                              ),
                            );
                          },
                        ),
                      ),

                      SizedBox(height: 20),

                      // Pin instruction
                      TranslatedText(
                        'Move the pin to change location',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),

              // Current Location Button
              if (_shouldShowAddressCard())
                Positioned(
                  bottom: 180,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          if (_userPosition != null) {
                            // Use actual user location if available
                            LatLng userLatLng = LatLng(
                              _userPosition!.latitude,
                              _userPosition!.longitude,
                            );
                            setState(() {
                              _currentCameraPosition = CameraPosition(
                                target: userLatLng,
                                zoom: 16.0,
                              );
                              isCurrentLocation = true;
                            });

                            _mapController?.animateCamera(
                              CameraUpdate.newCameraPosition(
                                _currentCameraPosition,
                              ),
                              duration: const Duration(milliseconds: 400),
                            );

                            _getAddressFromCoordinates(userLatLng);
                          } else {
                            // Request location permission again
                            _requestLocationPermissionAndGetLocation();
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                padding: EdgeInsets.all(4),
                                child: Icon(
                                  Icons.my_location,
                                  color: theme.colorScheme.primary,
                                  size: 18,
                                ),
                              ),
                              SizedBox(width: 8),
                              TranslatedText(
                                'Current Location',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Floating Action Button for cycling locations
              if (_shouldShowAddressCard())
                Positioned(
                  bottom: 240,
                  right: 16,
                  child: FloatingActionButton(
                    mini: true,
                    backgroundColor: theme.colorScheme.surface,
                    foregroundColor: theme.colorScheme.primary,
                    onPressed: _changeLocation,
                    elevation: 4,
                    child: Icon(
                      Icons.refresh,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                ),

              // Bottom Location Details Card
              if (_shouldShowAddressCard())
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.shadow.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TranslatedText(
                            'Place the pin at exact location',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.7,
                              ),
                            ),
                          ),

                          SizedBox(height: 16),

                          Row(
                            children: [
                              _isLoadingAddress
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              theme.colorScheme.primary,
                                            ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.location_on,
                                      color: theme.colorScheme.primary,
                                      size: 24,
                                    ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedLocation,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      selectedAddress,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                    if (_plusCode.isNotEmpty) ...[
                                      SizedBox(height: 4),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary
                                              .withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          'Plus Code: $_plusCode',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),

                          if (!isCurrentLocation && distanceKm > 0) ...[
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber[200]!),
                              ),
                              child: TranslatedText(
                                'This is a different location from your current location.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.amber[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],

                          if (isCurrentLocation) ...[
                            SizedBox(height: 12),
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.zoom_in,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: TranslatedText(
                                      'Zoom in to place the pin at exact location',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.red[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          SizedBox(height: 16),

                          // Confirm Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _hasValidLocationData
                                  ? () =>
                                        _showAddressDetailsBottomSheet(context)
                                  : null, // Disable button when location data isn't ready
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _hasValidLocationData
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withOpacity(
                                        0.3,
                                      ),
                                foregroundColor: _hasValidLocationData
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.onSurface.withOpacity(
                                        0.6,
                                      ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: _isGettingLocation || _isLoadingAddress
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  theme.colorScheme.onSurface
                                                      .withOpacity(0.6),
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        TranslatedText(
                                          _isGettingLocation
                                              ? 'Getting location...'
                                              : 'Loading address...',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    )
                                  : TranslatedText(
                                      _hasValidLocationData
                                          ? 'Confirm & proceed'
                                          : 'Please wait for location...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          SizedBox(
                            height: MediaQuery.of(context).padding.bottom,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddressDetailsBottomSheet(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddressDetailsBottomSheet(
        locationName: selectedLocation,
        locationAddress: selectedAddress,
        latitude: _currentCameraPosition.target.latitude,
        longitude: _currentCameraPosition.target.longitude,
        addressComponents: {
          'neighborhood': _storedNeighborhood,
          'locality': _storedLocality,
          'adminLevel1': _storedAdminLevel1,
          'adminLevel2': _storedAdminLevel2,
          'adminLevel3': _storedAdminLevel3,
          'pincode': _storedPincode,
        },
      ),
    );

    // Update the display if address data was returned
    if (result != null) {
      setState(() {
        selectedLocation = result['displayName'] ?? selectedLocation;
        selectedAddress = result['fullAddress'] ?? selectedAddress;
      });

      // Return the address data to the previous screen (HomeScreen)
      Navigator.pop(context, result);
    }
  }
}

class AddressDetailsBottomSheet extends StatefulWidget {
  final String locationName;
  final String locationAddress;
  final double latitude;
  final double longitude;
  final Map<String, dynamic>? addressComponents;

  const AddressDetailsBottomSheet({
    super.key,
    required this.locationName,
    required this.locationAddress,
    required this.latitude,
    required this.longitude,
    this.addressComponents,
  });

  @override
  State<AddressDetailsBottomSheet> createState() =>
      _AddressDetailsBottomSheetState();
}

class _AddressDetailsBottomSheetState extends State<AddressDetailsBottomSheet> {
  final TextEditingController _houseController = TextEditingController();
  final TextEditingController _apartmentController = TextEditingController();
  final TextEditingController _directionsController = TextEditingController();
  final TextEditingController _customAddressNameController =
      TextEditingController();

  String selectedAddressType = 'Home';
  bool isRecording = false;
  bool _isSaving = false;

  // Validation states
  String? _houseError;
  String? _apartmentError;
  String? _customAddressNameError;

  @override
  void dispose() {
    _houseController.dispose();
    _apartmentController.dispose();
    _directionsController.dispose();
    _customAddressNameController.dispose();
    super.dispose();
  }

  bool _validateFields() {
    print('🔍 _validateFields() called');
    print('📝 House controller text: "${_houseController.text}"');
    print('📝 Apartment controller text: "${_apartmentController.text}"');

    setState(() {
      _houseError = null;
      _apartmentError = null;
      _customAddressNameError = null;
    });
    print('✅ Cleared previous validation errors');

    bool isValid = true;

    // Validate House/Flat/Floor number
    if (_houseController.text.trim().isEmpty) {
      print('❌ House field is empty, setting error');
      setState(() {
        _houseError = 'House/Flat/Floor number is required';
      });
      isValid = false;
    } else {
      print('✅ House field validation passed');
    }

    // Validate Apartment/Road/Area (recommended)
    if (_apartmentController.text.trim().isEmpty) {
      print('❌ Apartment field is empty, setting error');
      setState(() {
        _apartmentError =
            'Apartment/Road/Area is recommended for better tracking';
      });
      isValid = false;
    } else {
      print('✅ Apartment field validation passed');
    }

    // Validate custom address name if "Other" is selected
    if (selectedAddressType == 'Other') {
      if (_customAddressNameController.text.trim().isEmpty) {
        print('❌ Custom address name is empty when Other is selected');
        setState(() {
          _customAddressNameError = 'Please enter a custom address name';
        });
        isValid = false;
      } else {
        print('✅ Custom address name validation passed');
      }
    }

    print('🏁 Validation result: isValid = $isValid');
    return isValid;
  }

  String _formatAddressDetails() {
    List<String> addressParts = [];

    // Add house/flat number
    if (_houseController.text.trim().isNotEmpty) {
      addressParts.add(_houseController.text.trim());
    }

    // Add apartment/road/area
    if (_apartmentController.text.trim().isNotEmpty) {
      addressParts.add(_apartmentController.text.trim());
    }

    return addressParts.join(', ');
  }

  Map<String, String> _parseAddressComponents(String fullAddress) {
    print('🗺️ _parseAddressComponents() called with: "$fullAddress"');

    // Parse the address string to extract components
    final parts = fullAddress.split(', ');
    print('🗺️ Address split into ${parts.length} parts: $parts');

    Map<String, String> components = {};

    // Try to extract common address components
    for (String part in parts) {
      final lowerPart = part.toLowerCase().trim();

      // Extract pincode (6 digits)
      final pincodeMatch = RegExp(r'\b\d{6}\b').firstMatch(part);
      if (pincodeMatch != null) {
        components['pincode'] = pincodeMatch.group(0)!;
      }

      // Extract state
      if (lowerPart.contains('assam') ||
          lowerPart.contains('delhi') ||
          lowerPart.contains('maharashtra') ||
          lowerPart.contains('gujarat') ||
          lowerPart.contains('karnataka') ||
          lowerPart.contains('tamil nadu')) {
        components['state'] = part.trim();
      }

      // Extract country
      if (lowerPart.contains('india')) {
        components['country'] = 'India';
      }

      // Extract city (often the larger administrative area)
      if (lowerPart.contains('delhi') ||
          lowerPart.contains('mumbai') ||
          lowerPart.contains('bangalore') ||
          lowerPart.contains('guwahati') ||
          lowerPart.contains('chennai') ||
          lowerPart.contains('kolkata')) {
        components['city'] = part.trim();
      }
    }

    // Use passed administrative level components if available
    if (widget.addressComponents != null) {
      final addressComponents = widget.addressComponents!;

      if (addressComponents['adminLevel1'] != null &&
          addressComponents['adminLevel1'].toString().isNotEmpty) {
        components['state'] = addressComponents['adminLevel1'].toString();
      }

      // Use administrative level 2 for city
      if (addressComponents['adminLevel2'] != null &&
          addressComponents['adminLevel2'].toString().isNotEmpty) {
        components['city'] = addressComponents['adminLevel2'].toString();
      }

      // Use administrative level 3 for district
      if (addressComponents['adminLevel3'] != null &&
          addressComponents['adminLevel3'].toString().isNotEmpty) {
        components['district'] = addressComponents['adminLevel3'].toString();
      }

      // Use stored locality
      if (addressComponents['locality'] != null &&
          addressComponents['locality'].toString().isNotEmpty) {
        components['locality'] = addressComponents['locality'].toString();
      }

      // Use stored pincode if available
      if (addressComponents['pincode'] != null &&
          addressComponents['pincode'].toString().isNotEmpty) {
        components['pincode'] = addressComponents['pincode'].toString();
      }

      // Use neighborhood for area
      if (addressComponents['neighborhood'] != null &&
          addressComponents['neighborhood'].toString().isNotEmpty) {
        components['area'] = addressComponents['neighborhood'].toString();
      }
    }

    // Set defaults and try to infer other components
    if (parts.isNotEmpty) {
      components['area'] = components['area'] ?? parts.first.trim();
      components['locality'] =
          components['locality'] ??
          (parts.length > 1 ? parts[1].trim() : parts.first.trim());
      components['district'] =
          components['district'] ?? components['city'] ?? '';
    }

    // If pincode is still not available, set default value
    if (components['pincode'] == null || components['pincode']!.isEmpty) {
      components['pincode'] = '000000';
      print('🗺️ No pincode found, using default: 000000');
    }

    print('🗺️ Final parsed components: $components');
    return components;
  }

  Future<void> _saveAddressToLocalStorage(
    Map<String, dynamic> addressData,
  ) async {
    print('💾 _saveAddressToLocalStorage() called');
    print('💾 Data to save: $addressData');

    try {
      final prefs = await SharedPreferences.getInstance();
      print('💾 SharedPreferences instance obtained');

      // Save as address_details object
      final addressDetailsJson = json.encode(addressData);
      print('💾 Encoded JSON: $addressDetailsJson');

      await prefs.setString('address_details', addressDetailsJson);
      print('💾 Saved address_details to SharedPreferences');

      // Save data in format expected by HomeScreen and CustomSliverAppBar
      final addressTitle = addressData['address_name'].toString().toUpperCase();
      final addressSubtitle = [
        addressData['address_line_1']?.toString() ?? '',
        addressData['address_line_2']?.toString() ?? '',
        addressData['area']?.toString() ?? '',
        addressData['city']?.toString() ?? '',
      ].where((item) => item.isNotEmpty).join(', ');

      await prefs.setString('address_title', addressTitle);
      await prefs.setString('address_subtitle', addressSubtitle);
      await prefs.setDouble('latitude', addressData['lat']?.toDouble() ?? 0.0);
      await prefs.setDouble('longitude', addressData['lng']?.toDouble() ?? 0.0);
      await prefs.setString(
        'lat_string',
        addressData['lat']?.toString() ?? '0.0',
      );
      await prefs.setString(
        'lng_string',
        addressData['lng']?.toString() ?? '0.0',
      );

      // Save additional display data
      await prefs.setString(
        'display_area',
        addressData['area']?.toString() ?? '',
      );
      await prefs.setString(
        'display_city',
        addressData['city']?.toString() ?? '',
      );
      await prefs.setString(
        'display_locality',
        addressData['locality']?.toString() ?? '',
      );

      // Also save individual components for easy access
      await prefs.setString('saved_address_name', addressData['address_name']);
      await prefs.setString(
        'saved_address_line_1',
        addressData['address_line_1'],
      );
      await prefs.setString(
        'saved_address_line_2',
        addressData['address_line_2'],
      );
      await prefs.setString('saved_locality', addressData['locality']);
      await prefs.setString('saved_city', addressData['city']);
      await prefs.setString('saved_state', addressData['state']);
      await prefs.setString('saved_pincode', addressData['pincode'].toString());
      print('💾 Saved individual address components');

      print('💾 Saved HomeScreen format data:');
      print('💾 - address_title: $addressTitle');
      print('💾 - address_subtitle: $addressSubtitle');
      print('💾 - coordinates: ${addressData['lat']}, ${addressData['lng']}');

      print('✅ Address details saved to local storage successfully');
    } catch (e) {
      print('❌ Error saving address to local storage: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle Bar
            Container(
              margin: EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.arrow_back,
                      color: theme.colorScheme.onSurface,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              widget.locationName,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.locationAddress,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 1),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Helper Text
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TranslatedText(
                        'A detailed address will help us find the best professional for you',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // House/Flat/Floor Number
                    TranslatedText(
                      'HOUSE / FLAT / FLOOR NO.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _houseController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _houseError != null
                                ? theme.colorScheme.error
                                : theme.colorScheme.outline,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _houseError != null
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: theme.colorScheme.error,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: theme.colorScheme.error,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        errorText: _houseError,
                        errorStyle: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Apartment/Road/Area
                    TranslatedText(
                      'APARTMENT / ROAD / AREA (RECOMMENDED)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _apartmentController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _apartmentError != null
                                ? Colors.red
                                : Colors.grey[300]!,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: _apartmentError != null
                                ? Colors.red
                                : Colors.blue,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.red, width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        errorText: _apartmentError,
                        errorStyle: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),

                    SizedBox(height: 24),

                    // COMMENTED OUT: Directions to Reach
                    /*
                    // Directions to Reach
                    Text(
                      'DIRECTIONS TO REACH (OPTIONAL)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 12),

                    // Voice Recording Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              isRecording = !isRecording;
                            });

                            if (isRecording) {
                              // Simulate recording
                              Future.delayed(Duration(seconds: 3), () {
                                if (mounted) {
                                  setState(() {
                                    isRecording = false;
                                    _directionsController.text =
                                        "Ring the bell on the red gate";
                                  });
                                }
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'NEW',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isRecording
                                        ? 'Recording...'
                                        : 'Tap to record voice directions',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: isRecording
                                          ? Colors.blue
                                          : Colors.black,
                                      fontWeight: isRecording
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.mic,
                                  color: isRecording
                                      ? Colors.blue
                                      : Colors.grey[600],
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 12),

                    // Text Directions
                    TextField(
                      controller: _directionsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'e.g. Ring the bell on the red gate',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.blue),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.all(12),
                        suffixText: '0/200',
                        suffixStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ),

                    SizedBox(height: 24),
                    */

                    // Save As
                    Text(
                      'SAVE AS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 12),

                    // Address Type Selection
                    Wrap(
                      spacing: 12,
                      children: [
                        _buildAddressTypeChip('Home', Icons.home),
                        _buildAddressTypeChip('Work', Icons.work),
                        _buildAddressTypeChip(
                          'Friends and Family',
                          Icons.people,
                        ),
                        _buildAddressTypeChip('Other', Icons.location_on),
                      ],
                    ),

                    SizedBox(height: 16),

                    // Custom Address Name (shown when "Other" is selected)
                    if (selectedAddressType == 'Other') ...[
                      Text(
                        'CUSTOM ADDRESS NAME',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _customAddressNameController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Gym, Restaurant, Friend\'s House',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _customAddressNameError != null
                                  ? Colors.red
                                  : Colors.grey[300]!,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _customAddressNameError != null
                                  ? Colors.red
                                  : Colors.blue,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.red, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          errorText: _customAddressNameError,
                          errorStyle: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                    ],

                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Save Button
            Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () async {
                          print(
                            '🔘 SAVE BUTTON PRESSED - Starting save process',
                          );

                          // Validate fields before saving
                          print('🔍 Starting field validation...');
                          print(
                            '📝 House field: "${_houseController.text.trim()}"',
                          );
                          print(
                            '📝 Apartment field: "${_apartmentController.text.trim()}"',
                          );
                          print(
                            '📝 Selected address type: "$selectedAddressType"',
                          );

                          if (!_validateFields()) {
                            print('❌ Validation failed, stopping save process');
                            return; // Stop if validation fails
                          }
                          print('✅ Field validation passed');

                          print('⏳ Setting loading state to true');
                          setState(() {
                            _isSaving = true;
                          });
                          print('✅ Loading state set');

                          try {
                            print(
                              '📱 Getting user data from SharedPreferences...',
                            );
                            // Get user data from SharedPreferences
                            final prefs = await SharedPreferences.getInstance();
                            final phoneNumber =
                                prefs.getString('phone_number') ?? '';
                            final firstName =
                                prefs.getString('first_name') ?? '';
                            final lastName = prefs.getString('last_name') ?? '';
                            final userName = '$firstName $lastName'.trim();

                            print('📞 Phone number: "$phoneNumber"');
                            print('👤 User name: "$userName"');
                            print(
                              '📍 Location coordinates: lat=${widget.latitude}, lng=${widget.longitude}',
                            );
                            print(
                              '🏠 Location address: "${widget.locationAddress}"',
                            );

                            // Parse address components from the location address
                            print('🗺️ Parsing address components...');
                            final addressParts = _parseAddressComponents(
                              widget.locationAddress,
                            );
                            print(
                              '🗺️ Parsed address components: $addressParts',
                            );

                            // Prepare API request body
                            final addressName = selectedAddressType == 'Other'
                                ? _customAddressNameController.text.trim()
                                : selectedAddressType.toLowerCase();
                            final requestBody = {
                              "address_name": addressName,
                              "phone_number": int.tryParse(phoneNumber) ?? 0,
                              "attendee_name": userName.isNotEmpty
                                  ? userName
                                  : "User",
                              "address_line_1": _houseController.text.trim(),
                              "address_line_2": _apartmentController.text
                                  .trim(),
                              "locality": addressParts['locality'] ?? '',
                              "state": addressParts['state'] ?? '',
                              "country": addressParts['country'] ?? 'India',
                              "district": addressParts['district'] ?? '',
                              "city": addressParts['city'] ?? '',
                              "area": addressParts['area'] ?? '',
                              "pincode":
                                  int.tryParse(
                                    addressParts['pincode'] ?? '000000',
                                  ) ??
                                  0,
                              "lat": widget.latitude,
                              "lng": widget.longitude,
                              "is_billing": true,
                              "is_shipping": true,
                            };

                            print('📦 API Request Body prepared:');
                            print(json.encode(requestBody));

                            // Send POST request to /add-user-address/
                            print(
                              '🚀 Sending POST request to /add-user-address/...',
                            );
                            final response = await ApiService.post(
                              '/add-user-address/',
                              body: requestBody,
                              useBearerToken: true,
                            );

                            print('📥 API Response received:');
                            print(
                              '📊 Response structure: ${response.keys.toList()}',
                            );
                            print('📊 Full response: $response');

                            if (mounted) {
                              print(
                                '✅ Widget still mounted, processing response...',
                              );
                              setState(() {
                                _isSaving = false;
                              });
                              print('✅ Loading state reset to false');

                              // Check if response status is 200
                              print('🔍 Checking response status...');
                              print(
                                '📊 response[\'data\']: ${response['data']}',
                              );
                              if (response['data'] != null) {
                                print(
                                  '📊 response[\'data\'][\'status\']: ${response['data']['status']}',
                                );
                              }

                              if (response['data'] != null &&
                                  response['data']['status'] == 200) {
                                print(
                                  '✅ Success response received! Status 200',
                                );

                                // Save address details to local storage
                                print('💾 Saving address to local storage...');
                                await _saveAddressToLocalStorage(requestBody);
                                print('✅ Address saved to local storage');

                                // Show success message
                                print('🎉 Showing success message...');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: TranslatedText(
                                      'Address saved successfully!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );

                                // Navigate to HomeScreen
                                print('🏠 Navigating to HomeScreen...');
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const HomeScreen(),
                                  ),
                                  (route) => false,
                                );
                                print('✅ Navigation completed');
                              } else {
                                print('❌ API Error: Status is not 200');
                                print('📊 Response data: ${response['data']}');

                                // Show error message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: TranslatedText(
                                      'Failed to save address. Please try again.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } else {
                              print(
                                '❌ Widget not mounted, skipping response processing',
                              );
                            }
                          } catch (e) {
                            print('💥 Exception caught during save process:');
                            print('💥 Exception type: ${e.runtimeType}');
                            print('💥 Exception message: $e');
                            print('💥 Stack trace: ${StackTrace.current}');

                            if (mounted) {
                              print(
                                '🔄 Widget mounted, resetting loading state and showing error',
                              );
                              setState(() {
                                _isSaving = false;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Network error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } else {
                              print(
                                '❌ Widget not mounted, skipping error handling',
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            SizedBox(width: 12),
                            TranslatedText(
                              'SAVING...',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : const TranslatedText(
                          'SAVE ADDRESS DETAILS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressTypeChip(String label, IconData icon) {
    final isSelected = selectedAddressType == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedAddressType = label;
          // Clear custom address name error when changing address type
          _customAddressNameError = null;
          // Clear custom address name if switching away from Other
          if (label != 'Other') {
            _customAddressNameController.clear();
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
            SizedBox(width: 8),
            TranslatedText(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
