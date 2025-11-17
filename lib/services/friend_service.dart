import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class FriendService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add a friend by user ID
  Future<void> addFriend(String userId, String friendId) async {
    try {
      if (userId == friendId) {
        throw Exception('Cannot add yourself as a friend');
      }

      final userDocRef = _firestore.collection('users').doc(userId);
      final friendDocRef = _firestore.collection('users').doc(friendId);

      // Fetch both user documents
      final results = await Future.wait([
        userDocRef.get(),
        friendDocRef.get(),
      ]);

      final currentUserDoc = results[0];
      final friendDoc = results[1];

      if (!currentUserDoc.exists) {
        throw Exception('Current user not found');
      }

      if (!friendDoc.exists) {
        throw Exception('User not found');
      }

      // Check if already friends
      final existingFriend = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc(friendId)
          .get();

      if (existingFriend.exists) {
        throw Exception('Already friends');
      }

      // Check if the other direction already exists
      final reverseFriend = await _firestore
          .collection('users')
          .doc(friendId)
          .collection('friends')
          .doc(userId)
          .get();

      if (reverseFriend.exists) {
        throw Exception('Already friends');
      }

      final friendData = friendDoc.data()!;
      final currentUserData = currentUserDoc.data()!;

      final batch = _firestore.batch();

      // Add friend to user's friends list
      batch.set(
        userDocRef.collection('friends').doc(friendId),
        {
          'friendId': friendId,
          'friendName': friendData['name'],
          'addedAt': FieldValue.serverTimestamp(),
        },
      );

      // Add current user to friend's friends list
      batch.set(
        friendDocRef.collection('friends').doc(userId),
        {
          'friendId': userId,
          'friendName': currentUserData['name'],
          'addedAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (e) {
      print('Error adding friend: $e');
      rethrow;
    }
  }

  // Remove a friend
  Future<void> removeFriend(String userId, String friendId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc(friendId)
          .delete();
    } catch (e) {
      print('Error removing friend: $e');
      rethrow;
    }
  }

  // Get all friends for a user
  Stream<List<Map<String, dynamic>>> getFriendsStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  // Get user by ID for friend lookup
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
}

