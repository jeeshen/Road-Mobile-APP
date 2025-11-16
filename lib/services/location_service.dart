import 'package:geolocator/geolocator.dart';
import '../models/district.dart';

class LocationService {
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

  Future<Position?> getCurrentPosition() async {
    bool hasPermission = await checkPermission();
    if (!hasPermission) {
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100, // Update every 100 meters
      ),
    );
  }

  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

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
}

