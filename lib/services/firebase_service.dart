import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/district.dart';
import 'image_upload_service.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImageUploadService _imageUploadService = ImageUploadService();
  final Uuid _uuid = const Uuid();

  // Districts Collection
  Future<List<District>> getDistricts() async {
    try {
      final snapshot = await _firestore.collection('districts').get();
      return snapshot.docs.map((doc) => District.fromMap(doc.data())).toList();
    } catch (e) {
      print('Error getting districts: $e');
      return [];
    }
  }

  Future<void> initializeDistricts() async {
    final districtsData = _getMalaysiaDistricts();
    final batch = _firestore.batch();
    
    for (var district in districtsData) {
      final docRef = _firestore.collection('districts').doc(district.id);
      batch.set(docRef, district.toMap());
    }
    
    await batch.commit();
  }

  // Posts Collection
  Stream<List<Post>> getPostsStream(String districtId) {
    print('Getting posts stream for district: $districtId');
    
    return _firestore
        .collection('posts')
        .where('districtId', isEqualTo: districtId)
        .snapshots()
        .map((snapshot) {
          print('Firestore snapshot received: ${snapshot.docs.length} documents');
          
          if (snapshot.docs.isEmpty) {
            print('No posts found for district: $districtId');
            return <Post>[];
          }
          
          final posts = <Post>[];
          for (var doc in snapshot.docs) {
            try {
              print('Processing document: ${doc.id}');
              print('Document data: ${doc.data()}');
              final post = Post.fromMap(doc.data());
              posts.add(post);
            } catch (e) {
              print('Error parsing post ${doc.id}: $e');
            }
          }
          
          // Sort: pinned first, then by date
          posts.sort((a, b) {
            if (a.isPinned && !b.isPinned) return -1;
            if (!a.isPinned && b.isPinned) return 1;
            return b.createdAt.compareTo(a.createdAt);
          });
          
          print('Returning ${posts.length} parsed posts');
          return posts;
        });
  }

  // Get all posts for map view
  Stream<List<Post>> getAllPostsStream() {
    print('Getting all posts stream for map');
    
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(100) // Limit to recent 100 posts for performance
        .snapshots()
        .map((snapshot) {
          print('Map posts snapshot: ${snapshot.docs.length} documents');
          
          final posts = <Post>[];
          for (var doc in snapshot.docs) {
            try {
              final post = Post.fromMap(doc.data());
              posts.add(post);
            } catch (e) {
              print('Error parsing post ${doc.id}: $e');
            }
          }
          
          return posts;
        });
  }

  Future<void> createPost(Post post, List<File> mediaFiles) async {
    try {
      // Upload media files using alternative service
      final mediaUrls = await _imageUploadService.uploadImages(mediaFiles);

      final postWithMedia = post.copyWith(mediaUrls: mediaUrls);
      await _firestore
          .collection('posts')
          .doc(post.id)
          .set(postWithMedia.toMap());
    } catch (e) {
      print('Error creating post: $e');
      rethrow;
    }
  }

  Future<void> updatePostPinStatus(String postId, bool isPinned) async {
    await _firestore.collection('posts').doc(postId).update({
      'isPinned': isPinned,
    });
  }

  Future<void> incrementCommentCount(String postId) async {
    await _firestore.collection('posts').doc(postId).update({
      'commentCount': FieldValue.increment(1),
    });
  }

  // Comments Collection
  Stream<List<Comment>> getCommentsStream(String postId) {
    return _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Comment.fromMap(doc.data())).toList());
  }

  Future<void> createComment(Comment comment) async {
    try {
      await _firestore
          .collection('comments')
          .doc(comment.id)
          .set(comment.toMap());
      await incrementCommentCount(comment.postId);
    } catch (e) {
      print('Error creating comment: $e');
      rethrow;
    }
  }

  // Malaysia Districts Data
  List<District> _getMalaysiaDistricts() {
    return [
      // Kuala Lumpur
      District(id: 'bukit_jalil', name: 'Bukit Jalil', latitude: 3.0643, longitude: 101.6995, state: 'Kuala Lumpur'),
      District(id: 'sungai_besi', name: 'Sungai Besi', latitude: 3.0833, longitude: 101.7000, state: 'Kuala Lumpur'),
      District(id: 'cheras', name: 'Cheras', latitude: 3.0930, longitude: 101.7380, state: 'Kuala Lumpur'),
      District(id: 'bangsar', name: 'Bangsar', latitude: 3.1290, longitude: 101.6710, state: 'Kuala Lumpur'),
      District(id: 'klcc', name: 'KLCC', latitude: 3.1570, longitude: 101.7120, state: 'Kuala Lumpur'),
      District(id: 'petaling_jaya', name: 'Petaling Jaya', latitude: 3.1073, longitude: 101.6067, state: 'Selangor'),
      District(id: 'subang_jaya', name: 'Subang Jaya', latitude: 3.0435, longitude: 101.5874, state: 'Selangor'),
      District(id: 'shah_alam', name: 'Shah Alam', latitude: 3.0733, longitude: 101.5185, state: 'Selangor'),
      District(id: 'klang', name: 'Klang', latitude: 3.0333, longitude: 101.4500, state: 'Selangor'),
      District(id: 'ampang', name: 'Ampang', latitude: 3.1486, longitude: 101.7611, state: 'Selangor'),
      // Johor
      District(id: 'johor_bahru', name: 'Johor Bahru', latitude: 1.4927, longitude: 103.7414, state: 'Johor'),
      District(id: 'skudai', name: 'Skudai', latitude: 1.5333, longitude: 103.6667, state: 'Johor'),
      District(id: 'iskandar_puteri', name: 'Iskandar Puteri', latitude: 1.4277, longitude: 103.6520, state: 'Johor'),
      // Penang
      District(id: 'georgetown', name: 'Georgetown', latitude: 5.4141, longitude: 100.3288, state: 'Penang'),
      District(id: 'bayan_lepas', name: 'Bayan Lepas', latitude: 5.2967, longitude: 100.2650, state: 'Penang'),
      District(id: 'butterworth', name: 'Butterworth', latitude: 5.4145, longitude: 100.3635, state: 'Penang'),
      // Ipoh
      District(id: 'ipoh', name: 'Ipoh', latitude: 4.5975, longitude: 101.0901, state: 'Perak'),
      District(id: 'taiping', name: 'Taiping', latitude: 4.8500, longitude: 100.7333, state: 'Perak'),
      // Malacca
      District(id: 'malacca_city', name: 'Malacca City', latitude: 2.1896, longitude: 102.2501, state: 'Malacca'),
      // Putrajaya
      District(id: 'putrajaya', name: 'Putrajaya', latitude: 2.9264, longitude: 101.6964, state: 'Putrajaya'),
    ];
  }
}


