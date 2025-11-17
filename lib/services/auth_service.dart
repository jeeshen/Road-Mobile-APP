import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Random _random = Random();

  // Register a new user with name and password
  Future<User?> register(String name, String password) async {
    try {
      final trimmedName = name.trim();
      final trimmedPassword = password.trim();
      final normalizedName = trimmedName.toLowerCase();

      await _ensureNameIsAvailable(trimmedName, normalizedName);

      // Generate short 6-digit user ID
      final userId = await _generateUniqueUserId();
      final user = User(
        id: userId,
        name: trimmedName,
        password: trimmedPassword,
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      await _firestore.collection('users').doc(userId).set(user.toMap());

      return user;
    } catch (e) {
      print('Error registering user: $e');
      rethrow;
    }
  }

  // Login with name and password
  Future<User?> login(String name, String password) async {
    try {
      final trimmedName = name.trim();
      final normalizedName = trimmedName.toLowerCase();
      final trimmedPassword = password.trim();

      final userDoc = await _findUserDocByName(normalizedName);
      if (userDoc == null) {
        throw Exception('User not found');
      }

      final userData = userDoc.data();
      final user = User.fromMap(userData);

      if (user.password != trimmedPassword) {
        throw Exception('Invalid password');
      }

      await _ensureNormalizedField(userDoc, normalizedName);

      return user;
    } catch (e) {
      print('Error logging in: $e');
      rethrow;
    }
  }

  // Get user by ID
  Future<User?> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return User.fromMap(doc.data()!);
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // Get user by name
  Future<User?> getUserByName(String name) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return User.fromMap(snapshot.docs.first.data());
    } catch (e) {
      print('Error getting user by name: $e');
      return null;
    }
  }

  // Update user information
  Future<void> updateUser(User user) async {
    try {
      await _firestore.collection('users').doc(user.id).update(user.toMap());
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  Future<String> _generateUniqueUserId() async {
    while (true) {
      final candidate = (_random.nextInt(900000) + 100000).toString();
      final existingDoc = await _firestore
          .collection('users')
          .doc(candidate)
          .get();
      if (!existingDoc.exists) {
        return candidate;
      }
    }
  }

  Future<void> _ensureNameIsAvailable(
    String displayName,
    String normalizedName,
  ) async {
    final normalizedSnapshot = await _firestore
        .collection('users')
        .where('nameLower', isEqualTo: normalizedName)
        .limit(1)
        .get();

    if (normalizedSnapshot.docs.isNotEmpty) {
      throw Exception('Name already taken');
    }

    final exactSnapshot = await _firestore
        .collection('users')
        .where('name', isEqualTo: displayName)
        .limit(1)
        .get();

    final hasLegacyMatch = exactSnapshot.docs.any((doc) {
      final docName = (doc.data()['name'] as String?)?.toLowerCase();
      return docName == normalizedName;
    });

    if (hasLegacyMatch) {
      throw Exception('Name already taken');
    }
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findUserDocByName(
    String normalizedName,
  ) async {
    final snapshot = await _firestore
        .collection('users')
        .where('nameLower', isEqualTo: normalizedName)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first;
    }

    final fallbackSnapshot = await _firestore.collection('users').get();
    for (final doc in fallbackSnapshot.docs) {
      final docName = (doc.data()['name'] as String?)?.toLowerCase();
      if (docName == normalizedName) {
        return doc;
      }
    }

    return null;
  }

  Future<void> _ensureNormalizedField(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String normalizedName,
  ) async {
    final currentValue = doc.data()['nameLower'] as String?;
    if (currentValue == normalizedName) {
      return;
    }

    await doc.reference.update({'nameLower': normalizedName});
  }
}
