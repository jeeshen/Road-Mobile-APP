import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user.dart';
import '../models/user_location.dart';

class LocationSharingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _cleanupTimer;

  // Update user's location in Firestore
  Future<void> updateUserLocation(User user, Position position) async {
    if (!user.shareLocation) return;

    final userLocation = UserLocation(
      userId: user.id,
      userName: user.name,
      latitude: position.latitude,
      longitude: position.longitude,
      selectedCharacter: user.selectedCharacter,
      lastUpdate: DateTime.now(),
      speed: position.speed, // Include speed for animation
    );

    await _firestore
        .collection('user_locations')
        .doc(user.id)
        .set(userLocation.toMap());
  }

  // Start sharing location
  void startSharingLocation(User user) {
    // Update every 5 seconds
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters
      ),
    ).listen((position) {
      updateUserLocation(user, position);
    });
  }

  // Stop sharing location
  Future<void> stopSharingLocation(String userId) async {
    _positionSubscription?.cancel();
    _positionSubscription = null;

    try {
      await _firestore.collection('user_locations').doc(userId).delete();
    } catch (_) {
      // Document might already be removed by cleanup or another client
    }
  }

  // Get stream of all user locations
  Stream<List<UserLocation>> getUserLocationsStream() {
    return _firestore.collection('user_locations').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserLocation.fromMap(doc.data());
      }).toList();
    });
  }

  // Start cleanup timer to remove stale locations (older than 2 minutes)
  void startCleanupTimer() {
    _cleanupTimer =
        Timer.periodic(const Duration(minutes: 2), (timer) async {
      final cutoffTime = DateTime.now().subtract(const Duration(minutes: 2));
      final staleLocations = await _firestore
          .collection('user_locations')
          .where('lastUpdate',
              isLessThan: Timestamp.fromDate(cutoffTime))
          .get();

      for (var doc in staleLocations.docs) {
        await doc.reference.delete();
      }
    });
  }

  void dispose() {
    _positionSubscription?.cancel();
    _cleanupTimer?.cancel();
  }
}

