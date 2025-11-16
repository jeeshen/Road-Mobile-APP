import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_category.dart';

class Post {
  final String id;
  final String districtId;
  final String userId;
  final String username;
  final String title;
  final String content;
  final PostCategory category;
  final List<String> mediaUrls;
  final DateTime createdAt;
  final bool isPinned;
  final int commentCount;
  final int likeCount;
  final double? latitude;
  final double? longitude;

  Post({
    required this.id,
    required this.districtId,
    required this.userId,
    required this.username,
    required this.title,
    required this.content,
    required this.category,
    required this.mediaUrls,
    required this.createdAt,
    this.isPinned = false,
    this.commentCount = 0,
    this.likeCount = 0,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'districtId': districtId,
      'userId': userId,
      'username': username,
      'title': title,
      'content': content,
      'category': category.toJson(),
      'mediaUrls': mediaUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'isPinned': isPinned,
      'commentCount': commentCount,
      'likeCount': likeCount,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: map['id'] ?? '',
      districtId: map['districtId'] ?? '',
      userId: map['userId'] ?? '',
      username: map['username'] ?? 'Anonymous',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      category: PostCategoryExtension.fromJson(map['category'] ?? 'other'),
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isPinned: map['isPinned'] ?? false,
      commentCount: map['commentCount'] ?? 0,
      likeCount: map['likeCount'] ?? 0,
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
    );
  }

  Post copyWith({
    String? id,
    String? districtId,
    String? userId,
    String? username,
    String? title,
    String? content,
    PostCategory? category,
    List<String>? mediaUrls,
    DateTime? createdAt,
    bool? isPinned,
    int? commentCount,
    int? likeCount,
    double? latitude,
    double? longitude,
  }) {
    return Post(
      id: id ?? this.id,
      districtId: districtId ?? this.districtId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      createdAt: createdAt ?? this.createdAt,
      isPinned: isPinned ?? this.isPinned,
      commentCount: commentCount ?? this.commentCount,
      likeCount: likeCount ?? this.likeCount,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}




