import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/premium_subscription.dart';

class PremiumService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  PremiumSubscription? _cachedSubscription;

  // Get user's subscription
  Future<PremiumSubscription?> getUserSubscription(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // Create default free subscription
        final subscription = PremiumSubscription(
          id: '',
          userId: userId,
          tier: SubscriptionTier.free,
          createdAt: DateTime.now(),
        );
        final docRef = await _firestore
            .collection('subscriptions')
            .add(subscription.toMap());
        await docRef.update({'id': docRef.id});
        _cachedSubscription = subscription.copyWith(id: docRef.id);
        return _cachedSubscription;
      }

      _cachedSubscription = PremiumSubscription.fromMap(snapshot.docs.first.data());
      return _cachedSubscription;
    } catch (e) {
      print('Error getting user subscription: $e');
      return null;
    }
  }

  // Check if user is premium
  Future<bool> isPremiumUser(String userId) async {
    final subscription = await getUserSubscription(userId);
    return subscription?.isPremium ?? false;
  }

  // Subscribe to premium
  Future<bool> subscribeToPremium(
    String userId, {
    required String paymentMethod,
    required double amount,
    int durationMonths = 1,
  }) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) return false;

      final now = DateTime.now();
      final endDate = DateTime(
        now.year,
        now.month + durationMonths,
        now.day,
      );

      await _firestore.collection('subscriptions').doc(subscription.id).update({
        'tier': SubscriptionTier.premium.name,
        'startDate': Timestamp.fromDate(now),
        'endDate': Timestamp.fromDate(endDate),
        'isActive': true,
        'paymentMethod': paymentMethod,
        'lastPaymentAmount': amount,
        'lastPaymentDate': Timestamp.fromDate(now),
        'autoRenew': true,
      });

      _cachedSubscription = null; // Clear cache
      return true;
    } catch (e) {
      print('Error subscribing to premium: $e');
      return false;
    }
  }

  // Cancel premium subscription
  Future<bool> cancelSubscription(String userId) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) return false;

      await _firestore.collection('subscriptions').doc(subscription.id).update({
        'isActive': false,
        'autoRenew': false,
        'cancelledAt': Timestamp.fromDate(DateTime.now()),
      });

      _cachedSubscription = null; // Clear cache
      return true;
    } catch (e) {
      print('Error cancelling subscription: $e');
      return false;
    }
  }

  // Renew subscription (auto-renew or manual)
  Future<bool> renewSubscription(
    String userId, {
    required String paymentMethod,
    required double amount,
    int durationMonths = 1,
  }) async {
    try {
      final subscription = await getUserSubscription(userId);
      if (subscription == null) return false;

      final now = DateTime.now();
      final startDate = subscription.endDate ?? now;
      final endDate = DateTime(
        startDate.year,
        startDate.month + durationMonths,
        startDate.day,
      );

      await _firestore.collection('subscriptions').doc(subscription.id).update({
        'endDate': Timestamp.fromDate(endDate),
        'isActive': true,
        'paymentMethod': paymentMethod,
        'lastPaymentAmount': amount,
        'lastPaymentDate': Timestamp.fromDate(now),
      });

      _cachedSubscription = null; // Clear cache
      return true;
    } catch (e) {
      print('Error renewing subscription: $e');
      return false;
    }
  }

  // Stream user subscription
  Stream<PremiumSubscription?> subscriptionStream(String userId) {
    return _firestore
        .collection('subscriptions')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return PremiumSubscription.fromMap(snapshot.docs.first.data());
    });
  }

  // Clear cached subscription
  void clearCache() {
    _cachedSubscription = null;
  }
}





