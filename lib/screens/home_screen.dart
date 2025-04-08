import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/flutter_map_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Flutter Map Service
  final FlutterMapService _mapService = FlutterMapService();
  
  // Map Controller
  final MapController _mapController = MapController();
  
  // State Variables
  bool _isMapReady = false;
  bool _isLoadingLocation = false;
  
  // Music Markers List
  final List<String> _musicMarkers = [];
  
  // Define a constant for the country zoom level
  static const double COUNTRY_ZOOM_LEVEL = 6.0; // Country zoom level
  
  @override
  void initState() {
    super.initState();
    
    // Initialize the map
    _initMapService();
    
    // Get location
    _initLocationService();
  }
  
  void _initMapService() {
    _mapService.initMap(_mapController);
  }
  
  Future<void> _initLocationService() async {
    try {
      setState(() {
        _isLoadingLocation = true;
      });
      
      await _mapService.getCurrentLocation();
      
      if (_isMapReady) {
        await _mapService.moveToCurrentLocation();
      }
    } catch (e) {
      print("📍 Location error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _mapService.dispose();
    super.dispose();
  }
  
  // When the map is ready
  void _onMapReady() {
    print("DEBUG: The map is ready");
    setState(() {
      _isMapReady = true;
    });
    
    _goToCurrentLocation();
  }
  
  // Go to current location
  Future<void> _goToCurrentLocation() async {
    if (!_isMapReady) return;
    
    setState(() {
      _isLoadingLocation = true;
    });
    
    try {
      await _mapService.moveToCurrentLocation();
    } catch (e) {
        print('Error moving to current location: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot access your location')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _goToCurrentLocation,
            tooltip: 'Refresh map',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Flutter Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _mapService.getDefaultLocation(),
              zoom: COUNTRY_ZOOM_LEVEL, // Use country zoom level
              onMapReady: _onMapReady,
            ),
            children: [
              // Map layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.soundscape_app',
              ),
              // Marker layer
              MarkerLayer(
                markers: _mapService.markers,
              ),
            ],
          ),
          
          // Location loading indicator
          if (_isLoadingLocation)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('定位中...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          
          // Add map zoom control buttons
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom in button
                _buildZoomButton(
                  icon: Icons.add,
                  onPressed: () {
                    // Get current zoom level and limit maximum value
                    double currentZoom = _mapController.zoom;
                    double newZoom = currentZoom + 1;
                    // Limit maximum zoom level to 17
                    if (newZoom > 17) newZoom = 17;
                    
                    _mapController.move(
                      _mapController.center,
                      newZoom
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Zoom out button
                _buildZoomButton(
                  icon: Icons.remove,
                  onPressed: () {
                    // Get current zoom level and limit minimum value
                    double currentZoom = _mapController.zoom;
                    double newZoom = currentZoom - 1;
                    // Limit minimum zoom level to 3 (continental level)
                    if (newZoom < 3) newZoom = 3;
                    
                    _mapController.move(
                      _mapController.center,
                      newZoom
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Bottom control bar - Removed layer button
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Removed layer button, now only two buttons
                    _buildMapButton(
                      icon: Icons.music_note,
                      label: 'Add Music',
                      onTap: _showAddMusicDialog,
                    ),
                    _buildMapButton(
                      icon: Icons.my_location,
                      label: 'My Location',
                      onTap: _goToCurrentLocation,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Build map button
  Widget _buildMapButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
  
  // Show add music dialog
  void _showAddMusicDialog() {
    final TextEditingController titleController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Music Marker'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Music Title',
                hintText: 'Enter music title',
                prefixIcon: Icon(Icons.music_note),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            const Text(
              'This will add a music marker at your current location.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final title = titleController.text.trim();
              if (title.isNotEmpty) {
                // Create unique ID
                final id = DateTime.now().millisecondsSinceEpoch.toString();
                
                // Add marker to map
                _mapService.addMusicMarker(
                  id: id,
                  title: title,
                  onTap: () {
                    _showMusicDetails(title);
                  },
                );
                
                // Update list
                setState(() {
                  _musicMarkers.add('$title (Current Location)');
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Music marker "$title" added')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
  
  // Show music details
  void _showMusicDetails(String title) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.album, color: Colors.purple),
                SizedBox(width: 10),
                Text('Local artist\'s music'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 10),
                Text(
                  'Added on ${DateTime.now().toString().substring(0, 16)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Play'),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Playing music: $title')),
                    );
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share feature coming soon')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Add helper method to build zoom button
  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 2,
            spreadRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon),
        padding: EdgeInsets.zero,
        iconSize: 20,
        onPressed: onPressed,
        tooltip: icon == Icons.add ? 'Zoom in' : 'Zoom out',
      ),
    );
  }
}