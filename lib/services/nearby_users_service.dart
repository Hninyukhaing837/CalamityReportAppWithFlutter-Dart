import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class NearbyUsersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if there are nearby users within radius (km)
  Future<List<Map<String, dynamic>>> getNearbyUsers({
    required String currentUserId,
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    try {
      final usersSnapshot = await _firestore
          .collection('users')
          .where('lastLocation', isNotEqualTo: null)
          .get();

      final nearbyUsers = <Map<String, dynamic>>[];

      for (var doc in usersSnapshot.docs) {
        // Skip current user
        if (doc.id == currentUserId) continue;

        final data = doc.data();
        final lastLocation = data['lastLocation'] as Map<String, dynamic>?;

        if (lastLocation != null) {
          final userLat = lastLocation['latitude'] as double?;
          final userLon = lastLocation['longitude'] as double?;

          if (userLat != null && userLon != null) {
            final distance = _calculateDistance(
              latitude,
              longitude,
              userLat,
              userLon,
            );

            if (distance <= radiusKm) {
              nearbyUsers.add({
                'id': doc.id,
                'name': data['name'] ?? 'Unknown',
                'email': data['email'] ?? '',
                'distance': distance,
                'latitude': userLat,
                'longitude': userLon,
                'isOnline': data['isOnline'] ?? false,
                'lastSeen': data['lastSeen'],
                'geohash': data['geohash'] ?? '',
              });
            }
          }
        }
      }

      // Sort by distance
      nearbyUsers.sort((a, b) => 
        (a['distance'] as double).compareTo(b['distance'] as double)
      );

      return nearbyUsers;
    } catch (e) {
      print('Error getting nearby users: $e');
      return [];
    }
  }

  /// Calculate distance using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const R = 6371; // Earth's radius in km
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * (pi / 180);

  /// Stream of nearby users count
  Stream<int> getNearbyUsersCountStream({
    required String currentUserId,
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async* {
    await for (var snapshot in _firestore.collection('users').snapshots()) {
      int count = 0;

      for (var doc in snapshot.docs) {
        if (doc.id == currentUserId) continue;

        final data = doc.data();
        final lastLocation = data['lastLocation'] as Map<String, dynamic>?;

        if (lastLocation != null) {
          final userLat = lastLocation['latitude'] as double?;
          final userLon = lastLocation['longitude'] as double?;

          if (userLat != null && userLon != null) {
            final distance = _calculateDistance(
              latitude,
              longitude,
              userLat,
              userLon,
            );

            if (distance <= radiusKm) count++;
          }
        }
      }

      yield count;
    }
  }
}