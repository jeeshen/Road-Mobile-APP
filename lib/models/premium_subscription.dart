import 'package:cloud_firestore/cloud_firestore.dart';

enum SubscriptionTier {
  free,
  premium;

  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.premium:
        return 'Premium';
    }
  }

  String get description {
    switch (this) {
      case SubscriptionTier.free:
        return 'Standard features with ads';
      case SubscriptionTier.premium:
        return 'Ad-free experience with premium features';
    }
  }

  double get monthlyPrice {
    switch (this) {
      case SubscriptionTier.free:
        return 0.0;
      case SubscriptionTier.premium:
        return 9.99;
    }
  }
}

class PremiumSubscription {
  final String id;
  final String userId;
  final SubscriptionTier tier;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? cancelledAt;
  final bool autoRenew;
  final String? paymentMethod;
  final double? lastPaymentAmount;
  final DateTime? lastPaymentDate;

  PremiumSubscription({
    required this.id,
    required this.userId,
    this.tier = SubscriptionTier.free,
    this.startDate,
    this.endDate,
    this.isActive = false,
    required this.createdAt,
    this.cancelledAt,
    this.autoRenew = true,
    this.paymentMethod,
    this.lastPaymentAmount,
    this.lastPaymentDate,
  });

  bool get isPremium =>
      tier == SubscriptionTier.premium &&
      isActive &&
      (endDate == null || DateTime.now().isBefore(endDate!));

  bool get isExpiringSoon {
    if (endDate == null || !isPremium) return false;
    final daysUntilExpiry = endDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 7 && daysUntilExpiry > 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'tier': tier.name,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'cancelledAt':
          cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null,
      'autoRenew': autoRenew,
      'paymentMethod': paymentMethod,
      'lastPaymentAmount': lastPaymentAmount,
      'lastPaymentDate': lastPaymentDate != null
          ? Timestamp.fromDate(lastPaymentDate!)
          : null,
    };
  }

  factory PremiumSubscription.fromMap(Map<String, dynamic> map) {
    return PremiumSubscription(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      tier: SubscriptionTier.values.firstWhere(
        (e) => e.name == map['tier'],
        orElse: () => SubscriptionTier.free,
      ),
      startDate:
          map['startDate'] != null ? (map['startDate'] as Timestamp).toDate() : null,
      endDate: map['endDate'] != null ? (map['endDate'] as Timestamp).toDate() : null,
      isActive: map['isActive'] ?? false,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      cancelledAt: map['cancelledAt'] != null
          ? (map['cancelledAt'] as Timestamp).toDate()
          : null,
      autoRenew: map['autoRenew'] ?? true,
      paymentMethod: map['paymentMethod'],
      lastPaymentAmount: map['lastPaymentAmount']?.toDouble(),
      lastPaymentDate: map['lastPaymentDate'] != null
          ? (map['lastPaymentDate'] as Timestamp).toDate()
          : null,
    );
  }

  PremiumSubscription copyWith({
    String? id,
    String? userId,
    SubscriptionTier? tier,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? cancelledAt,
    bool? autoRenew,
    String? paymentMethod,
    double? lastPaymentAmount,
    DateTime? lastPaymentDate,
  }) {
    return PremiumSubscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tier: tier ?? this.tier,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      autoRenew: autoRenew ?? this.autoRenew,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      lastPaymentAmount: lastPaymentAmount ?? this.lastPaymentAmount,
      lastPaymentDate: lastPaymentDate ?? this.lastPaymentDate,
    );
  }
}








