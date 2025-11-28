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
  GoogleMapController? _mapController;
  BitmapDescriptor? _customMarkerIcon;
  Marker? _currentLocationMarker;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMap();
    });
  }

  Future<void> _initializeMap() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    await locationProvider.checkAndRequestPermissions();
    await _loadCustomMarkerIcon();
    await _loadPinsFromJson();
    await _loadMediaLocations();
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    locationProvider.stopTracking();
    super.dispose();
  }

  Future<void> _loadPinsFromJson() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/pins.json');
      final List<dynamic> pinData = json.decode(jsonString);

      final newMarkers = pinData.map((pin) {
        return Marker(
          markerId: MarkerId(pin['id'].toString()),
          position: LatLng(pin['latitude'], pin['longitude']),
          infoWindow: InfoWindow(
            title: pin['name'],
            snippet: pin['description'],
          ),
          icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
        );
      }).toSet();

      if (mounted) {
        setState(() {
          _markers.addAll(newMarkers);
        });
      }
    } catch (e) {
      print('Error loading pins: $e');
    }
  }

  Future<void> _loadCustomMarkerIcon() async {
    try {
      try {
         _customMarkerIcon = await BitmapDescriptor.fromAssetImage(
          const ImageConfiguration(size: Size(48, 48)),
          'assets/custom_marker.png',
        );
      } catch(e) {
        print("Custom marker not found, using default: $e");
        _customMarkerIcon = BitmapDescriptor.defaultMarker; 
      }
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        
        setState(() {
          _markers.removeWhere((marker) => marker.markerId.value == 'current_location');
          
          _currentLocationMarker = Marker(
            markerId: const MarkerId('current_location'),
            position: LatLng(latitude, longitude),
            infoWindow: const InfoWindow(title: '現在地'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          );
          _markers.add(_currentLocationMarker!);
        });

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(latitude, longitude), 15),
        );
      });
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
      final newMarkers = <Marker>{};
      
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
          newMarkers.add(marker);
        }
      }
      
      if (mounted) {
        setState(() {
          _markers.addAll(newMarkers);
        });
      }
    } catch (e) {
      print('Error loading media locations: $e');
    }
  }

  Widget buildMap(LocationProvider locationProvider) {
    if (kIsWeb || Platform.isWindows) {
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
      if (locationProvider.currentLocation != null && _isInitialized) {
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

              // CORRECTED LOGIC: Show card ONLY if location exists
              if (locationProvider.currentLocation != null)
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
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Buttons inside the conditional block if you want them hidden too, 
                      // BUT usually buttons should remain visible to fetch location.
                      // If buttons should remain visible, they must be OUTSIDE this if block.
                      // Moving buttons OUTSIDE for usability.
                    ],
                  ),
                ),
              
              // Buttons are now always visible so user can retry fetching location
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await locationProvider.getCurrentLocation();
                        if (mounted && locationProvider.currentLocation != null) {
                          _updateCurrentLocationMarker(locationProvider);
                        }
                      },
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
              ),
              
              const SizedBox(height: 16),

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
