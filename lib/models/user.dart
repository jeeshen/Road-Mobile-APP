import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String password; // Stored as plain text (simple implementation)
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.password,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'password': password,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      password: map['password'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

