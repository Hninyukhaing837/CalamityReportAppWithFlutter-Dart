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
      if (kIsWeb) {
        // Web: Skip native permission checks, rely on browser
        _errorMessage = null;
        notifyListeners();
        return true;
      }

      // Check if location service is enabled
      _serviceEnabled = await _location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await _location.requestService();
        if (!_serviceEnabled) {
          _errorMessage = '位置情報サービスが無効です。設定で有効にしてください。';
          notifyListeners();
          return false;
        }
      }

      // Check if permission is granted
      _permissionGranted = await _location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await _location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) {
          _errorMessage = '位置情報の権限が拒否されました。設定で権限を付与してください。';
          notifyListeners();
          return false;
        }
      }

      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '権限の確認中にエラーが発生しました: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      _errorMessage = null;
      notifyListeners();

      // Web: Browser will show its own permission dialog
      if (kIsWeb) {
        try {
          _currentLocation = await _location.getLocation();
          _errorMessage = null;
          notifyListeners();
          return;
        } catch (e) {
          notifyListeners();
          return;
        }
      }

      // Mobile: Check permissions first
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        return;
      }

      _currentLocation = await _location.getLocation();
      notifyListeners();
    } catch (e) {
      notifyListeners();
    }
  }

  Future<void> startTracking() async {
    try {
      if (kIsWeb) {
        // Web: Location tracking is limited in browsers
        _errorMessage = '位置情報追跡はWebではサポートされていません。「現在地を取得」をご利用ください。';
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
        _errorMessage = '位置情報追跡中にエラーが発生しました: $error';
        _isTracking = false;
        notifyListeners();
      });

      notifyListeners();
    } catch (e) {
      _errorMessage = '位置情報追跡の開始中にエラーが発生しました: $e';
      _isTracking = false;
      notifyListeners();
    }
  }

  void stopTracking() {
    if (kIsWeb) {
      _errorMessage = '位置情報追跡はWebではサポートされていません';
      notifyListeners();
      return;
    }

    _isTracking = false;
    debugPrint('⏹️ 位置情報追跡を停止');
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}