import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'dart:developer' as developer;

// Flutter Map Map Service
class FlutterMapService {
  // Singleton Pattern
  static final FlutterMapService _instance = FlutterMapService._internal();
  factory FlutterMapService() => _instance;
  FlutterMapService._internal();
  
  // Default location: London (latitude 51.5074, longitude -0.1278)
  final LatLng _defaultLocation = const LatLng(51.5074, -0.1278);
  
  // Location Service
  final Location _locationService = Location();
  
  // Current Location
  LocationData? _currentLocation;
  LatLng? get currentLatLng => _currentLocation != null 
      ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!) 
      : _defaultLocation;
  
  // Map Controller
  MapController? _mapController;
  
  // Marker Collection
  final List<Marker> _markers = [];
  List<Marker> get markers => _markers;
  
  // Add constant at the top of the class
  static const double COUNTRY_ZOOM_LEVEL = 6.0; // Country zoom level
  
  // Initialize Map
  void initMap(MapController controller) {
    _mapController = controller;
    _checkLocationPermission();
  }
  
  // Check location permission
  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled;
    PermissionStatus permissionStatus;
    
    try {
      // Check if location service is enabled
      serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) {
          developer.log('Location services are disabled', name: 'FlutterMapService');
          return false;
        }
      }
      
      // Check location permission
      permissionStatus = await _locationService.hasPermission();
      if (permissionStatus == PermissionStatus.denied) {
        permissionStatus = await _locationService.requestPermission();
        if (permissionStatus != PermissionStatus.granted) {
          developer.log('Location permissions are denied', name: 'FlutterMapService');
          return false;
        }
      }
      
      // Get current location
      await getCurrentLocation();
      return true;
    } catch (e) {
      developer.log('Error checking location permission: $e', name: 'FlutterMapService');
      return false;
    }
  }
  
  // Get current location
  Future<void> getCurrentLocation() async {
    try {
      // Add timeout handling
      final locationData = await _locationService.getLocation()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        print("DEBUG: Get location timeout");
        return LocationData.fromMap({
          'latitude': _defaultLocation.latitude,
          'longitude': _defaultLocation.longitude,
          'accuracy': 0.0,
          'altitude': 0.0,
          'speed': 0.0,
          'speed_accuracy': 0.0,
          'heading': 0.0,
          'time': DateTime.now().millisecondsSinceEpoch.toDouble(),
        });
      });
      
      _currentLocation = locationData;
      developer.log('Current location: ${locationData.latitude}, ${locationData.longitude}', 
                  name: 'FlutterMapService');
    } catch (e) {
      print("DEBUG: Error getting location: $e");
      developer.log('Error getting location: $e', name: 'FlutterMapService');
    }
  }
  
  // 移动到当前位置
  Future<void> moveToCurrentLocation() async {
    try {
      print("DEBUG: moveToCurrentLocation started");
      print("DEBUG: Trying to get current location");
      await getCurrentLocation();
      print("DEBUG: Current location retrieved");
      
      if (_mapController == null) {
        print("DEBUG: Map controller is null");
        return;
      }
      
      print("DEBUG: Preparing to move map");
      if (_currentLocation != null) {
        print("DEBUG: Using current location: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}");
        _mapController!.move(
          LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
          COUNTRY_ZOOM_LEVEL // Use country zoom level
        );
      } else {
        print("DEBUG: Using default location: ${_defaultLocation.latitude}, ${_defaultLocation.longitude}");
        _mapController!.move(
          _defaultLocation, 
          COUNTRY_ZOOM_LEVEL // Use country zoom level
        );
      }
      print("DEBUG: Map moved");
    } catch (e) {
      print("DEBUG: Error moving to current location: $e");
      developer.log('Error moving to current location: $e', name: 'FlutterMapService');
    }
  }
  
  // Add marker
  void addMarker({
    required String id,
    required LatLng position,
    required String title,
    String? snippet,
    VoidCallback? onTap,
    Widget? icon,
  }) {
    final marker = Marker(
      point: position,
      width: 80,
      height: 80,
      builder: (context) => icon ?? 
        GestureDetector(
          onTap: onTap,
          child: Column(
            children: [
              Icon(Icons.location_on, color: Colors.red, size: 30),
              Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
    );
    
    _markers.add(marker);
  }
  
  // Add music marker
  void addMusicMarker({
    required String id,
    required String title,
    LatLng? position,
    VoidCallback? onTap,
  }) {
    final LatLng markerPosition = position ?? (currentLatLng ?? _defaultLocation);
    
    addMarker(
      id: 'music_$id',
      position: markerPosition,
      title: title,
      onTap: onTap,
      icon: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Icon(Icons.music_note, color: Colors.purple, size: 30),
            Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
    
    developer.log('Added music marker: $title at ${markerPosition.latitude}, ${markerPosition.longitude}', 
                 name: 'FlutterMapService');
  }
  
  // Remove marker
  void removeMarker(String id) {
    _markers.removeWhere((marker) => marker.key.toString().contains(id));
  }
  
  // Clear all markers
  void clearMarkers() {
    _markers.clear();
  }
  
  // Get default location
  LatLng getDefaultLocation() {
    return _defaultLocation;
  }
  
  // Calculate distance between two points (meters)
  double calculateDistance(LatLng start, LatLng end) {
    final Distance distance = const Distance();
    return distance.as(LengthUnit.Meter, start, end);
  }
  
  // Dispose resources
  void dispose() {
    // Flutter Map has no resources to dispose
  }
}