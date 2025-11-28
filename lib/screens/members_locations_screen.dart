import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class MembersLocationsScreen extends StatefulWidget {
  const MembersLocationsScreen({super.key});

  @override
  State<MembersLocationsScreen> createState() => _MembersLocationsScreenState();
}

class _MembersLocationsScreenState extends State<MembersLocationsScreen> {
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

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Color _getAvatarColor(String userId) {
    final colors = [Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink, Colors.indigo];
    return colors[userId.hashCode % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('近隣のメンバー', style: TextStyle(fontSize: 16))),
        body: const Center(child: Text('ログインが必要です')),
      );
    }

    if (_isLoadingLocation) {
      return Scaffold(
        appBar: AppBar(title: const Text('近隣のメンバー', style: TextStyle(fontSize: 16))),
        body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('位置情報を取得中...')])),
      );
    }

    if (_currentPosition == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('近隣のメンバー', style: TextStyle(fontSize: 16))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('位置情報が利用できません', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ElevatedButton.icon(onPressed: _getCurrentLocation, icon: const Icon(Icons.refresh), label: const Text('再試行')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('近隣のメンバー', style: TextStyle(fontSize: 16)), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () { setState(() {}); _getCurrentLocation(); })]),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').where('lastLocation', isNotEqualTo: null).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('エラー: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final allUsers = snapshot.data!.docs;
          final nearbyUsers = allUsers.where((doc) {
            if (doc.id == user.uid) return false;
            final data = doc.data() as Map<String, dynamic>;
            final lastLocation = data['lastLocation'] as Map<String, dynamic>?;
            
            if (lastLocation != null) {
              final lat = lastLocation['latitude'] as double?;
              final lon = lastLocation['longitude'] as double?;
              if (lat != null && lon != null) {
                final distance = _calculateDistance(_currentPosition!.latitude, _currentPosition!.longitude, lat, lon);
                return distance <= _radiusKm;
              }
            }
            return false;
          }).toList();

          nearbyUsers.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aLoc = aData['lastLocation'] as Map<String, dynamic>;
            final bLoc = bData['lastLocation'] as Map<String, dynamic>;
            final aDist = _calculateDistance(_currentPosition!.latitude, _currentPosition!.longitude, aLoc['latitude'] as double, aLoc['longitude'] as double);
            final bDist = _calculateDistance(_currentPosition!.latitude, _currentPosition!.longitude, bLoc['latitude'] as double, bLoc['longitude'] as double);
            return aDist.compareTo(bDist);
          });

          if (nearbyUsers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text('近隣にメンバーはいません', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                color: Colors.green.shade50,
                child: Row(
                  children: [
                    Icon(Icons.people, size: 20, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${nearbyUsers.length}人のメンバーが半径${_radiusKm.toStringAsFixed(0)}km以内にいます', style: TextStyle(fontSize: 13, color: Colors.green.shade900, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: nearbyUsers.length,
                  itemBuilder: (context, index) {
                    final doc = nearbyUsers[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final lastLocation = data['lastLocation'] as Map<String, dynamic>;
                    final distance = _calculateDistance(_currentPosition!.latitude, _currentPosition!.longitude, lastLocation['latitude'] as double, lastLocation['longitude'] as double);
                    final name = data['name'] as String? ?? 'Unknown';
                    final email = data['email'] as String? ?? '';
                    final isOnline = data['isOnline'] as bool? ?? false;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: _getAvatarColor(doc.id),
                                  child: Text(_getInitials(name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                ),
                                if (isOnline)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  Row(
                                    children: [
                                      Icon(isOnline ? Icons.circle : Icons.access_time, size: 12, color: isOnline ? Colors.green : Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(isOnline ? 'オンライン' : 'オフライン', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
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