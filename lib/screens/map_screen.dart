import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Import Google Maps
import 'package:provider/provider.dart';
import '../providers/location_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Set<Marker> _markers = {}; // Define _markers to store map markers

  @override
  void initState() {
    super.initState();
    _loadPinsFromJson(); // Load pins when the screen initializes

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationProvider = Provider.of<LocationProvider>(context, listen: false);
      locationProvider.checkAndRequestPermissions();
    });
  }

  // Load pins from the local JSON file
  Future<void> _loadPinsFromJson() async {
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
        );
      }));
    });
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
                      ],
                    ),
                  ],
                ),
              ),

              // Map placeholder
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(35.6895, 139.6917), // Default to Tokyo
                    zoom: 10,
                  ),
                  markers: _markers, // Use the markers on the map
                  onMapCreated: (GoogleMapController controller) {
                    // Map is ready
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

//Location permission handling
//Current location retrieval
//Display of latitude and longitude
//Location refresh button
//Share location button (placeholder functionality)

//The map screen includes:
//Real-time location tracking
//Google Maps integration
//Location marker display
//Error handling
//Permission management
//Location updates button