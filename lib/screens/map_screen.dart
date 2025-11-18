import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Set<Marker> _markers = {};
  late GoogleMapController _mapController;
  BitmapDescriptor? _customMarkerIcon;
  Marker? _currentLocationMarker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      locationProvider.checkAndRequestPermissions();
    });
    _loadPinsFromJson();
    _loadCustomMarkerIcon();
    _loadMediaLocations();
  }

  @override
  void dispose() {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    locationProvider.stopTracking();
    super.dispose();
  }

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
            icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
          );
        }));
      });
    } catch (e) {
      print('Error loading pins: $e');
    }
  }

  Future<void> _loadCustomMarkerIcon() async {
    try {
      _customMarkerIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/custom_marker.png',
      );
    } catch (e) {
      print('Error loading custom marker: $e');
    }
  }

  void _updateCurrentLocationMarker(LocationProvider locationProvider) {
    if (locationProvider.currentLocation != null &&
        locationProvider.currentLocation!.latitude != null &&
        locationProvider.currentLocation!.longitude != null) {
      final double latitude = locationProvider.currentLocation!.latitude!;
      final double longitude = locationProvider.currentLocation!.longitude!;

      setState(() {
        // Remove old current location marker if exists
        _markers.removeWhere((marker) => marker.markerId.value == 'current_location');
        
        _currentLocationMarker = Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(latitude, longitude),
          infoWindow: const InfoWindow(title: '現在地'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );
        _markers.add(_currentLocationMarker!);
      });

      // Move the map camera to the current location
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(latitude, longitude), 15),
      );
    } else {
      print('Error: Current location is null or incomplete.');
    }
  }

  void _shareCurrentLocation(LocationProvider locationProvider) {
    if (locationProvider.currentLocation != null &&
        locationProvider.currentLocation!.latitude != null &&
        locationProvider.currentLocation!.longitude != null) {
      final latitude = locationProvider.currentLocation!.latitude!;
      final longitude = locationProvider.currentLocation!.longitude!;
      final locationUrl = 'https://www.google.com/maps?q=$latitude,$longitude';

      print('Share this location: $locationUrl');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('現在地を共有しました: $locationUrl')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('現在地が利用できません')),
      );
    }
  }

  Future<void> _loadMediaLocations() async {
    try {
      final mediaDocs = await FirebaseFirestore.instance.collection('media').get();
      for (var doc in mediaDocs.docs) {
        final data = doc.data();
        final latitude = data['latitude'];
        final longitude = data['longitude'];
        
        if (latitude != null && longitude != null) {
          final marker = Marker(
            markerId: MarkerId(doc.id),
            position: LatLng(latitude, longitude),
            infoWindow: InfoWindow(
              title: data['incidentCase'] ?? 'メディア',
              snippet: data['type'],
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              data['type'] == 'image' 
                ? BitmapDescriptor.hueGreen 
                : BitmapDescriptor.hueRed,
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
    if (kIsWeb || Platform.isWindows) {
      // Handle web and Windows platforms with info message and location display
      return Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Icon(Icons.info_outline, size: 64, color: Colors.blue.shade700),
                const SizedBox(height: 16),
                Text(
                  'マップ表示は${kIsWeb ? "Web" : "Windows"}ではサポートされていません',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'モバイルアプリでご利用ください',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Show location info if available
                if (locationProvider.currentLocation != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, 
                              size: 20, 
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '現在の位置情報:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '緯度: ${locationProvider.currentLocation!.latitude?.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '経度: ${locationProvider.currentLocation!.longitude?.toStringAsFixed(6)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (locationProvider.currentLocation!.accuracy != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '精度: ${locationProvider.currentLocation!.accuracy?.toStringAsFixed(2)} m',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '位置情報を取得するには「現在地を取得」ボタンを押してください',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    } else {
      // Handle mobile platforms (Android/iOS)
      if (locationProvider.currentLocation != null) {
        _updateCurrentLocationMarker(locationProvider);
      }
      return GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(35.6895, 139.6917), // Default to Tokyo
          zoom: 10,
        ),
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        mapType: MapType.normal,
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
        title: const Text('地図と位置情報'),
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

              // Location info card
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
                              '現在地',
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
                                    '緯度: ${locationProvider.currentLocation!.latitude?.toStringAsFixed(6)}',
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '経度: ${locationProvider.currentLocation!.longitude?.toStringAsFixed(6)}',
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '精度: ${locationProvider.currentLocation!.accuracy?.toStringAsFixed(2)} m',
                                  ),
                                ],
                              )
                            else
                              const Text('位置情報が利用できません'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action buttons
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => locationProvider.getCurrentLocation(),
                          icon: const Icon(Icons.my_location),
                          label: const Text('現在地を取得'),
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
                                ? '追跡を停止'
                                : '追跡を開始',
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
                          label: const Text('現在地を共有'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Map or placeholder
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