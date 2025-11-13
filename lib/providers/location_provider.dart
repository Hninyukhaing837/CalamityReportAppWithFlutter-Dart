import 'package:flutter/foundation.dart'; // For kIsWeb
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
      if (kIsWeb) {
        // Skip permission checks for web
        _errorMessage = null;
        notifyListeners();
        return true;
      }

      // Check if location service is enabled
      _serviceEnabled = await _location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await _location.requestService();
        if (!_serviceEnabled) {
          _errorMessage = '位置情報サービスが無効です。設定で有効にしてください。'; // "Location services are disabled. Please enable them in settings."
          notifyListeners();
          return false;
        }
      }

      // Check if permission is granted
      _permissionGranted = await _location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await _location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) {
          _errorMessage = '位置情報の権限が拒否されました。設定で権限を付与してください。'; // "Location permission denied. Please grant permission in settings."
          notifyListeners();
          return false;
        }
      }

      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '権限の確認中にエラーが発生しました: $e'; // "Error checking permissions: $e"
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      if (kIsWeb) {
        // Skip location retrieval for web
        _errorMessage = '現在地の取得はWebではサポートされていません'; // "Getting location is not supported on the web."
        notifyListeners();
        return;
      }

      _errorMessage = null;

      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        return;
      }

      _currentLocation = await _location.getLocation();
      notifyListeners();
    } catch (e) {
      _errorMessage = '現在地の取得中にエラーが発生しました: $e'; // "Error getting location: $e"
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  Future<void> startTracking() async {
    try {
      if (kIsWeb) {
        // Skip location tracking for web
        _errorMessage = '位置情報追跡はWebではサポートされていません'; // "Location tracking is not supported on the web."
        notifyListeners();
        return;
      }

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
        _errorMessage = '位置情報追跡中にエラーが発生しました: $error'; // "Location tracking error: $error"
        _isTracking = false;
        debugPrint(_errorMessage);
        notifyListeners();
      });

      notifyListeners();
    } catch (e) {
      _errorMessage = '位置情報追跡の開始中にエラーが発生しました: $e'; // "Error starting location tracking: $e"
      _isTracking = false;
      debugPrint(_errorMessage);
      notifyListeners();
    }
  }

  void stopTracking() {
    if (kIsWeb) {
      // Skip stop tracking for web
      _errorMessage = '位置情報追跡はWebではサポートされていません'; // "Location tracking is not supported on the web."
      notifyListeners();
      return;
    }

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