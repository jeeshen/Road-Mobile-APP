import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_category.dart';

enum RiskLevel {
  low,
  medium,
  high,
  critical;

  String get displayName {
    switch (this) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.medium:
        return 'Medium';
      case RiskLevel.high:
        return 'High';
      case RiskLevel.critical:
        return 'Critical';
    }
  }

  int get colorValue {
    switch (this) {
      case RiskLevel.low:
        return 0xFF34C759; // Green
      case RiskLevel.medium:
        return 0xFFFFCC00; // Yellow
      case RiskLevel.high:
        return 0xFFFF9500; // Orange
      case RiskLevel.critical:
        return 0xFFFF3B30; // Red
    }
  }
}

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
  final List<String> likedBy;
  final double? latitude;
  final double? longitude;
  final List<String> autoTags; // AI-generated tags from NLP analysis
  final RiskLevel? riskLevel; // AI-determined risk level
  final int inaccuracyReports; // Count of users reporting this post as inaccurate
  final List<String> reportedBy; // User IDs who reported this as inaccurate
  final bool? isRoadDamage; // Detected via accelerometer
  final bool isSponsored; // Sponsored/Ad post
  final String? sponsorAdId; // Link to ad if sponsored

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
    this.likedBy = const [],
    this.latitude,
    this.longitude,
    this.autoTags = const [],
    this.riskLevel,
    this.inaccuracyReports = 0,
    this.reportedBy = const [],
    this.isRoadDamage,
    this.isSponsored = false,
    this.sponsorAdId,
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
      'likedBy': likedBy,
      'latitude': latitude,
      'longitude': longitude,
      'autoTags': autoTags,
      'riskLevel': riskLevel?.name,
      'inaccuracyReports': inaccuracyReports,
      'reportedBy': reportedBy,
      'isRoadDamage': isRoadDamage,
      'isSponsored': isSponsored,
      'sponsorAdId': sponsorAdId,
    };
  }

  factory Post.fromMap(Map<String, dynamic> map) {
    RiskLevel? riskLevel;
    if (map['riskLevel'] != null) {
      riskLevel = RiskLevel.values.firstWhere(
        (e) => e.name == map['riskLevel'],
        orElse: () => RiskLevel.low,
      );
    }

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
      likedBy: List<String>.from(map['likedBy'] ?? []),
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      autoTags: List<String>.from(map['autoTags'] ?? []),
      riskLevel: riskLevel,
      inaccuracyReports: map['inaccuracyReports'] ?? 0,
      reportedBy: List<String>.from(map['reportedBy'] ?? []),
      isRoadDamage: map['isRoadDamage'],
      isSponsored: map['isSponsored'] ?? false,
      sponsorAdId: map['sponsorAdId'],
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
    List<String>? likedBy,
    double? latitude,
    double? longitude,
    List<String>? autoTags,
    RiskLevel? riskLevel,
    int? inaccuracyReports,
    List<String>? reportedBy,
    bool? isRoadDamage,
    bool? isSponsored,
    String? sponsorAdId,
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
      likedBy: likedBy ?? this.likedBy,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      autoTags: autoTags ?? this.autoTags,
      riskLevel: riskLevel ?? this.riskLevel,
      inaccuracyReports: inaccuracyReports ?? this.inaccuracyReports,
      reportedBy: reportedBy ?? this.reportedBy,
      isRoadDamage: isRoadDamage ?? this.isRoadDamage,
      isSponsored: isSponsored ?? this.isSponsored,
      sponsorAdId: sponsorAdId ?? this.sponsorAdId,
    );
  }
}




