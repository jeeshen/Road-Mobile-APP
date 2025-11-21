import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../models/trip.dart';
import '../models/trip_status_update.dart';
import '../models/trip_message.dart';

class ConvoyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // Collections
  static const String _tripsCollection = 'convoy_trips';
  static const String _statusUpdatesCollection = 'trip_status_updates';
  static const String _messagesCollection = 'trip_messages';
  static const String _invitationsCollection = 'trip_invitations';

  /// Create a new trip
  Future<Trip> createTrip({
    required String creatorId,
    required String creatorName,
    required String title,
    required LatLng startLocation,
    required String startAddress,
    required LatLng destination,
    required String destinationAddress,
    List<LatLng> route = const [],
    required DateTime estimatedArrival,
    int updateInterval = 30,
    double totalDistance = 0,
  }) async {
    final tripId = _uuid.v4();
    final now = DateTime.now();

    final creator = TripParticipant(
      userId: creatorId,
      userName: creatorName,
      role: ParticipantRole.creator,
      status: ParticipantStatus.active,
      joinedAt: now,
    );

    final trip = Trip(
      id: tripId,
      creatorId: creatorId,
      creatorName: creatorName,
      title: title,
      startLocation: startLocation,
      startAddress: startAddress,
      destination: destination,
      destinationAddress: destinationAddress,
      route: route,
      participants: [creator],
      status: TripStatus.planned,
      createdAt: now,
      estimatedArrival: estimatedArrival,
      updateInterval: updateInterval,
      totalDistance: totalDistance,
    );

    await _firestore.collection(_tripsCollection).doc(tripId).set(trip.toMap());

    return trip;
  }

  /// Invite friends to trip
  Future<void> inviteFriendsToTrip({
    required String tripId,
    required List<String> friendIds,
    required String inviterName,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now();

    for (final friendId in friendIds) {
      final invitationId = _uuid.v4();
      final invitationRef = _firestore
          .collection(_invitationsCollection)
          .doc(invitationId);

      batch.set(invitationRef, {
        'id': invitationId,
        'tripId': tripId,
        'inviterId': inviterName,
        'inviteeId': friendId,
        'status': 'pending',
        'createdAt': Timestamp.fromDate(now),
      });
    }

    await batch.commit();
  }

  /// Accept trip invitation
  Future<void> acceptTripInvitation({
    required String invitationId,
    required String tripId,
    required String userId,
    required String userName,
  }) async {
    final batch = _firestore.batch();

    // Update invitation status
    final invitationRef = _firestore
        .collection(_invitationsCollection)
        .doc(invitationId);
    batch.update(invitationRef, {
      'status': 'accepted',
      'acceptedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Add participant to trip
    final tripRef = _firestore.collection(_tripsCollection).doc(tripId);
    final tripDoc = await tripRef.get();
    if (!tripDoc.exists) throw Exception('Trip not found');

    final trip = Trip.fromMap(tripDoc.data()!);
    final newParticipant = TripParticipant(
      userId: userId,
      userName: userName,
      role: ParticipantRole.member,
      status: ParticipantStatus.active,
      joinedAt: DateTime.now(),
    );

    final updatedParticipants = [...trip.participants, newParticipant];

    batch.update(tripRef, {
      'participants': updatedParticipants.map((p) => p.toMap()).toList(),
    });

    await batch.commit();

    // Send system message
    await sendSystemMessage(
      tripId: tripId,
      content: '$userName joined the convoy',
    );
  }

  /// Decline trip invitation
  Future<void> declineTripInvitation(String invitationId) async {
    await _firestore
        .collection(_invitationsCollection)
        .doc(invitationId)
        .update({
          'status': 'declined',
          'declinedAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  /// Get pending invitations for user
  Stream<List<Map<String, dynamic>>> getPendingInvitations(String userId) {
    return _firestore
        .collection(_invitationsCollection)
        .where('inviteeId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final invitations = <Map<String, dynamic>>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final tripId = data['tripId'];

            // Fetch trip details
            final tripDoc = await _firestore
                .collection(_tripsCollection)
                .doc(tripId)
                .get();
            if (tripDoc.exists) {
              final tripData = tripDoc.data()!;
              invitations.add({'invitation': data, 'trip': tripData});
            }
          }

          return invitations;
        });
  }

  /// Start trip
  Future<void> startTrip(String tripId) async {
    await _firestore.collection(_tripsCollection).doc(tripId).update({
      'status': TripStatus.active.name,
      'startedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Send system message
    await sendSystemMessage(
      tripId: tripId,
      content: '🚗 Trip started! Drive safely!',
    );
  }

  /// Complete trip
  Future<void> completeTrip(String tripId, Map<String, dynamic> stats) async {
    await _firestore.collection(_tripsCollection).doc(tripId).update({
      'status': TripStatus.completed.name,
      'completedAt': Timestamp.fromDate(DateTime.now()),
      'stats': stats,
    });

    // Send system message
    await sendSystemMessage(
      tripId: tripId,
      content: '🏁 Trip completed! Thank you for using convoy mode.',
    );
  }

  /// Cancel trip
  Future<void> cancelTrip(String tripId) async {
    await _firestore.collection(_tripsCollection).doc(tripId).update({
      'status': TripStatus.cancelled.name,
      'completedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Update participant location
  Future<void> updateParticipantLocation({
    required String tripId,
    required String userId,
    required Position position,
  }) async {
    final tripRef = _firestore.collection(_tripsCollection).doc(tripId);
    final tripDoc = await tripRef.get();
    if (!tripDoc.exists) return;

    final trip = Trip.fromMap(tripDoc.data()!);
    final updatedParticipants = trip.participants.map((p) {
      if (p.userId == userId) {
        return p.copyWith(
          currentLocation: LatLng(position.latitude, position.longitude),
          lastLocationUpdate: DateTime.now(),
        );
      }
      return p;
    }).toList();

    await tripRef.update({
      'participants': updatedParticipants.map((p) => p.toMap()).toList(),
    });
  }

  /// Post status update
  Future<void> postStatusUpdate({
    required String tripId,
    required String userId,
    required String userName,
    required StatusType type,
    String? customMessage,
    required LatLng location,
    bool isAutoDetected = false,
  }) async {
    final statusId = _uuid.v4();
    final statusUpdate = TripStatusUpdate(
      id: statusId,
      tripId: tripId,
      userId: userId,
      userName: userName,
      type: type,
      customMessage: customMessage,
      location: location,
      timestamp: DateTime.now(),
      isAutoDetected: isAutoDetected,
    );

    await _firestore
        .collection(_statusUpdatesCollection)
        .doc(statusId)
        .set(statusUpdate.toMap());

    // Also send as system message
    await sendSystemMessage(
      tripId: tripId,
      content: '$userName: ${statusUpdate.displayText}',
    );
  }

  /// Get status updates for trip
  Stream<List<TripStatusUpdate>> getStatusUpdates(String tripId) {
    return _firestore
        .collection(_statusUpdatesCollection)
        .where('tripId', isEqualTo: tripId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TripStatusUpdate.fromMap(doc.data()))
              .toList(),
        );
  }

  /// Send message
  Future<void> sendMessage({
    required String tripId,
    required String senderId,
    required String senderName,
    required MessageType type,
    String? content,
    LatLng? location,
    String? metadata,
  }) async {
    final messageId = _uuid.v4();
    final message = TripMessage(
      id: messageId,
      tripId: tripId,
      senderId: senderId,
      senderName: senderName,
      type: type,
      content: content,
      location: location,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    await _firestore
        .collection(_messagesCollection)
        .doc(messageId)
        .set(message.toMap());
  }

  /// Send system message
  Future<void> sendSystemMessage({
    required String tripId,
    required String content,
  }) async {
    await sendMessage(
      tripId: tripId,
      senderId: 'system',
      senderName: 'System',
      type: MessageType.systemAlert,
      content: content,
    );
  }

  /// Get messages for trip
  Stream<List<TripMessage>> getMessages(String tripId) {
    return _firestore
        .collection(_messagesCollection)
        .where('tripId', isEqualTo: tripId)
        .orderBy('timestamp', descending: false)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TripMessage.fromMap(doc.data()))
              .toList(),
        );
  }

  /// Get trip by ID
  Future<Trip?> getTrip(String tripId) async {
    final doc = await _firestore.collection(_tripsCollection).doc(tripId).get();
    if (!doc.exists) return null;
    return Trip.fromMap(doc.data()!);
  }

  /// Get trip stream (real-time updates)
  Stream<Trip?> getTripStream(String tripId) {
    return _firestore
        .collection(_tripsCollection)
        .doc(tripId)
        .snapshots()
        .map((doc) => doc.exists ? Trip.fromMap(doc.data()!) : null);
  }

  /// Get user's active trips
  Stream<List<Trip>> getUserActiveTrips(String userId) {
    return _firestore
        .collection(_tripsCollection)
        .where(
          'status',
          whereIn: [TripStatus.planned.name, TripStatus.active.name],
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          final trips = snapshot.docs
              .map((doc) => Trip.fromMap(doc.data()))
              .where(
                (trip) => trip.participants.any(
                  (p) =>
                      p.userId == userId &&
                      (p.status == ParticipantStatus.active ||
                          p.status == ParticipantStatus.pending),
                ),
              )
              .toList();
          return trips;
        });
  }

  /// Get user's completed trips
  Stream<List<Trip>> getUserCompletedTrips(String userId) {
    return _firestore
        .collection(_tripsCollection)
        .where('status', isEqualTo: TripStatus.completed.name)
        .orderBy('completedAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
          final trips = snapshot.docs
              .map((doc) => Trip.fromMap(doc.data()))
              .where((trip) => trip.participants.any((p) => p.userId == userId))
              .toList();
          return trips;
        });
  }

  /// Leave trip
  Future<void> leaveTrip({
    required String tripId,
    required String userId,
    required String userName,
  }) async {
    final tripRef = _firestore.collection(_tripsCollection).doc(tripId);
    final tripDoc = await tripRef.get();
    if (!tripDoc.exists) return;

    final trip = Trip.fromMap(tripDoc.data()!);

    // Can't leave if you're the creator and there are other active participants
    final isCreator = trip.creatorId == userId;
    final otherActiveParticipants = trip.participants
        .where(
          (p) => p.userId != userId && p.status == ParticipantStatus.active,
        )
        .length;

    if (isCreator && otherActiveParticipants > 0) {
      throw Exception(
        'Creator cannot leave while other participants are active. Cancel the trip instead.',
      );
    }

    final updatedParticipants = trip.participants.map((p) {
      if (p.userId == userId) {
        return p.copyWith(status: ParticipantStatus.left);
      }
      return p;
    }).toList();

    await tripRef.update({
      'participants': updatedParticipants.map((p) => p.toMap()).toList(),
    });

    // Send system message
    await sendSystemMessage(
      tripId: tripId,
      content: '$userName left the convoy',
    );
  }

  /// Check if user has moved (for safety alerts)
  bool hasUserMoved(TripParticipant participant, Duration threshold) {
    if (participant.lastLocationUpdate == null) return false;
    final timeSinceUpdate = DateTime.now().difference(
      participant.lastLocationUpdate!,
    );
    return timeSinceUpdate < threshold;
  }

  /// Calculate distance between two points (in meters)
  double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  /// Check if participant is too far from route
  bool isParticipantOffRoute(
    TripParticipant participant,
    List<LatLng> route,
    double maxDistanceMeters,
  ) {
    if (participant.currentLocation == null || route.isEmpty) return false;

    // Find minimum distance to route
    double minDistance = double.infinity;
    for (final point in route) {
      final distance = calculateDistance(participant.currentLocation!, point);
      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance > maxDistanceMeters;
  }

  /// Check if participant reached destination
  bool hasReachedDestination(
    TripParticipant participant,
    LatLng destination,
    double thresholdMeters,
  ) {
    if (participant.currentLocation == null) return false;
    final distance = calculateDistance(
      participant.currentLocation!,
      destination,
    );
    return distance <= thresholdMeters;
  }
}


