import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'dart:convert';

/// Singleton service to manage Google Maps instances efficiently
/// This reduces API charges by reusing map controllers and minimizing reloads
class GoogleMapsService {
  static final GoogleMapsService _instance = GoogleMapsService._internal();
  factory GoogleMapsService() => _instance;
  GoogleMapsService._internal();

  // Shared map controller
  GoogleMapController? _sharedController;
  Completer<GoogleMapController>? _controllerCompleter;

  // Performance optimizations
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(28.6129, 77.2295), // Delhi, India
    zoom: 15.0,
    bearing: 0.0,
    tilt: 0.0, // Disable 3D tilt for performance
  );

  // Optimized map style for performance
  static const String _optimizedMapStyle = '''[
    {
      "featureType": "poi",
      "elementType": "labels",
      "stylers": [{"visibility": "off"}]
    },
    {
      "featureType": "transit",
      "elementType": "labels",
      "stylers": [{"visibility": "off"}]
    }
  ]''';

  /// Get shared map controller with optimizations
  Future<GoogleMapController> getMapController() async {
    if (_sharedController != null) {
      return _sharedController!;
    }

    if (_controllerCompleter == null) {
      _controllerCompleter = Completer<GoogleMapController>();
    }

    return _controllerCompleter!.future;
  }

  /// Initialize shared map controller
  void onMapCreated(GoogleMapController controller) {
    if (_sharedController == null) {
      _sharedController = controller;
      _applyOptimizations();

      if (_controllerCompleter != null && !_controllerCompleter!.isCompleted) {
        _controllerCompleter!.complete(controller);
      }
    }
  }

  /// Apply performance optimizations to the map
  void _applyOptimizations() {
    if (_sharedController != null) {
      // Apply optimized map style
      _sharedController!.setMapStyle(_optimizedMapStyle);
    }
  }

  /// Create optimized GoogleMap widget
  Widget createOptimizedMap({
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    Set<Polygon>? polygons,
    Set<Circle>? circles,
    CameraPosition? initialCameraPosition,
    Function(CameraPosition)? onCameraMove,
    Function(LatLng)? onTap,

    bool myLocationEnabled = true,
    bool trafficEnabled = false,
    MapType mapType = MapType.normal,
  }) {
    return GoogleMap(
      onMapCreated: onMapCreated,
      initialCameraPosition: initialCameraPosition ?? _defaultPosition,
      markers: markers ?? {},
      polylines: polylines ?? {},
      polygons: polygons ?? {},
      circles: circles ?? {},

      // Performance optimizations - disable 3D and heavy features
      mapType: mapType,
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: false, // Use custom button for better control
      zoomControlsEnabled: false, // Use custom controls
      compassEnabled: false, // Reduce rendering load
      rotateGesturesEnabled: true,
      scrollGesturesEnabled: true,
      tiltGesturesEnabled: false, // Disable 3D tilt gestures
      zoomGesturesEnabled: true,

      // Disable heavy features to reduce API usage
      buildingsEnabled: false, // Disable 3D buildings
      indoorViewEnabled: false, // Disable indoor maps
      trafficEnabled: trafficEnabled, // Usually false for performance
      mapToolbarEnabled: false,
      liteModeEnabled: false, // Keep false for full interaction
      // Limit zoom to reduce tile loading
      minMaxZoomPreference: const MinMaxZoomPreference(8.0, 20.0),

      // Callbacks
      onCameraMove: onCameraMove,
      onTap: onTap,

      // Optimize camera bounds to reduce unnecessary tile loads
      cameraTargetBounds: CameraTargetBounds.unbounded,
    );
  }

  /// Animate camera to specific position efficiently
  Future<void> animateCamera({
    required LatLng target,
    double zoom = 15.0,
    double bearing = 0.0,
    double tilt = 0.0, // Always 0 for 2D mode
  }) async {
    final controller = await getMapController();
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: zoom,
          bearing: bearing,
          tilt: tilt,
        ),
      ),
    );
  }

  /// Move camera without animation for better performance
  Future<void> moveCamera({
    required LatLng target,
    double zoom = 15.0,
    double bearing = 0.0,
  }) async {
    final controller = await getMapController();
    await controller.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: zoom,
          bearing: bearing,
          tilt: 0.0, // Always 0 for 2D mode
        ),
      ),
    );
  }

  /// Get current zoom level
  Future<double> getCurrentZoom() async {
    final controller = await getMapController();
    return await controller.getZoomLevel();
  }

  /// Dispose resources when no longer needed
  void dispose() {
    _sharedController?.dispose();
    _sharedController = null;
    _controllerCompleter = null;
  }

  /// Reset service (useful for testing or when switching contexts)
  void reset() {
    dispose();
  }

  /// Check if map is ready
  bool get isMapReady => _sharedController != null;

  /// Get default camera position
  static CameraPosition get defaultPosition => _defaultPosition;
}

/// Mixin to easily integrate optimized Google Maps in widgets
mixin OptimizedGoogleMapsMixin<T extends StatefulWidget> on State<T> {
  final GoogleMapsService _mapsService = GoogleMapsService();

  /// Create optimized map widget
  Widget buildOptimizedMap({
    Set<Marker>? markers,
    Set<Polyline>? polylines,
    Set<Polygon>? polygons,
    Set<Circle>? circles,
    CameraPosition? initialCameraPosition,
    Function(CameraPosition)? onCameraMove,
    Function(LatLng)? onTap,
    bool myLocationEnabled = true,
    bool trafficEnabled = false,
    MapType mapType = MapType.normal,
  }) {
    return _mapsService.createOptimizedMap(
      markers: markers,
      polylines: polylines,
      polygons: polygons,
      circles: circles,
      initialCameraPosition: initialCameraPosition,
      onCameraMove: onCameraMove,
      onTap: onTap,
      myLocationEnabled: myLocationEnabled,
      trafficEnabled: trafficEnabled,
      mapType: mapType,
    );
  }

  /// Animate to location
  Future<void> animateToLocation(LatLng location, {double zoom = 15.0}) {
    return _mapsService.animateCamera(target: location, zoom: zoom);
  }

  /// Move to location without animation
  Future<void> moveToLocation(LatLng location, {double zoom = 15.0}) {
    return _mapsService.moveCamera(target: location, zoom: zoom);
  }

  /// Get current zoom level
  Future<double> getCurrentZoom() {
    return _mapsService.getCurrentZoom();
  }

  /// Check if map is ready
  bool get isMapReady => _mapsService.isMapReady;
}
