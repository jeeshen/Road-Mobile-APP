import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

enum MessageType {
  text,
  location,
  photo,
  voice,
  systemAlert, // System-generated alerts
}

class TripMessage {
  final String id;
  final String tripId;
  final String senderId;
  final String senderName;
  final MessageType type;
  final String? content; // Text content or file URL
  final LatLng? location; // For location messages
  final DateTime timestamp;
  final bool isRead;
  final String? metadata; // Additional data (e.g., voice duration)

  TripMessage({
    required this.id,
    required this.tripId,
    required this.senderId,
    required this.senderName,
    required this.type,
    this.content,
    this.location,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tripId': tripId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.name,
      'content': content,
      'location': location != null
          ? {
              'latitude': location!.latitude,
              'longitude': location!.longitude,
            }
          : null,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'metadata': metadata,
    };
  }

  factory TripMessage.fromMap(Map<String, dynamic> map) {
    return TripMessage(
      id: map['id'] ?? '',
      tripId: map['tripId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      content: map['content'],
      location: map['location'] != null
          ? LatLng(
              map['location']['latitude'] ?? 0.0,
              map['location']['longitude'] ?? 0.0,
            )
          : null,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
      metadata: map['metadata'],
    );
  }

  TripMessage copyWith({
    String? id,
    String? tripId,
    String? senderId,
    String? senderName,
    MessageType? type,
    String? content,
    LatLng? location,
    DateTime? timestamp,
    bool? isRead,
    String? metadata,
  }) {
    return TripMessage(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      type: type ?? this.type,
      content: content ?? this.content,
      location: location ?? this.location,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }
}



