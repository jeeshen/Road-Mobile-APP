import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ad.dart';
import '../models/merchant_wallet.dart';
import 'dart:math';

class AdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Set<String> _shownAds = {}; // Track shown ads this session
  final Map<String, DateTime> _lastAdTime = {}; // Track ad cooldown

  // Get nearby active ads based on user location
  Future<List<Ad>> getNearbyAds(
    double userLat,
    double userLng, {
    AdType? type,
    String? districtId,
  }) async {
    try {
      print('AdService: Getting nearby ads for location ($userLat, $userLng)');
      print('AdService: Filtering by type: ${type?.name ?? "all"}, district: ${districtId ?? "any"}');
      
      // First, get ALL active ads to see what exists
      final allActiveQuery = _firestore.collection('ads').where('status', isEqualTo: 'active');
      final allActiveSnapshot = await allActiveQuery.get();
      print('AdService: Total active ads in database: ${allActiveSnapshot.docs.length}');
      
      // Show all active ads for debugging
      for (var doc in allActiveSnapshot.docs) {
        final data = doc.data();
        print('  - ${data['title']}: type=${data['type']}, district=${data['districtId']}, status=${data['status']}');
      }
      
      // Now apply filters
      Query query = _firestore.collection('ads').where('status', isEqualTo: 'active');

      if (type != null) {
        query = query.where('type', isEqualTo: type.name);
        print('AdService: Added type filter: ${type.name}');
      }

      if (districtId != null) {
        query = query.where('districtId', isEqualTo: districtId);
        print('AdService: Added district filter: $districtId');
      }

      final snapshot = await query.get();
      print('AdService: After filtering: ${snapshot.docs.length} ads match criteria');
      
      final ads = snapshot.docs
          .map((doc) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              print('AdService: Processing ad ${doc.id}: ${data['title']} at (${data['latitude']}, ${data['longitude']})');
              return Ad.fromMap(data);
            } catch (e) {
              print('AdService: Error parsing ad ${doc.id}: $e');
              return null;
            }
          })
          .whereType<Ad>()
          .where((ad) {
        // Check if ad is active and within budget
        if (!ad.isActive) {
          print('AdService: Ad ${ad.id} is not active (status: ${ad.status}, spent: ${ad.spent}/${ad.budget}, date range: ${ad.startDate} - ${ad.endDate})');
          return false;
        }

        // Check if ad has location targeting
        if (ad.latitude != null && ad.longitude != null) {
          final distance = _calculateDistance(
            userLat,
            userLng,
            ad.latitude!,
            ad.longitude!,
          );
          final isWithinRange = distance <= ad.radiusKm;
          print('AdService: Ad ${ad.id} distance: ${distance.toStringAsFixed(2)}km, radius: ${ad.radiusKm}km, within range: $isWithinRange');
          return isWithinRange;
        }

        print('AdService: Ad ${ad.id} has no location targeting, including it');
        return true; // Include ads without location targeting
      }).toList();

      print('AdService: Returning ${ads.length} nearby ads');
      return ads;
    } catch (e) {
      print('Error getting nearby ads: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  // Get a random ad that hasn't been shown recently
  Ad? getNextAd(List<Ad> availableAds, AdType type) {
    final now = DateTime.now();
    final filteredAds = availableAds.where((ad) {
      if (ad.type != type) return false;

      // Check cooldown (don't show same ad within 5 minutes)
      final lastShown = _lastAdTime[ad.id];
      if (lastShown != null &&
          now.difference(lastShown).inMinutes < 5) {
        return false;
      }

      return true;
    }).toList();

    if (filteredAds.isEmpty) return null;

    // Return random ad
    final random = Random();
    return filteredAds[random.nextInt(filteredAds.length)];
  }

  // Record ad impression
  Future<void> recordImpression(String adId) async {
    try {
      final adRef = _firestore.collection('ads').doc(adId);
      final adDoc = await adRef.get();

      if (!adDoc.exists) return;

      final ad = Ad.fromMap(adDoc.data() as Map<String, dynamic>);
      final newSpent = ad.spent + ad.costPerImpression;
      final newImpressions = ad.impressions + 1;

      // Update ad
      await adRef.update({
        'impressions': newImpressions,
        'spent': newSpent,
        'status': newSpent >= ad.budget ? AdStatus.outOfBudget.name : ad.status.name,
      });

      // Track locally
      _lastAdTime[adId] = DateTime.now();
      _shownAds.add(adId);

      print('Recorded impression for ad $adId');
    } catch (e) {
      print('Error recording impression: $e');
    }
  }

  // Record ad click
  Future<void> recordClick(String adId) async {
    try {
      final adRef = _firestore.collection('ads').doc(adId);
      final adDoc = await adRef.get();

      if (!adDoc.exists) return;

      final ad = Ad.fromMap(adDoc.data() as Map<String, dynamic>);
      final newSpent = ad.spent + ad.costPerClick;
      final newClicks = ad.clicks + 1;

      // Update ad
      await adRef.update({
        'clicks': newClicks,
        'spent': newSpent,
        'status': newSpent >= ad.budget ? AdStatus.outOfBudget.name : ad.status.name,
      });

      print('Recorded click for ad $adId');
    } catch (e) {
      print('Error recording click: $e');
    }
  }

  // Create new ad
  Future<String> createAd(Ad ad) async {
    try {
      print('AdService: Creating ad for merchant ${ad.merchantId}');
      print('AdService: Ad type: ${ad.type.name}, Title: ${ad.title}');
      print('AdService: Location: ${ad.latitude}, ${ad.longitude}');
      print('AdService: Budget: \$${ad.budget}, Radius: ${ad.radiusKm}km');
      
      final adData = ad.toMap();
      print('AdService: Ad data to save: $adData');
      
      final docRef = await _firestore.collection('ads').add(adData);
      await docRef.update({'id': docRef.id});
      
      print('AdService: Ad created successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error creating ad: $e');
      rethrow;
    }
  }

  // Get merchant's ads
  Stream<List<Ad>> getMerchantAds(String merchantId) {
    print('AdService: Getting ads for merchant $merchantId');
    return _firestore
        .collection('ads')
        .where('merchantId', isEqualTo: merchantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          print('AdService: Received ${snapshot.docs.length} ads for merchant $merchantId');
          return snapshot.docs.map((doc) {
            final data = doc.data();
            print('AdService: Ad data: ${data['title']} - Status: ${data['status']}');
            return Ad.fromMap(data);
          }).toList();
        });
  }

  // Update ad status
  Future<void> updateAdStatus(String adId, AdStatus status) async {
    try {
      await _firestore.collection('ads').doc(adId).update({
        'status': status.name,
      });
    } catch (e) {
      print('Error updating ad status: $e');
      rethrow;
    }
  }

  // Get all active ads for admin
  Stream<List<Ad>> getAllActiveAds() {
    return _firestore
        .collection('ads')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Ad.fromMap(doc.data()))
            .toList());
  }

  // Calculate distance between two coordinates
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  // Get merchant wallet
  Future<MerchantWallet?> getMerchantWallet(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('merchant_wallets')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return MerchantWallet.fromMap(snapshot.docs.first.data());
    } catch (e) {
      print('Error getting merchant wallet: $e');
      return null;
    }
  }

  // Create or update merchant wallet
  Future<void> updateWalletBalance(String userId, double amount) async {
    try {
      final wallet = await getMerchantWallet(userId);
      final now = DateTime.now();

      if (wallet == null) {
        // Create new wallet
        final newWallet = MerchantWallet(
          id: '',
          userId: userId,
          balance: amount,
          createdAt: now,
          updatedAt: now,
        );
        final docRef = await _firestore
            .collection('merchant_wallets')
            .add(newWallet.toMap());
        await docRef.update({'id': docRef.id});
      } else {
        // Update existing wallet
        await _firestore
            .collection('merchant_wallets')
            .doc(wallet.id)
            .update({
          'balance': wallet.balance + amount,
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      // Record transaction
      final transaction = WalletTransaction(
        id: '',
        merchantId: userId,
        type: amount > 0 ? TransactionType.deposit : TransactionType.adSpend,
        amount: amount.abs(),
        balanceAfter: (wallet?.balance ?? 0) + amount,
        createdAt: now,
      );

      final txRef = await _firestore
          .collection('wallet_transactions')
          .add(transaction.toMap());
      await txRef.update({'id': txRef.id});
    } catch (e) {
      print('Error updating wallet balance: $e');
      rethrow;
    }
  }

  // Get wallet transactions
  Stream<List<WalletTransaction>> getWalletTransactions(String merchantId) {
    return _firestore
        .collection('wallet_transactions')
        .where('merchantId', isEqualTo: merchantId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WalletTransaction.fromMap(doc.data()))
            .toList());
  }
}

