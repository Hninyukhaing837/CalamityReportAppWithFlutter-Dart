import 'package:location/location.dart';
import 'package:location_platform_interface/location_platform_interface.dart';
import 'package:flutter/material.dart';

class MockLocation implements Location {
  @override
  Future<bool> serviceEnabled() async => true;

  @override
  Future<PermissionStatus> hasPermission() async => PermissionStatus.granted;

  @override
  Future<LocationData> getLocation() async {
    return LocationData.fromMap({
      'latitude': 37.4219999,
      'longitude': -122.0840575,
      'accuracy': 0.0,
      'altitude': 0.0,
      'speed': 0.0,
      'speed_accuracy': 0.0,
      'heading': 0.0,
      'time': 0.0,
    });
  }

  @override
  Future<PermissionStatus> requestPermission() async => PermissionStatus.granted;

  @override
  Future<bool> requestService() async => true;

  @override
  Stream<LocationData> get onLocationChanged => Stream.value(
        LocationData.fromMap({
          'latitude': 37.4219999,
          'longitude': -122.0840575,
          'accuracy': 0.0,
          'altitude': 0.0,
          'speed': 0.0,
          'speed_accuracy': 0.0,
          'heading': 0.0,
          'time': 0.0,
        }),
      );

  @override
  Future<bool> enableBackgroundMode({bool? enable}) async => true;

  @override
  Future<bool> isBackgroundModeEnabled() async => false;

  @override 
  Future<bool> changeSettings({
    LocationAccuracy? accuracy,
    int? interval,
    double? distanceFilter,
    bool? pausesLocationUpdatesAutomatically,  // Added missing parameter
  }) async => true;

  @override
  Future<AndroidNotificationData?> changeNotificationOptions({
    String? channelName,
    String? title,
    String? subtitle,
    String? description,
    String? iconName,
    bool? onTapBringToFront,
    Color? color,
  }) async => null;
}