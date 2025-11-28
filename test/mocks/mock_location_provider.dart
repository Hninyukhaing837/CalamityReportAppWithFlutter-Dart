import 'package:calamity_report/providers/location_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart';

class MockLocationProvider extends LocationProvider {
  Position? _mockPosition;

  void setMockPosition(Position position) {
    _mockPosition = position;
    notifyListeners();
  }

  Position? get currentPosition => _mockPosition;
  @override
  LocationData? get currentLocation => _mockPosition != null
      ? LocationData.fromMap({
          'latitude': _mockPosition!.latitude,
          'longitude': _mockPosition!.longitude,
        })
      : null;

  @override
  Future<void> getCurrentLocation() async {
    // Mock implementation
    if (_mockPosition != null) {
      // Simulate loading
      await Future.delayed(const Duration(milliseconds: 100));
      notifyListeners();
    }
  }
}