import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';

/// Service for detecting road damage using accelerometer data
/// Detects when car moves up and down (vertical acceleration changes)
class RoadDamageService {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<Position>? _positionSubscription;
  final List<double> _accelerationHistory = [];
  final int _historySize = 10; // Keep last 10 readings
  final double _damageThreshold =
      5.0; // m/s² threshold for road damage detection (increased to only detect potholes, not bumps)
  Position? _lastPosition;
  DateTime? _lastDamageDetection;
  final Duration _cooldownPeriod = const Duration(seconds: 5); // Prevent spam

  Function(Position position, double severity)? onRoadDamageDetected;

  /// Start monitoring for road damage
  void startMonitoring() {
    // Listen to accelerometer events
    _accelerometerSubscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        _processAccelerometerData(event);
      },
      onError: (error) {
        print('Accelerometer error: $error');
      },
    );

    // Listen to position updates to get location when damage is detected
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // Update every 10 meters
          ),
        ).listen(
          (Position position) {
            _lastPosition = position;
          },
          onError: (error) {
            print('Position stream error: $error');
          },
        );
  }

  /// Stop monitoring
  void stopMonitoring() {
    _accelerometerSubscription?.cancel();
    _positionSubscription?.cancel();
    _accelerationHistory.clear();
  }

  /// Process accelerometer data to detect road damage
  void _processAccelerometerData(AccelerometerEvent event) {
    // Focus on vertical acceleration (Z-axis) for up/down movement
    final verticalAcceleration = event.z.abs();

    // Add to history
    _accelerationHistory.add(verticalAcceleration);
    if (_accelerationHistory.length > _historySize) {
      _accelerationHistory.removeAt(0);
    }

    // Check for sudden vertical acceleration changes (road damage indicator)
    if (_accelerationHistory.length >= 3) {
      final recent = _accelerationHistory.sublist(
        _accelerationHistory.length - 3,
      );
      final avgRecent =
          recent.fold<double>(0.0, (sum, value) => sum + value) / recent.length;
      final previous = _accelerationHistory.length >= 6
          ? _accelerationHistory.sublist(
              _accelerationHistory.length - 6,
              _accelerationHistory.length - 3,
            )
          : <double>[];

      if (previous.isNotEmpty) {
        final avgPrevious =
            previous.fold<double>(0.0, (sum, value) => sum + value) /
            previous.length;
        final change = (avgRecent - avgPrevious).abs();

        // Detect significant vertical acceleration change
        if (change > _damageThreshold &&
            verticalAcceleration > _damageThreshold) {
          _detectRoadDamage(change);
        }
      }
    }
  }

  /// Detect and report road damage
  void _detectRoadDamage(double severity) {
    // Cooldown check to prevent spam
    if (_lastDamageDetection != null) {
      final timeSinceLastDetection = DateTime.now().difference(
        _lastDamageDetection!,
      );
      if (timeSinceLastDetection < _cooldownPeriod) {
        return;
      }
    }

    if (_lastPosition != null) {
      _lastDamageDetection = DateTime.now();

      // Normalize severity (0.0 to 1.0)
      final normalizedSeverity = (severity / (_damageThreshold * 2)).clamp(
        0.0,
        1.0,
      );

      // Call callback if registered
      onRoadDamageDetected?.call(_lastPosition!, normalizedSeverity);

      print(
        'Road damage detected at: ${_lastPosition!.latitude}, ${_lastPosition!.longitude}',
      );
      print('Severity: ${normalizedSeverity.toStringAsFixed(2)}');
    }
  }

  /// Get current acceleration statistics
  Map<String, double> getAccelerationStats() {
    if (_accelerationHistory.isEmpty) {
      return {'current': 0.0, 'average': 0.0, 'max': 0.0};
    }

    return {
      'current': _accelerationHistory.last,
      'average':
          _accelerationHistory.fold<double>(0.0, (sum, value) => sum + value) /
          _accelerationHistory.length,
      'max': _accelerationHistory.fold<double>(
        0.0,
        (max, value) => value > max ? value : max,
      ),
    };
  }
}
