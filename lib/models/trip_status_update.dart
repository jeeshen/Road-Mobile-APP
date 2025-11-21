import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

enum StatusType {
  restStop, // 🅿 Rest stop
  toilet, // 🚻 Toilet
  fuel, // ⛽ Fuel
  eating, // 🍔 Eating
  issue, // ⚠️ Encounter issue
  resumeTrip, // 🚙 Resume trip
  custom, // Custom status
}

class TripStatusUpdate {
  final String id;
  final String tripId;
  final String userId;
  final String userName;
  final StatusType type;
  final String? customMessage;
  final LatLng location;
  final DateTime timestamp;
  final bool isAutoDetected; // System detected vs manual

  TripStatusUpdate({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.userName,
    required this.type,
    this.customMessage,
    required this.location,
    required this.timestamp,
    this.isAutoDetected = false,
  });

  String get displayText {
    switch (type) {
      case StatusType.restStop:
        return '🅿 Rest stop';
      case StatusType.toilet:
        return '🚻 Toilet';
      case StatusType.fuel:
        return '⛽ Fuel';
      case StatusType.eating:
        return '🍔 Eating';
      case StatusType.issue:
        return '⚠️ Encounter issue';
      case StatusType.resumeTrip:
        return '🚙 Resume trip';
      case StatusType.custom:
        return customMessage ?? 'Custom status';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'userId': userId,
      'userName': userName,
      'type': type.name,
      'customMessage': customMessage,
      'location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
      'timestamp': Timestamp.fromDate(timestamp),
      'isAutoDetected': isAutoDetected,
    };
  }

  factory TripStatusUpdate.fromMap(Map<String, dynamic> map) {
    return TripStatusUpdate(
      id: map['id'] ?? '',
      tripId: map['tripId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      type: StatusType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => StatusType.custom,
      ),
      customMessage: map['customMessage'],
      location: LatLng(
        map['location']['latitude'] ?? 0.0,
        map['location']['longitude'] ?? 0.0,
      ),
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isAutoDetected: map['isAutoDetected'] ?? false,
    );
  }

  TripStatusUpdate copyWith({
    String? id,
    String? tripId,
    String? userId,
    String? userName,
    StatusType? type,
    String? customMessage,
    LatLng? location,
    DateTime? timestamp,
    bool? isAutoDetected,
  }) {
    return TripStatusUpdate(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      type: type ?? this.type,
      customMessage: customMessage ?? this.customMessage,
      location: location ?? this.location,
      timestamp: timestamp ?? this.timestamp,
      isAutoDetected: isAutoDetected ?? this.isAutoDetected,
    );
  }
}



