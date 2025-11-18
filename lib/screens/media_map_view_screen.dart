import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/media_service.dart';
import 'media_preview_screen.dart';

class MediaMapViewScreen extends StatefulWidget {
  final String? mediaId;
  final double? latitude;
  final double? longitude;
  final String? type;
  final String? downloadUrl;
  final String? incidentCase;

  const MediaMapViewScreen({
    super.key,
    this.mediaId,
    this.latitude,
    this.longitude,
    this.type,
    this.downloadUrl,
    this.incidentCase,
  });

  @override
  State<MediaMapViewScreen> createState() => _MediaMapViewScreenState();
}

class _MediaMapViewScreenState extends State<MediaMapViewScreen> {
  final MediaService _mediaService = MediaService();
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Map<String, DocumentSnapshot> _mediaDocuments = {};
  bool _isLoading = true;
  String? _selectedMediaId;

  @override
  void initState() {
    super.initState();
    _loadMediaMarkers();
  }

  Future<void> _loadMediaMarkers() async {
    try {
      setState(() => _isLoading = true);

      // If specific media provided, show only that
      if (widget.mediaId != null && widget.latitude != null && widget.longitude != null) {
        _addSingleMarker(
          widget.mediaId!,
          widget.latitude!,
          widget.longitude!,
          widget.type ?? 'image',
        );
        setState(() => _isLoading = false);
        return;
      }

      // Otherwise, load all media with location
      final snapshot = await _mediaService.getMediaWithLocation().first;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;
        final type = data['type'] as String;

        if (lat != null && lng != null) {
          _mediaDocuments[doc.id] = doc;
          _addSingleMarker(doc.id, lat, lng, type);
        }
      }

      setState(() => _isLoading = false);

      // Move camera to show all markers
      if (_markers.isNotEmpty && _mapController != null) {
        _fitMarkersInView();
      }
    } catch (e) {
      print('❌ マーカー読み込みエラー: $e');
      setState(() => _isLoading = false);
    }
  }

  void _addSingleMarker(String mediaId, double lat, double lng, String type) {
    _markers.add(
      Marker(
        markerId: MarkerId(mediaId),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          type == 'image'
              ? BitmapDescriptor.hueGreen
              : BitmapDescriptor.hueRed,
        ),
        infoWindow: InfoWindow(
          title: type == 'image' ? '📷 画像' : '🎥 ビデオ',
          snippet: 'タップして詳細を表示',
          onTap: () => _showMediaPreview(mediaId),
        ),
        onTap: () {
          setState(() => _selectedMediaId = mediaId);
          _showMediaBottomSheet(mediaId);
        },
      ),
    );
  }

  void _fitMarkersInView() {
    if (_markers.isEmpty || _mapController == null) return;

    double minLat = _markers.first.position.latitude;
    double maxLat = _markers.first.position.latitude;
    double minLng = _markers.first.position.longitude;
    double maxLng = _markers.first.position.longitude;

    for (var marker in _markers) {
      if (marker.position.latitude < minLat) minLat = marker.position.latitude;
      if (marker.position.latitude > maxLat) maxLat = marker.position.latitude;
      if (marker.position.longitude < minLng) minLng = marker.position.longitude;
      if (marker.position.longitude > maxLng) maxLng = marker.position.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  void _showMediaBottomSheet(String mediaId) {
    DocumentSnapshot? doc;
    
    if (widget.mediaId == mediaId) {
      // Use provided data
      doc = null;
    } else {
      doc = _mediaDocuments[mediaId];
    }

    final data = doc?.data() as Map<String, dynamic>?;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Media preview thumbnail
              if (data?['downloadUrl'] != null || widget.downloadUrl != null)
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade200,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (data?['type'] ?? widget.type) == 'video'
                        ? Container(
                            color: Colors.black87,
                            child: const Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 64,
                            ),
                          )
                        : Image.network(
                            data?['downloadUrl'] ?? widget.downloadUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.broken_image, size: 48),
                              );
                            },
                          ),
                  ),
                ),
              const SizedBox(height: 16),
              // Info
              Row(
                children: [
                  Icon(
                    (data?['type'] ?? widget.type) == 'image'
                        ? Icons.image
                        : Icons.videocam,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (data?['type'] ?? widget.type) == 'image'
                              ? '画像'
                              : 'ビデオ',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (data?['userName'] != null)
                          Text(
                            'アップロード: ${data!['userName']}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showMediaPreview(mediaId);
                      },
                      icon: const Icon(Icons.open_in_full),
                      label: const Text('プレビュー'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _centerOnMarker(mediaId);
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text('中心に'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMediaPreview(String mediaId) {
    DocumentSnapshot? doc;
    
    if (widget.mediaId == mediaId) {
      // Use provided data
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MediaPreviewScreen(
            mediaId: widget.mediaId,
            url: widget.downloadUrl,
            type: widget.type!,
            latitude: widget.latitude,
            longitude: widget.longitude,
            incidentCase: widget.incidentCase,
          ),
        ),
      );
      return;
    }

    doc = _mediaDocuments[mediaId];
    if (doc == null) return;

    final data = doc.data() as Map<String, dynamic>;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaPreviewScreen(
          mediaId: doc!.id,
          url: data['downloadUrl'],
          type: data['type'],
          latitude: data['latitude'],
          longitude: data['longitude'],
          incidentCase: data['incidentCase'],
          timestamp: (data['uploadedAt'] as Timestamp?)?.toDate(),
          userName: data['userName'],
        ),
      ),
    );
  }

  void _centerOnMarker(String mediaId) {
    final marker = _markers.firstWhere(
      (m) => m.markerId.value == mediaId,
      orElse: () => _markers.first,
    );

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(marker.position, 15),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メディアマップ'),
        actions: [
          if (_markers.length > 1)
            IconButton(
              icon: const Icon(Icons.fit_screen),
              onPressed: _fitMarkersInView,
              tooltip: 'すべて表示',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMediaMarkers,
            tooltip: '更新',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.latitude ?? 35.6762,
                widget.longitude ?? 139.6503,
              ),
              zoom: widget.latitude != null ? 15 : 10,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_markers.length > 1) {
                _fitMarkersInView();
              }
            },
          ),

          // Info banner
          if (!_isLoading)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.blue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_markers.length}件のメディア',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'マーカーをタップして詳細を表示',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('メディアを読み込み中...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}