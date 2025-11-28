import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class NearbyDisastersScreen extends StatefulWidget {
  const NearbyDisastersScreen({super.key});

  @override
  State<NearbyDisastersScreen> createState() => _NearbyDisastersScreenState();
}

class _NearbyDisastersScreenState extends State<NearbyDisastersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  final double _radiusKm = 5.0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() => _isLoadingLocation = true);
      
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      _currentPosition = await Geolocator.getCurrentPosition();
      setState(() => _isLoadingLocation = false);
    } catch (e) {
      print('Location error: $e');
      setState(() => _isLoadingLocation = false);
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * (pi / 180);

  Color _getTypeColor(String type) {
    switch (type) {
      case '火災': return Colors.red;
      case '洪水': return Colors.blue;
      case '地震': return Colors.orange;
      case '医療': return Colors.green;
      default: return Colors.purple;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case '火災': return Icons.local_fire_department;
      case '洪水': return Icons.flood;
      case '地震': return Icons.terrain;
      case '医療': return Icons.medical_services;
      default: return Icons.warning;
    }
  }

  // Helper method to extract coordinates from dynamic location data
  Map<String, double>? _getCoordinates(dynamic locationData) {
    if (locationData == null) return null;

    double? lat;
    double? lon;

    if (locationData is GeoPoint) {
      lat = locationData.latitude;
      lon = locationData.longitude;
    } else if (locationData is Map<String, dynamic>) {
      lat = locationData['latitude'] as double?;
      lon = locationData['longitude'] as double?;
    }

    if (lat != null && lon != null) {
      return {'latitude': lat, 'longitude': lon};
    }
    return null;
  }

  void _showReportDetailsDialog(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final coords = _getCoordinates(data['location']);
    
    double? distance;
    if (coords != null && _currentPosition != null) {
      distance = _calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        coords['latitude']!,
        coords['longitude']!,
      );
    }

    final type = data['type'] as String? ?? 'その他';
    final severity = data['severity'] as String? ?? '';
    final description = data['description'] as String? ?? '';
    final location = data['locationName'] as String? ?? '';
    final userName = data['userName'] as String? ?? 'Unknown';
    final userEmail = data['userEmail'] as String? ?? '';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final imageUrl = data['imageUrl'] as String? ?? '';
    
    Color getSeverityColor(String severity) {
      switch (severity) {
        case '緊急': return Colors.red;
        case '警告': return Colors.orange;
        case '注意': return Colors.yellow.shade700;
        default: return Colors.grey;
      }
    }

    IconData getSeverityIcon(String severity) {
      switch (severity) {
        case '緊急': return Icons.emergency;
        case '警告': return Icons.warning;
        case '注意': return Icons.info;
        default: return Icons.circle;
      }
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getTypeColor(type).withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getTypeColor(type).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_getTypeIcon(type), color: _getTypeColor(type), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _getTypeColor(type),
                            ),
                          ),
                          if (severity.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  getSeverityIcon(severity),
                                  size: 14,
                                  color: getSeverityColor(severity),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: getSeverityColor(severity).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    severity,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: getSeverityColor(severity),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image if available
                      if (imageUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 200,
                                color: Colors.grey.shade200,
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.grey.shade200,
                                child: const Center(
                                  child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Sender Information
                      _buildInfoSection(
                        icon: Icons.person,
                        title: '報告者',
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (userEmail.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                userEmail,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const Divider(height: 24),

                      // Location Information
                      _buildInfoSection(
                        icon: Icons.location_on,
                        title: '場所',
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (location.isNotEmpty) ...[
                              Text(
                                location,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                            ],
                            if (coords != null) ...[
                              Text(
                                '緯度: ${coords['latitude']!.toStringAsFixed(6)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              Text(
                                '経度: ${coords['longitude']!.toStringAsFixed(6)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                            if (distance != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.near_me, size: 14, color: Colors.blue.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    'あなたから ${distance.toStringAsFixed(2)}km',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const Divider(height: 24),

                      // Details
                      _buildInfoSection(
                        icon: Icons.description,
                        title: '詳細',
                        content: Text(
                          description.isNotEmpty ? description : '詳細情報なし',
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),

                      const Divider(height: 24),

                      // Date
                      if (createdAt != null)
                        _buildInfoSection(
                          icon: Icons.access_time,
                          title: '報告日時',
                          content: Text(
                            DateFormat('yyyy年MM月dd日 HH:mm').format(createdAt),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade500),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 4),
              content,
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('近隣の災害', style: TextStyle(fontSize: 16))),
        body: const Center(child: Text('ログインが必要です')),
      );
    }

    if (_isLoadingLocation) {
      return Scaffold(
        appBar: AppBar(title: const Text('近隣の災害', style: TextStyle(fontSize: 16))),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('位置情報を取得中...'),
            ],
          ),
        ),
      );
    }

    if (_currentPosition == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('近隣の災害', style: TextStyle(fontSize: 16))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('位置情報が利用できません', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('設定で位置情報を有効にしてください'),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('近隣の災害', style: TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
              _getCurrentLocation();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('emergency_reports').orderBy('createdAt', descending: true).limit(100).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allReports = snapshot.data!.docs;
          
          // Filter nearby reports
          final nearbyReports = allReports.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            
            // Use safe helper for location
            final coords = _getCoordinates(data['location']);
            
            if (data['userId'] == user.uid) return false;
            
            if (coords != null) {
              final distance = _calculateDistance(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                coords['latitude']!,
                coords['longitude']!,
              );
              return distance <= _radiusKm;
            }
            return false;
          }).toList();

          // Sort by distance
          nearbyReports.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            
            final aCoords = _getCoordinates(aData['location']);
            final bCoords = _getCoordinates(bData['location']);
            
            if (aCoords == null || bCoords == null) return 0;

            final aDist = _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              aCoords['latitude']!,
              aCoords['longitude']!,
            );
            final bDist = _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              bCoords['latitude']!,
              bCoords['longitude']!,
            );
            return aDist.compareTo(bDist);
          });

          if (nearbyReports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_searching, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('近隣に災害報告はありません', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('半径${_radiusKm.toStringAsFixed(0)}km以内', style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.blue.shade50,
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${nearbyReports.length}件の災害報告が半径${_radiusKm.toStringAsFixed(0)}km以内で見つかりました',
                        style: TextStyle(fontSize: 13, color: Colors.blue.shade900, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: nearbyReports.length,
                  itemBuilder: (context, index) {
                    final doc = nearbyReports[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final coords = _getCoordinates(data['location']);
                    
                    if (coords == null) return const SizedBox.shrink();

                    final distance = _calculateDistance(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                      coords['latitude']!,
                      coords['longitude']!,
                    );

                    final type = data['type'] as String? ?? 'その他';
                    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _showReportDetailsDialog(context, doc),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _getTypeColor(type).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(_getTypeIcon(type), color: _getTypeColor(type), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(type, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _getTypeColor(type))),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.location_on, size: 14, color: Colors.blue.shade700),
                                        const SizedBox(width: 4),
                                        Text('${distance.toStringAsFixed(1)}km', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(data['description'] ?? '', style: const TextStyle(fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(data['userName'] ?? 'Unknown', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
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
