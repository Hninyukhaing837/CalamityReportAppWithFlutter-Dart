import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlatformMap extends StatelessWidget {
  final Position? position;

  const PlatformMap({super.key, this.position});

  @override
  Widget build(BuildContext context) {
    if (position == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 32, color: Colors.grey.shade400),
            const SizedBox(height: 6),
            Text(
              '位置情報を読み込み中',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    if (kIsWeb) {
      // Web version - show placeholder with coordinates
      return Container(
        color: Colors.blue.shade50,
        child: Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate responsive sizes
              final iconSize = (constraints.maxHeight * 0.25).clamp(32.0, 48.0);
              final titleSize = (constraints.maxHeight * 0.08).clamp(13.0, 16.0);
              final coordSize = (constraints.maxHeight * 0.055).clamp(9.0, 11.0);
              final badgeSize = (constraints.maxHeight * 0.05).clamp(8.0, 10.0);
              
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map, 
                        size: iconSize, 
                        color: Colors.blue.shade300,
                      ),
                      SizedBox(height: constraints.maxHeight * 0.05),
                      Text(
                        'マップ (Web版)',
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      SizedBox(height: constraints.maxHeight * 0.025),
                      Text(
                        '緯度: ${position!.latitude.toStringAsFixed(4)}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: coordSize,
                        ),
                      ),
                      Text(
                        '経度: ${position!.longitude.toStringAsFixed(4)}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: coordSize,
                        ),
                      ),
                      SizedBox(height: constraints.maxHeight * 0.05),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth * 0.03,
                          vertical: constraints.maxHeight * 0.02,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'モバイルで完全な地図表示',
                          style: TextStyle(
                            fontSize: badgeSize,
                            color: Colors.blue.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // Mobile version - real Google Map
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(position!.latitude, position!.longitude),
        zoom: 12,
      ),
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      mapType: MapType.normal,
      markers: {
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(position!.latitude, position!.longitude),
          infoWindow: const InfoWindow(title: '現在地'),
        ),
      },
    );
  }
}