import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // Register a new user with name and password
  Future<User?> register(String name, String password) async {
    try {
      // Check if name already exists
      final existingUser = await _firestore
          .collection('users')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (existingUser.docs.isNotEmpty) {
        throw Exception('Name already taken');
      }

      // Generate auto user ID
      final userId = _uuid.v4();
      final user = User(
        id: userId,
        name: name,
        password: password,
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
      final snapshot = await _firestore
          .collection('users')
          .where('name', isEqualTo: name)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('User not found');
      }

      final userData = snapshot.docs.first.data();
      final user = User.fromMap(userData);

      if (user.password != password) {
        throw Exception('Invalid password');
      }

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
}

