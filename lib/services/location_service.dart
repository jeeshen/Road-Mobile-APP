import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/district.dart';

/// Enhanced GPS Service with tracking, speed, and location utilities
class LocationService {
  Position? _lastKnownPosition;
  DateTime? _lastUpdateTime;
  final List<Position> _locationHistory = [];
  static const int _maxHistorySize = 100; // Keep last 100 positions

  /// Check if location services are enabled and permissions granted
  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current GPS position with high accuracy
  Future<Position?> getCurrentPosition() async {
    bool hasPermission = await checkPermission();
    if (!hasPermission) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _updatePosition(position);
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Get current position with custom accuracy
  Future<Position?> getCurrentPositionWithAccuracy(
    LocationAccuracy accuracy,
  ) async {
    bool hasPermission = await checkPermission();
    if (!hasPermission) {
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
      );
      _updatePosition(position);
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  /// Get continuous position updates stream
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 100,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter, // Update every X meters
      ),
    ).map((position) {
      _updatePosition(position);
      return position;
    });
  }

  /// Update position and maintain history
  void _updatePosition(Position position) {
    _lastKnownPosition = position;
    _lastUpdateTime = DateTime.now();
    
    _locationHistory.add(position);
    if (_locationHistory.length > _maxHistorySize) {
      _locationHistory.removeAt(0);
    }
  }

  /// Get last known position (cached)
  Position? getLastKnownPosition() {
    return _lastKnownPosition;
  }

  /// Get location history
  List<Position> getLocationHistory() {
    return List.unmodifiable(_locationHistory);
  }

  /// Clear location history
  void clearHistory() {
    _locationHistory.clear();
  }

  /// Calculate distance between two coordinates (in meters)
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Calculate bearing/direction between two points (in degrees)
  double calculateBearing(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.bearingBetween(lat1, lon1, lat2, lon2);
  }

  /// Get current speed (if available)
  double? getCurrentSpeed() {
    return _lastKnownPosition?.speed;
  }

  /// Get speed in km/h
  double? getCurrentSpeedKmh() {
    final speed = getCurrentSpeed();
    if (speed == null) return null;
    return speed * 3.6; // Convert m/s to km/h
  }

  /// Check if GPS is currently active
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get GPS accuracy status
  Future<String> getLocationAccuracyStatus() async {
    if (!await isLocationServiceEnabled()) {
      return 'GPS Disabled';
    }

    if (_lastKnownPosition == null) {
      return 'No Location';
    }

    final accuracy = _lastKnownPosition!.accuracy;
    if (accuracy < 10) {
      return 'High Accuracy';
    } else if (accuracy < 50) {
      return 'Medium Accuracy';
    } else {
      return 'Low Accuracy';
    }
  }

  /// Calculate total distance traveled from history
  double calculateTotalDistanceTraveled() {
    if (_locationHistory.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 1; i < _locationHistory.length; i++) {
      final prev = _locationHistory[i - 1];
      final curr = _locationHistory[i];
      totalDistance += calculateDistance(
        prev.latitude,
        prev.longitude,
        curr.latitude,
        curr.longitude,
      );
    }

    return totalDistance;
  }

  /// Get average speed from history (in km/h)
  double? getAverageSpeed() {
    if (_locationHistory.length < 2 || _lastUpdateTime == null) {
      return null;
    }

    final totalDistance = calculateTotalDistanceTraveled();
    final timeElapsed = DateTime.now().difference(_lastUpdateTime!).inSeconds;
    
    if (timeElapsed == 0) return null;
    
    final avgSpeedMs = totalDistance / timeElapsed;
    return avgSpeedMs * 3.6; // Convert to km/h
  }

  /// Find nearest district from current position
  District? findNearestDistrict(Position position, List<District> districts) {
    if (districts.isEmpty) return null;

    District? nearest;
    double minDistance = double.infinity;

    for (var district in districts) {
      final distance = calculateDistance(
        position.latitude,
        position.longitude,
        district.latitude,
        district.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearest = district;
      }
    }

    return nearest;
  }

  /// Get formatted address from coordinates (requires geocoding service)
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      // Note: This requires a geocoding service
      // You can use packages like 'geocoding' for reverse geocoding
      return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
    } catch (e) {
      print('Error getting address: $e');
      return null;
    }
  }

  /// Check if location is within a radius of a point
  bool isWithinRadius(
    double centerLat,
    double centerLon,
    double radiusMeters,
    double checkLat,
    double checkLon,
  ) {
    final distance = calculateDistance(
      centerLat,
      centerLon,
      checkLat,
      checkLon,
    );
    return distance <= radiusMeters;
  }

  /// Get GPS status information
  Future<Map<String, dynamic>> getGPSStatus() async {
    final isEnabled = await isLocationServiceEnabled();
    final hasPermission = await checkPermission();
    final accuracy = await getLocationAccuracyStatus();
    final speed = getCurrentSpeedKmh();
    final avgSpeed = getAverageSpeed();
    final totalDistance = calculateTotalDistanceTraveled();

    return {
      'enabled': isEnabled,
      'permissionGranted': hasPermission,
      'accuracy': accuracy,
      'currentSpeed': speed,
      'averageSpeed': avgSpeed,
      'totalDistance': totalDistance,
      'lastUpdate': _lastUpdateTime?.toIso8601String(),
      'historyCount': _locationHistory.length,
      'lastPosition': _lastKnownPosition != null
          ? {
              'latitude': _lastKnownPosition!.latitude,
              'longitude': _lastKnownPosition!.longitude,
              'accuracy': _lastKnownPosition!.accuracy,
            }
          : null,
    };
  }
}

