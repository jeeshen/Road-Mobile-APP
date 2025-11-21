import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ad.dart';
import '../services/ad_service.dart';
import '../services/auth_service.dart';

class TestAdCreationScreen extends StatefulWidget {
  const TestAdCreationScreen({super.key});

  @override
  State<TestAdCreationScreen> createState() => _TestAdCreationScreenState();
}

class _TestAdCreationScreenState extends State<TestAdCreationScreen> {
  final AdService _adService = AdService();
  final AuthService _authService = AuthService();
  String? _userId;
  String _status = 'Ready to create test ad...';
  List<Ad> _myAds = [];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('current_user_id');
    setState(() {
      _status = _userId != null 
          ? 'User ID: $_userId\nReady!' 
          : 'Not logged in';
    });
    if (_userId != null) {
      _loadAds();
    }
  }

  Future<void> _loadAds() async {
    if (_userId == null) return;
    
    setState(() => _status = 'Loading ads...');
    
    _adService.getMerchantAds(_userId!).listen((ads) {
      setState(() {
        _myAds = ads;
        _status = 'Found ${ads.length} ads for user $_userId';
      });
    });
  }

  Future<void> _createTestAd() async {
    if (_userId == null) {
      setState(() => _status = 'Error: Not logged in');
      return;
    }

    setState(() => _status = 'Creating test ad...');

    try {
      final user = await _authService.getUserById(_userId!);
      final userName = user?.name ?? 'Test Merchant';

      final testAd = Ad(
        id: '',
        merchantId: _userId!,
        merchantName: userName,
        type: AdType.banner,
        title: 'Test Coffee Shop',
        content: 'Best coffee in town! Come visit us today.',
        latitude: 3.1390,
        longitude: 101.6869,
        radiusKm: 2.0,
        budget: 50.0,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
        createdAt: DateTime.now(),
        merchantPhone: '+60123456789',
        merchantAddress: 'Kuala Lumpur City Center',
      );

      final adId = await _adService.createAd(testAd);
      
      setState(() => _status = 'Success! Ad created with ID: $adId');
      await _loadAds();
      
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Test Ad Creation'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _status,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: _userId != null ? _createTestAd : null,
                child: const Text('Create Test Ad'),
              ),
              const SizedBox(height: 16),
              CupertinoButton(
                onPressed: _loadAds,
                child: const Text('Refresh Ads'),
              ),
              const SizedBox(height: 16),
              const Text(
                'My Ads:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _myAds.isEmpty
                    ? const Center(child: Text('No ads yet'))
                    : ListView.builder(
                        itemCount: _myAds.length,
                        itemBuilder: (context, index) {
                          final ad = _myAds[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: CupertinoColors.systemGrey4,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ad.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('Type: ${ad.type.displayName}'),
                                Text('Status: ${ad.status.displayName}'),
                                Text('Budget: \$${ad.budget.toStringAsFixed(2)}'),
                                Text('Spent: \$${ad.spent.toStringAsFixed(2)}'),
                                Text('Impressions: ${ad.impressions}'),
                                Text('Clicks: ${ad.clicks}'),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}





