import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/district.dart';
import '../models/user.dart';
import 'image_upload_service.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImageUploadService _imageUploadService = ImageUploadService();

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

  Future<void> toggleLike(String postId, String userId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return;

      final postData = postDoc.data()!;
      final likedBy = List<String>.from(postData['likedBy'] ?? []);
      final isLiked = likedBy.contains(userId);

      if (isLiked) {
        likedBy.remove(userId);
        await _firestore.collection('posts').doc(postId).update({
          'likedBy': likedBy,
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        likedBy.add(userId);
        await _firestore.collection('posts').doc(postId).update({
          'likedBy': likedBy,
          'likeCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      print('Error toggling like: $e');
      rethrow;
    }
  }

  /// Report a post as inaccurate
  Future<void> reportInaccurate(String postId, String userId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return;

      final postData = postDoc.data()!;
      final reportedBy = List<String>.from(postData['reportedBy'] ?? []);
      
      // Only report once per user
      if (!reportedBy.contains(userId)) {
        reportedBy.add(userId);
        await _firestore.collection('posts').doc(postId).update({
          'reportedBy': reportedBy,
          'inaccuracyReports': FieldValue.increment(1),
        });
      }
    } catch (e) {
      print('Error reporting inaccurate: $e');
      rethrow;
    }
  }

  // User Updates
  Future<void> updateUser(User user) async {
    try {
      await _firestore.collection('users').doc(user.id).update(user.toMap());
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  // Comments Collection
  Stream<List<Comment>> getCommentsStream(String postId) {
    print('Getting comments stream for post: $postId');
    
    return _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .snapshots()
        .map((snapshot) {
          print('Comments snapshot received: ${snapshot.docs.length} documents');
          
          if (snapshot.docs.isEmpty) {
            print('No comments found for post: $postId');
            return <Comment>[];
          }
          
          final comments = <Comment>[];
          for (var doc in snapshot.docs) {
            try {
              print('Processing comment document: ${doc.id}');
              final comment = Comment.fromMap(doc.data());
              comments.add(comment);
            } catch (e) {
              print('Error parsing comment ${doc.id}: $e');
            }
          }
          
          // Sort by createdAt in memory (oldest first)
          comments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          
          print('Returning ${comments.length} parsed comments');
          return comments;
        });
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
      // Federal Territory - Kuala Lumpur
      District(id: 'kl_bukit_bintang', name: 'Bukit Bintang', latitude: 3.1486, longitude: 101.7110, state: 'Kuala Lumpur'),
      District(id: 'kl_klcc', name: 'KLCC', latitude: 3.1570, longitude: 101.7120, state: 'Kuala Lumpur'),
      District(id: 'kl_bangsar', name: 'Bangsar', latitude: 3.1290, longitude: 101.6710, state: 'Kuala Lumpur'),
      District(id: 'kl_cheras', name: 'Cheras', latitude: 3.0930, longitude: 101.7380, state: 'Kuala Lumpur'),
      District(id: 'kl_ampang', name: 'Ampang', latitude: 3.1486, longitude: 101.7611, state: 'Kuala Lumpur'),
      District(id: 'kl_bukit_jalil', name: 'Bukit Jalil', latitude: 3.0643, longitude: 101.6995, state: 'Kuala Lumpur'),
      District(id: 'kl_sungai_besi', name: 'Sungai Besi', latitude: 3.0833, longitude: 101.7000, state: 'Kuala Lumpur'),
      District(id: 'kl_sentul', name: 'Sentul', latitude: 3.1867, longitude: 101.6900, state: 'Kuala Lumpur'),
      District(id: 'kl_wangsa_maju', name: 'Wangsa Maju', latitude: 3.2000, longitude: 101.7333, state: 'Kuala Lumpur'),
      District(id: 'kl_setapak', name: 'Setapak', latitude: 3.2000, longitude: 101.7167, state: 'Kuala Lumpur'),
      District(id: 'kl_kepong', name: 'Kepong', latitude: 3.2167, longitude: 101.6333, state: 'Kuala Lumpur'),
      District(id: 'kl_damansara', name: 'Damansara', latitude: 3.1500, longitude: 101.6167, state: 'Kuala Lumpur'),
      
      // Federal Territory - Putrajaya
      District(id: 'putrajaya', name: 'Putrajaya', latitude: 2.9264, longitude: 101.6964, state: 'Putrajaya'),
      
      // Federal Territory - Labuan
      District(id: 'labuan', name: 'Labuan', latitude: 5.2767, longitude: 115.2417, state: 'Labuan'),
      
      // Selangor
      District(id: 'sel_petaling_jaya', name: 'Petaling Jaya', latitude: 3.1073, longitude: 101.6067, state: 'Selangor'),
      District(id: 'sel_subang_jaya', name: 'Subang Jaya', latitude: 3.0435, longitude: 101.5874, state: 'Selangor'),
      District(id: 'sel_shah_alam', name: 'Shah Alam', latitude: 3.0733, longitude: 101.5185, state: 'Selangor'),
      District(id: 'sel_klang', name: 'Klang', latitude: 3.0333, longitude: 101.4500, state: 'Selangor'),
      District(id: 'sel_kajang', name: 'Kajang', latitude: 2.9927, longitude: 101.7900, state: 'Selangor'),
      District(id: 'sel_puchong', name: 'Puchong', latitude: 3.0167, longitude: 101.6167, state: 'Selangor'),
      District(id: 'sel_serdang', name: 'Serdang', latitude: 3.0167, longitude: 101.7000, state: 'Selangor'),
      District(id: 'sel_rawang', name: 'Rawang', latitude: 3.3167, longitude: 101.5833, state: 'Selangor'),
      District(id: 'sel_selayang', name: 'Selayang', latitude: 3.2333, longitude: 101.6500, state: 'Selangor'),
      District(id: 'sel_banting', name: 'Banting', latitude: 2.8167, longitude: 101.5000, state: 'Selangor'),
      District(id: 'sel_kuala_selangor', name: 'Kuala Selangor', latitude: 3.3500, longitude: 101.2500, state: 'Selangor'),
      District(id: 'sel_sabak_bernam', name: 'Sabak Bernam', latitude: 3.7667, longitude: 100.9833, state: 'Selangor'),
      
      // Johor
      District(id: 'johor_johor_bahru', name: 'Johor Bahru', latitude: 1.4927, longitude: 103.7414, state: 'Johor'),
      District(id: 'johor_skudai', name: 'Skudai', latitude: 1.5333, longitude: 103.6667, state: 'Johor'),
      District(id: 'johor_iskandar_puteri', name: 'Iskandar Puteri', latitude: 1.4277, longitude: 103.6520, state: 'Johor'),
      District(id: 'johor_pasir_gudang', name: 'Pasir Gudang', latitude: 1.4667, longitude: 103.9000, state: 'Johor'),
      District(id: 'johor_kulai', name: 'Kulai', latitude: 1.6667, longitude: 103.6000, state: 'Johor'),
      District(id: 'johor_batu_pahat', name: 'Batu Pahat', latitude: 1.8500, longitude: 102.9333, state: 'Johor'),
      District(id: 'johor_muar', name: 'Muar', latitude: 2.0500, longitude: 102.5667, state: 'Johor'),
      District(id: 'johor_segamat', name: 'Segamat', latitude: 2.5000, longitude: 102.8167, state: 'Johor'),
      District(id: 'johor_kluang', name: 'Kluang', latitude: 2.0333, longitude: 103.3167, state: 'Johor'),
      District(id: 'johor_pontian', name: 'Pontian', latitude: 1.4833, longitude: 103.3833, state: 'Johor'),
      District(id: 'johor_tangkak', name: 'Tangkak', latitude: 2.2667, longitude: 102.5500, state: 'Johor'),
      District(id: 'johor_mersing', name: 'Mersing', latitude: 2.4333, longitude: 103.8333, state: 'Johor'),
      
      // Penang
      District(id: 'pen_georgetown', name: 'Georgetown', latitude: 5.4141, longitude: 100.3288, state: 'Penang'),
      District(id: 'pen_bayan_lepas', name: 'Bayan Lepas', latitude: 5.2967, longitude: 100.2650, state: 'Penang'),
      District(id: 'pen_butterworth', name: 'Butterworth', latitude: 5.4145, longitude: 100.3635, state: 'Penang'),
      District(id: 'pen_bukit_mertajam', name: 'Bukit Mertajam', latitude: 5.3667, longitude: 100.4667, state: 'Penang'),
      District(id: 'pen_nibong_tebal', name: 'Nibong Tebal', latitude: 5.1667, longitude: 100.4833, state: 'Penang'),
      District(id: 'pen_kepala_batas', name: 'Kepala Batas', latitude: 5.5167, longitude: 100.4167, state: 'Penang'),
      District(id: 'pen_teluk_bahang', name: 'Teluk Bahang', latitude: 5.4500, longitude: 100.2167, state: 'Penang'),
      
      // Perak
      District(id: 'perak_ipoh', name: 'Ipoh', latitude: 4.5975, longitude: 101.0901, state: 'Perak'),
      District(id: 'perak_taiping', name: 'Taiping', latitude: 4.8500, longitude: 100.7333, state: 'Perak'),
      District(id: 'perak_teluk_intan', name: 'Teluk Intan', latitude: 4.0167, longitude: 101.0167, state: 'Perak'),
      District(id: 'perak_kampar', name: 'Kampar', latitude: 4.3000, longitude: 101.1500, state: 'Perak'),
      District(id: 'perak_batu_gajah', name: 'Batu Gajah', latitude: 4.4667, longitude: 101.0500, state: 'Perak'),
      District(id: 'perak_sitiawan', name: 'Sitiawan', latitude: 4.2167, longitude: 100.7000, state: 'Perak'),
      District(id: 'perak_lumut', name: 'Lumut', latitude: 4.2333, longitude: 100.6333, state: 'Perak'),
      District(id: 'perak_parit_buntar', name: 'Parit Buntar', latitude: 5.1167, longitude: 100.4833, state: 'Perak'),
      District(id: 'perak_tapah', name: 'Tapah', latitude: 4.2000, longitude: 101.2667, state: 'Perak'),
      District(id: 'perak_gerik', name: 'Gerik', latitude: 5.4167, longitude: 101.1333, state: 'Perak'),
      
      // Kedah
      District(id: 'kedah_alor_setar', name: 'Alor Setar', latitude: 6.1167, longitude: 100.3667, state: 'Kedah'),
      District(id: 'kedah_sungai_petani', name: 'Sungai Petani', latitude: 5.6500, longitude: 100.4833, state: 'Kedah'),
      District(id: 'kedah_kulim', name: 'Kulim', latitude: 5.3667, longitude: 100.5500, state: 'Kedah'),
      District(id: 'kedah_jitra', name: 'Jitra', latitude: 6.2667, longitude: 100.4167, state: 'Kedah'),
      District(id: 'kedah_kuah', name: 'Kuah', latitude: 6.3167, longitude: 99.8500, state: 'Kedah'),
      District(id: 'kedah_bandar_baharu', name: 'Bandar Baharu', latitude: 5.1167, longitude: 100.4833, state: 'Kedah'),
      District(id: 'kedah_baling', name: 'Baling', latitude: 5.6667, longitude: 100.9167, state: 'Kedah'),
      District(id: 'kedah_pendang', name: 'Pendang', latitude: 6.0000, longitude: 100.4667, state: 'Kedah'),
      
      // Kelantan
      District(id: 'kel_kota_bharu', name: 'Kota Bharu', latitude: 6.1333, longitude: 102.2500, state: 'Kelantan'),
      District(id: 'kel_pasir_mas', name: 'Pasir Mas', latitude: 6.0500, longitude: 102.1333, state: 'Kelantan'),
      District(id: 'kel_tumpat', name: 'Tumpat', latitude: 6.2000, longitude: 102.1667, state: 'Kelantan'),
      District(id: 'kel_bachok', name: 'Bachok', latitude: 6.0500, longitude: 102.4000, state: 'Kelantan'),
      District(id: 'kel_pasir_puteh', name: 'Pasir Puteh', latitude: 5.8333, longitude: 102.4000, state: 'Kelantan'),
      District(id: 'kel_tanah_merah', name: 'Tanah Merah', latitude: 5.8000, longitude: 102.1500, state: 'Kelantan'),
      District(id: 'kel_machang', name: 'Machang', latitude: 5.7667, longitude: 102.2167, state: 'Kelantan'),
      District(id: 'kel_gua_musang', name: 'Gua Musang', latitude: 4.8833, longitude: 101.9667, state: 'Kelantan'),
      
      // Terengganu
      District(id: 'ter_kuala_terengganu', name: 'Kuala Terengganu', latitude: 5.3333, longitude: 103.1333, state: 'Terengganu'),
      District(id: 'ter_kemaman', name: 'Kemaman', latitude: 4.2333, longitude: 103.4167, state: 'Terengganu'),
      District(id: 'ter_dungun', name: 'Dungun', latitude: 4.7667, longitude: 103.4167, state: 'Terengganu'),
      District(id: 'ter_marang', name: 'Marang', latitude: 5.2167, longitude: 103.2000, state: 'Terengganu'),
      District(id: 'ter_hulu_terengganu', name: 'Hulu Terengganu', latitude: 5.0833, longitude: 102.8833, state: 'Terengganu'),
      District(id: 'ter_besut', name: 'Besut', latitude: 5.8333, longitude: 102.5500, state: 'Terengganu'),
      District(id: 'ter_setiu', name: 'Setiu', latitude: 5.6167, longitude: 102.7167, state: 'Terengganu'),
      
      // Pahang
      District(id: 'pahang_kuantan', name: 'Kuantan', latitude: 3.8167, longitude: 103.3333, state: 'Pahang'),
      District(id: 'pahang_temerloh', name: 'Temerloh', latitude: 3.4500, longitude: 102.4167, state: 'Pahang'),
      District(id: 'pahang_bentong', name: 'Bentong', latitude: 3.5167, longitude: 101.9167, state: 'Pahang'),
      District(id: 'pahang_raub', name: 'Raub', latitude: 3.8000, longitude: 101.8500, state: 'Pahang'),
      District(id: 'pahang_mentakab', name: 'Mentakab', latitude: 3.4833, longitude: 102.3500, state: 'Pahang'),
      District(id: 'pahang_pekan', name: 'Pekan', latitude: 3.5000, longitude: 103.4000, state: 'Pahang'),
      District(id: 'pahang_rompin', name: 'Rompin', latitude: 2.7167, longitude: 103.4833, state: 'Pahang'),
      District(id: 'pahang_cameron_highlands', name: 'Cameron Highlands', latitude: 4.4833, longitude: 101.3833, state: 'Pahang'),
      District(id: 'pahang_genting_highlands', name: 'Genting Highlands', latitude: 3.4167, longitude: 101.8000, state: 'Pahang'),
      District(id: 'pahang_lipez', name: 'Lipez', latitude: 3.0167, longitude: 102.0167, state: 'Pahang'),
      
      // Negeri Sembilan
      District(id: 'ns_seremban', name: 'Seremban', latitude: 2.7167, longitude: 101.9333, state: 'Negeri Sembilan'),
      District(id: 'ns_port_dickson', name: 'Port Dickson', latitude: 2.5167, longitude: 101.8000, state: 'Negeri Sembilan'),
      District(id: 'ns_nilai', name: 'Nilai', latitude: 2.8167, longitude: 101.8000, state: 'Negeri Sembilan'),
      District(id: 'ns_tampin', name: 'Tampin', latitude: 2.4667, longitude: 102.2333, state: 'Negeri Sembilan'),
      District(id: 'ns_kuala_pilah', name: 'Kuala Pilah', latitude: 2.7333, longitude: 102.2500, state: 'Negeri Sembilan'),
      District(id: 'ns_jempol', name: 'Jempol', latitude: 2.9000, longitude: 102.4167, state: 'Negeri Sembilan'),
      District(id: 'ns_jelebu', name: 'Jelebu', latitude: 2.9333, longitude: 102.0667, state: 'Negeri Sembilan'),
      
      // Malacca
      District(id: 'melaka_melaka_city', name: 'Malacca City', latitude: 2.1896, longitude: 102.2501, state: 'Malacca'),
      District(id: 'melaka_alor_gajah', name: 'Alor Gajah', latitude: 2.3833, longitude: 102.2167, state: 'Malacca'),
      District(id: 'melaka_jasin', name: 'Jasin', latitude: 2.3167, longitude: 102.4333, state: 'Malacca'),
      District(id: 'melaka_masjid_tanah', name: 'Masjid Tanah', latitude: 2.3500, longitude: 102.1167, state: 'Malacca'),
      
      // Perlis
      District(id: 'perlis_kangar', name: 'Kangar', latitude: 6.4333, longitude: 100.2000, state: 'Perlis'),
      District(id: 'perlis_arau', name: 'Arau', latitude: 6.4333, longitude: 100.2667, state: 'Perlis'),
      District(id: 'perlis_kuala_perlis', name: 'Kuala Perlis', latitude: 6.4000, longitude: 100.1333, state: 'Perlis'),
      
      // Sabah
      District(id: 'sabah_kota_kinabalu', name: 'Kota Kinabalu', latitude: 5.9804, longitude: 116.0735, state: 'Sabah'),
      District(id: 'sabah_sandakan', name: 'Sandakan', latitude: 5.8388, longitude: 118.1173, state: 'Sabah'),
      District(id: 'sabah_tawau', name: 'Tawau', latitude: 4.2447, longitude: 117.8912, state: 'Sabah'),
      District(id: 'sabah_lahad_datu', name: 'Lahad Datu', latitude: 5.0333, longitude: 118.3167, state: 'Sabah'),
      District(id: 'sabah_keningau', name: 'Keningau', latitude: 5.3333, longitude: 116.1667, state: 'Sabah'),
      District(id: 'sabah_kudat', name: 'Kudat', latitude: 6.8833, longitude: 116.8333, state: 'Sabah'),
      District(id: 'sabah_ranau', name: 'Ranau', latitude: 6.0333, longitude: 116.6667, state: 'Sabah'),
      District(id: 'sabah_beaufort', name: 'Beaufort', latitude: 5.3500, longitude: 115.7500, state: 'Sabah'),
      District(id: 'sabah_sipitang', name: 'Sipitang', latitude: 5.0833, longitude: 115.5500, state: 'Sabah'),
      District(id: 'sabah_tenom', name: 'Tenom', latitude: 5.1167, longitude: 115.9500, state: 'Sabah'),
      District(id: 'sabah_papar', name: 'Papar', latitude: 5.7333, longitude: 115.9333, state: 'Sabah'),
      District(id: 'sabah_penampang', name: 'Penampang', latitude: 5.9167, longitude: 116.1167, state: 'Sabah'),
      District(id: 'sabah_tuaran', name: 'Tuaran', latitude: 6.1667, longitude: 116.2333, state: 'Sabah'),
      
      // Sarawak
      District(id: 'sarawak_kuching', name: 'Kuching', latitude: 1.5397, longitude: 110.3542, state: 'Sarawak'),
      District(id: 'sarawak_miri', name: 'Miri', latitude: 4.3995, longitude: 113.9914, state: 'Sarawak'),
      District(id: 'sarawak_sibu', name: 'Sibu', latitude: 2.3000, longitude: 111.8167, state: 'Sarawak'),
      District(id: 'sarawak_bintulu', name: 'Bintulu', latitude: 3.1667, longitude: 113.0333, state: 'Sarawak'),
      District(id: 'sarawak_limbang', name: 'Limbang', latitude: 4.7500, longitude: 115.0000, state: 'Sarawak'),
      District(id: 'sarawak_sri_aman', name: 'Sri Aman', latitude: 1.2333, longitude: 111.4667, state: 'Sarawak'),
      District(id: 'sarawak_sarikei', name: 'Sarikei', latitude: 2.1167, longitude: 111.5167, state: 'Sarawak'),
      District(id: 'sarawak_mukah', name: 'Mukah', latitude: 2.9000, longitude: 112.0833, state: 'Sarawak'),
      District(id: 'sarawak_marudi', name: 'Marudi', latitude: 4.1833, longitude: 114.3167, state: 'Sarawak'),
      District(id: 'sarawak_lawas', name: 'Lawas', latitude: 4.8500, longitude: 115.4000, state: 'Sarawak'),
      District(id: 'sarawak_kapit', name: 'Kapit', latitude: 2.0167, longitude: 112.9333, state: 'Sarawak'),
      District(id: 'sarawak_betong', name: 'Betong', latitude: 1.4000, longitude: 111.5167, state: 'Sarawak'),
    ];
  }
}


