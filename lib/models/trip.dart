import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

enum TripStatus {
  planned,
  active,
  completed,
  cancelled,
}

class Trip {
  final String id;
  final String creatorId;
  final String creatorName;
  final String title;
  final LatLng startLocation;
  final String startAddress;
  final LatLng destination;
  final String destinationAddress;
  final List<LatLng> route;
  final List<TripParticipant> participants;
  final TripStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime estimatedArrival;
  final int updateInterval; // seconds: 10, 30, or 60
  final double totalDistance; // in meters
  final Map<String, dynamic> stats; // trip statistics

  Trip({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    required this.title,
    required this.startLocation,
    required this.startAddress,
    required this.destination,
    required this.destinationAddress,
    this.route = const [],
    this.participants = const [],
    this.status = TripStatus.planned,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    required this.estimatedArrival,
    this.updateInterval = 30,
    this.totalDistance = 0,
    this.stats = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'creatorId': creatorId,
      'creatorName': creatorName,
      'title': title,
      'startLocation': {
        'latitude': startLocation.latitude,
        'longitude': startLocation.longitude,
      },
      'startAddress': startAddress,
      'destination': {
        'latitude': destination.latitude,
        'longitude': destination.longitude,
      },
      'destinationAddress': destinationAddress,
      'route': route
          .map((point) => {
                'latitude': point.latitude,
                'longitude': point.longitude,
              })
          .toList(),
      'participants': participants.map((p) => p.toMap()).toList(),
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'estimatedArrival': Timestamp.fromDate(estimatedArrival),
      'updateInterval': updateInterval,
      'totalDistance': totalDistance,
      'stats': stats,
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map) {
    return Trip(
      id: map['id'] ?? '',
      creatorId: map['creatorId'] ?? '',
      creatorName: map['creatorName'] ?? '',
      title: map['title'] ?? '',
      startLocation: LatLng(
        map['startLocation']['latitude'] ?? 0.0,
        map['startLocation']['longitude'] ?? 0.0,
      ),
      startAddress: map['startAddress'] ?? '',
      destination: LatLng(
        map['destination']['latitude'] ?? 0.0,
        map['destination']['longitude'] ?? 0.0,
      ),
      destinationAddress: map['destinationAddress'] ?? '',
      route: (map['route'] as List?)
              ?.map((point) => LatLng(
                    point['latitude'] ?? 0.0,
                    point['longitude'] ?? 0.0,
                  ))
              .toList() ??
          [],
      participants: (map['participants'] as List?)
              ?.map((p) => TripParticipant.fromMap(p as Map<String, dynamic>))
              .toList() ??
          [],
      status: TripStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TripStatus.planned,
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      startedAt: map['startedAt'] != null
          ? (map['startedAt'] as Timestamp).toDate()
          : null,
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      estimatedArrival: (map['estimatedArrival'] as Timestamp).toDate(),
      updateInterval: map['updateInterval'] ?? 30,
      totalDistance: (map['totalDistance'] ?? 0).toDouble(),
      stats: map['stats'] ?? {},
    );
  }

  Trip copyWith({
    String? id,
    String? creatorId,
    String? creatorName,
    String? title,
    LatLng? startLocation,
    String? startAddress,
    LatLng? destination,
    String? destinationAddress,
    List<LatLng>? route,
    List<TripParticipant>? participants,
    TripStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? estimatedArrival,
    int? updateInterval,
    double? totalDistance,
    Map<String, dynamic>? stats,
  }) {
    return Trip(
      id: id ?? this.id,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      title: title ?? this.title,
      startLocation: startLocation ?? this.startLocation,
      startAddress: startAddress ?? this.startAddress,
      destination: destination ?? this.destination,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      route: route ?? this.route,
      participants: participants ?? this.participants,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      estimatedArrival: estimatedArrival ?? this.estimatedArrival,
      updateInterval: updateInterval ?? this.updateInterval,
      totalDistance: totalDistance ?? this.totalDistance,
      stats: stats ?? this.stats,
    );
  }
}

class TripParticipant {
  final String userId;
  final String userName;
  final ParticipantRole role;
  final ParticipantStatus status;
  final DateTime joinedAt;
  final LatLng? currentLocation;
  final DateTime? lastLocationUpdate;

  TripParticipant({
    required this.userId,
    required this.userName,
    this.role = ParticipantRole.member,
    this.status = ParticipantStatus.pending,
    required this.joinedAt,
    this.currentLocation,
    this.lastLocationUpdate,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'role': role.name,
      'status': status.name,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'currentLocation': currentLocation != null
          ? {
              'latitude': currentLocation!.latitude,
              'longitude': currentLocation!.longitude,
            }
          : null,
      'lastLocationUpdate': lastLocationUpdate != null
          ? Timestamp.fromDate(lastLocationUpdate!)
          : null,
    };
  }

  factory TripParticipant.fromMap(Map<String, dynamic> map) {
    return TripParticipant(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      role: ParticipantRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => ParticipantRole.member,
      ),
      status: ParticipantStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ParticipantStatus.pending,
      ),
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
      currentLocation: map['currentLocation'] != null
          ? LatLng(
              map['currentLocation']['latitude'] ?? 0.0,
              map['currentLocation']['longitude'] ?? 0.0,
            )
          : null,
      lastLocationUpdate: map['lastLocationUpdate'] != null
          ? (map['lastLocationUpdate'] as Timestamp).toDate()
          : null,
    );
  }

  TripParticipant copyWith({
    String? userId,
    String? userName,
    ParticipantRole? role,
    ParticipantStatus? status,
    DateTime? joinedAt,
    LatLng? currentLocation,
    DateTime? lastLocationUpdate,
  }) {
    return TripParticipant(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      role: role ?? this.role,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      currentLocation: currentLocation ?? this.currentLocation,
      lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
    );
  }
}

enum ParticipantRole {
  creator,
  member,
}

enum ParticipantStatus {
  pending, // Invited but not accepted
  active, // Accepted and participating
  declined, // Declined invitation
  left, // Left the trip
}


