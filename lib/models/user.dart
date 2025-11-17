import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String password; // Stored as plain text (simple implementation)
  final DateTime createdAt;
  final String? selectedCharacter; // Format: "color_type" e.g., "blue_warrior"
  final bool shareLocation;

  User({
    required this.id,
    required this.name,
    required this.password,
    required this.createdAt,
    this.selectedCharacter,
    this.shareLocation = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameLower': name.toLowerCase(),
      'password': password,
      'createdAt': Timestamp.fromDate(createdAt),
      'selectedCharacter': selectedCharacter,
      'shareLocation': shareLocation,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      password: map['password'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      selectedCharacter: map['selectedCharacter'],
      shareLocation: map['shareLocation'] ?? false,
    );
  }

  User copyWith({
    String? id,
    String? name,
    String? password,
    DateTime? createdAt,
    String? selectedCharacter,
    bool? shareLocation,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      selectedCharacter: selectedCharacter ?? this.selectedCharacter,
      shareLocation: shareLocation ?? this.shareLocation,
    );
  }
}

