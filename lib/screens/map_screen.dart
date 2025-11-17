import 'dart:convert';
import 'dart:io' show Platform; // Import for Platform
import 'package:flutter/foundation.dart'; // Import for kIsWeb
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Import Google Maps
import 'package:flutter/services.dart' show rootBundle; // Import for loading JSON
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Set<Marker> _markers = {}; // Define _markers to store map markers
  late GoogleMapController _mapController;
  BitmapDescriptor? _customMarkerIcon; // For custom marker icons
  Marker? _currentLocationMarker; // Marker for current location

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      locationProvider.checkAndRequestPermissions();
    });
    _loadPinsFromJson(); // Load pins when the screen initializes
    _loadCustomMarkerIcon(); // Load custom marker icon
    _loadMediaLocations();
  }

  @override
  void dispose() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    locationProvider.stopTracking(); // Stop location tracking when the screen is disposed
    super.dispose();
  }

  // Load pins from the local JSON file
  Future<void> _loadPinsFromJson() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/pins.json');
      final List<dynamic> pinData = json.decode(jsonString);

      setState(() {
        _markers.addAll(pinData.map((pin) {
          return Marker(
            markerId: MarkerId(pin['id'].toString()),
            position: LatLng(pin['latitude'], pin['longitude']),
            infoWindow: InfoWindow(
              title: pin['name'],
              snippet: pin['description'],
            ),
            icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker, // Use custom marker icon
          );
        }));
      });
    } catch (e) {
      print('Error loading pins: $e');
    }
  }

  // Load custom marker icon
  Future<void> _loadCustomMarkerIcon() async {
    _customMarkerIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/custom_marker.png', // Path to your custom marker icon
    );
  }

  // Update current location marker
  void _updateCurrentLocationMarker(LocationProvider locationProvider) {
    if (locationProvider.currentLocation != null &&
        locationProvider.currentLocation!.latitude != null &&
        locationProvider.currentLocation!.longitude != null) {
      final double latitude = locationProvider.currentLocation!.latitude!;
      final double longitude = locationProvider.currentLocation!.longitude!;

      setState(() {
        _currentLocationMarker = Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(latitude, longitude),
          infoWindow: const InfoWindow(title: '現在地'), // "Current Location"
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue), // Blue marker for current location
        );
        _markers.add(_currentLocationMarker!);
      });

      // Move the map camera to the current location
      _mapController.animateCamera(CameraUpdate.newLatLng(LatLng(latitude, longitude)));
    } else {
      print('Error: Current location is null or incomplete.');
    }
  }

  // Share current location
  void _shareCurrentLocation(LocationProvider locationProvider) {
    if (locationProvider.currentLocation != null &&
        locationProvider.currentLocation!.latitude != null &&
        locationProvider.currentLocation!.longitude != null) {
      final latitude = locationProvider.currentLocation!.latitude!;
      final longitude = locationProvider.currentLocation!.longitude!;
      final locationUrl = 'https://www.google.com/maps?q=$latitude,$longitude';

      // Share location URL (you can use a sharing plugin like `share_plus`)
      print('Share this location: $locationUrl');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('現在地を共有しました: $locationUrl')), // "Shared current location"
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('現在地が利用できません')), // "Current location not available"
      );
    }
  }

  // Load media locations from Firestore
  Future<void> _loadMediaLocations() async {
    try {
      final mediaDocs = await FirebaseFirestore.instance.collection('media').get();
      for (var doc in mediaDocs.docs) {
        final data = doc.data();
        final location = data['location'];
        if (location != null) {
          final marker = Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(location['latitude'], location['longitude']),
            infoWindow: InfoWindow(
              title: data['incidentCase'] ?? 'メディア',
              snippet: data['type'],
            ),
          );
          setState(() {
            _markers.add(marker);
          });
        }
      }
    } catch (e) {
      print('Error loading media locations: $e');
    }
  }

  Widget buildMap(LocationProvider locationProvider) {
    if (kIsWeb) {
      // Handle web platform
      return Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'ここにGoogleマップが表示されます', // "The map will be displayed here"
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    } else if (Platform.isWindows) {
      // Handle Windows platform
      return Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'ここにGoogleマップが表示されます', // "The map will be displayed here"
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    } else {
      // Handle mobile platforms (Android/iOS)
      _updateCurrentLocationMarker(locationProvider); // Update current location marker
      return GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(35.6895, 139.6917), // Default to Tokyo
          zoom: 10,
        ),
        markers: _markers, // Use the markers on the map
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('地図と位置情報'), // "Map & Location"
      ),
      body: Consumer<LocationProvider>(
        builder: (context, locationProvider, child) {
          return Column(
            children: [
              // Error message banner
              if (locationProvider.errorMessage != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.red.shade100,
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          locationProvider.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => locationProvider.clearError(),
                      ),
                    ],
                  ),
                ),

              // Location info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '現在地', // "Current Location"
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (locationProvider.currentLocation != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '緯度: ${locationProvider.currentLocation!.latitude?.toStringAsFixed(6)}', // "Latitude"
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '経度: ${locationProvider.currentLocation!.longitude?.toStringAsFixed(6)}', // "Longitude"
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '精度: ${locationProvider.currentLocation!.accuracy?.toStringAsFixed(2)} m', // "Accuracy"
                                  ),
                                ],
                              )
                            else
                              const Text('位置情報が利用できません'), // "No location data available"
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => locationProvider.getCurrentLocation(),
                          icon: const Icon(Icons.my_location),
                          label: const Text('現在地を取得'), // "Get Location"
                        ),
                        ElevatedButton.icon(
                          onPressed: locationProvider.isTracking
                              ? () => locationProvider.stopTracking()
                              : () => locationProvider.startTracking(),
                          icon: Icon(
                            locationProvider.isTracking
                                ? Icons.stop
                                : Icons.play_arrow,
                          ),
                          label: Text(
                            locationProvider.isTracking
                                ? '追跡を停止' // "Stop Tracking"
                                : '追跡を開始', // "Start Tracking"
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: locationProvider.isTracking
                                ? Colors.red
                                : Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _shareCurrentLocation(locationProvider),
                          icon: const Icon(Icons.share),
                          label: const Text('現在地を共有'), // "Share Location"
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Map placeholder or actual map
              Expanded(
                child: buildMap(locationProvider),
              ),
            ],
          );
        },
      ),
    );
  }
}