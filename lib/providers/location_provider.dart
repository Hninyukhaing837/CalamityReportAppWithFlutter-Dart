import 'package:flutter/foundation.dart';
import 'package:location/location.dart';

class LocationProvider with ChangeNotifier {
  final Location _location = Location();
  LocationData? _currentLocation;
  bool _isTracking = false;
  String? _errorMessage;
  bool _serviceEnabled = false;
  PermissionStatus _permissionGranted = PermissionStatus.denied;

  LocationData? get currentLocation => _currentLocation;
  bool get isTracking => _isTracking;
  String? get errorMessage => _errorMessage;
  bool get serviceEnabled => _serviceEnabled;
  PermissionStatus get permissionGranted => _permissionGranted;

  Future<bool> checkAndRequestPermissions() async {
    try {
      // Check if location service is enabled
      _serviceEnabled = await _location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await _location.requestService();
        if (!_serviceEnabled) {
          _errorMessage = 'Location services are disabled. Please enable them in settings.';
          notifyListeners();
          return false;
        }
      }

      // Check if permission is granted
      _permissionGranted = await _location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await _location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) {
          _errorMessage = 'Location permission denied. Please grant permission in settings.';
          notifyListeners();
          return false;
        }
      }

      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error checking permissions: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      _errorMessage = null;
      
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        return;
      }

      _currentLocation = await _location.getLocation();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error getting location: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  Future<void> startTracking() async {
    try {
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        return;
      }

      _isTracking = true;
      _errorMessage = null;
      
      _location.onLocationChanged.listen((LocationData locationData) {
        _currentLocation = locationData;
        notifyListeners();
      }, onError: (error) {
        _errorMessage = 'Location tracking error: $error';
        _isTracking = false;
        debugPrint(_errorMessage);
        notifyListeners();
      });
      
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error starting location tracking: $e';
      _isTracking = false;
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  void stopTracking() {
    _isTracking = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}

// This location provider includes:
// - Permission handling
// - Current location retrieval
// - Location tracking
// - Error handling
//
// The provider can be used in your widgets by:
//
// - Accessing current location
// - Starting/stopping tracking
// - Checking permission status
// - Handling location errors