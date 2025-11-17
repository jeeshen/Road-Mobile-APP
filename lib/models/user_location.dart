import 'package:cloud_firestore/cloud_firestore.dart';

class UserLocation {
  final String userId;
  final String userName;
  final double latitude;
  final double longitude;
  final String? selectedCharacter;
  final DateTime lastUpdate;

  UserLocation({
    required this.userId,
    required this.userName,
    required this.latitude,
    required this.longitude,
    this.selectedCharacter,
    required this.lastUpdate,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'latitude': latitude,
      'longitude': longitude,
      'selectedCharacter': selectedCharacter,
      'lastUpdate': Timestamp.fromDate(lastUpdate),
    };
  }

  factory UserLocation.fromMap(Map<String, dynamic> map) {
    return UserLocation(
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      latitude: map['latitude'] ?? 0.0,
      longitude: map['longitude'] ?? 0.0,
      selectedCharacter: map['selectedCharacter'],
      lastUpdate: (map['lastUpdate'] as Timestamp).toDate(),
    );
  }
}

