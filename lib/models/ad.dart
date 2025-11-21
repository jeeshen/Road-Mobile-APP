import 'package:cloud_firestore/cloud_firestore.dart';

enum AdType {
  banner,
  voice,
  mapLogo,
  forumPost;

  String get displayName {
    switch (this) {
      case AdType.banner:
        return 'Banner Ad';
      case AdType.voice:
        return 'Voice Ad';
      case AdType.mapLogo:
        return 'Map Logo';
      case AdType.forumPost:
        return 'Forum Post';
    }
  }
}

enum AdStatus {
  active,
  paused,
  completed,
  outOfBudget;

  String get displayName {
    switch (this) {
      case AdStatus.active:
        return 'Active';
      case AdStatus.paused:
        return 'Paused';
      case AdStatus.completed:
        return 'Completed';
      case AdStatus.outOfBudget:
        return 'Out of Budget';
    }
  }
}

class Ad {
  final String id;
  final String merchantId;
  final String merchantName;
  final AdType type;
  final String title;
  final String content;
  final String? imageUrl;
  final String? logoUrl;
  final String? voiceScript;
  final String? districtId; // Coverage area
  final String? state; // State coverage
  final double? latitude;
  final double? longitude;
  final double radiusKm; // Ad trigger radius in km
  final double budget;
  final double spent;
  final double costPerImpression;
  final double costPerClick;
  final DateTime startDate;
  final DateTime endDate;
  final AdStatus status;
  final int impressions;
  final int clicks;
  final DateTime createdAt;
  final String? targetUrl;
  final String? merchantPhone;
  final String? merchantAddress;

  Ad({
    required this.id,
    required this.merchantId,
    required this.merchantName,
    required this.type,
    required this.title,
    required this.content,
    this.imageUrl,
    this.logoUrl,
    this.voiceScript,
    this.districtId,
    this.state,
    this.latitude,
    this.longitude,
    this.radiusKm = 0.5,
    required this.budget,
    this.spent = 0.0,
    this.costPerImpression = 0.10,
    this.costPerClick = 0.50,
    required this.startDate,
    required this.endDate,
    this.status = AdStatus.active,
    this.impressions = 0,
    this.clicks = 0,
    required this.createdAt,
    this.targetUrl,
    this.merchantPhone,
    this.merchantAddress,
  });

  bool get isActive =>
      status == AdStatus.active &&
      DateTime.now().isAfter(startDate) &&
      DateTime.now().isBefore(endDate) &&
      spent < budget;

  double get clickThroughRate =>
      impressions > 0 ? (clicks / impressions) * 100 : 0.0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchantId': merchantId,
      'merchantName': merchantName,
      'type': type.name,
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
      'logoUrl': logoUrl,
      'voiceScript': voiceScript,
      'districtId': districtId,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
      'radiusKm': radiusKm,
      'budget': budget,
      'spent': spent,
      'costPerImpression': costPerImpression,
      'costPerClick': costPerClick,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status.name,
      'impressions': impressions,
      'clicks': clicks,
      'createdAt': Timestamp.fromDate(createdAt),
      'targetUrl': targetUrl,
      'merchantPhone': merchantPhone,
      'merchantAddress': merchantAddress,
    };
  }

  factory Ad.fromMap(Map<String, dynamic> map) {
    return Ad(
      id: map['id'] ?? '',
      merchantId: map['merchantId'] ?? '',
      merchantName: map['merchantName'] ?? '',
      type: AdType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => AdType.banner,
      ),
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'],
      logoUrl: map['logoUrl'],
      voiceScript: map['voiceScript'],
      districtId: map['districtId'],
      state: map['state'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      radiusKm: map['radiusKm']?.toDouble() ?? 0.5,
      budget: map['budget']?.toDouble() ?? 0.0,
      spent: map['spent']?.toDouble() ?? 0.0,
      costPerImpression: map['costPerImpression']?.toDouble() ?? 0.10,
      costPerClick: map['costPerClick']?.toDouble() ?? 0.50,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      status: AdStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AdStatus.active,
      ),
      impressions: map['impressions'] ?? 0,
      clicks: map['clicks'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      targetUrl: map['targetUrl'],
      merchantPhone: map['merchantPhone'],
      merchantAddress: map['merchantAddress'],
    );
  }

  Ad copyWith({
    String? id,
    String? merchantId,
    String? merchantName,
    AdType? type,
    String? title,
    String? content,
    String? imageUrl,
    String? logoUrl,
    String? voiceScript,
    String? districtId,
    String? state,
    double? latitude,
    double? longitude,
    double? radiusKm,
    double? budget,
    double? spent,
    double? costPerImpression,
    double? costPerClick,
    DateTime? startDate,
    DateTime? endDate,
    AdStatus? status,
    int? impressions,
    int? clicks,
    DateTime? createdAt,
    String? targetUrl,
    String? merchantPhone,
    String? merchantAddress,
  }) {
    return Ad(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      merchantName: merchantName ?? this.merchantName,
      type: type ?? this.type,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      voiceScript: voiceScript ?? this.voiceScript,
      districtId: districtId ?? this.districtId,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusKm: radiusKm ?? this.radiusKm,
      budget: budget ?? this.budget,
      spent: spent ?? this.spent,
      costPerImpression: costPerImpression ?? this.costPerImpression,
      costPerClick: costPerClick ?? this.costPerClick,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      impressions: impressions ?? this.impressions,
      clicks: clicks ?? this.clicks,
      createdAt: createdAt ?? this.createdAt,
      targetUrl: targetUrl ?? this.targetUrl,
      merchantPhone: merchantPhone ?? this.merchantPhone,
      merchantAddress: merchantAddress ?? this.merchantAddress,
    );
  }
}





