import 'package:flutter/cupertino.dart';
import '../models/premium_subscription.dart';
import '../services/premium_service.dart';
import '../services/auth_service.dart';
import 'premium_subscription_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdSettingsScreen extends StatefulWidget {
  const AdSettingsScreen({super.key});

  @override
  State<AdSettingsScreen> createState() => _AdSettingsScreenState();
}

class _AdSettingsScreenState extends State<AdSettingsScreen> {
  final PremiumService _premiumService = PremiumService();
  final AuthService _authService = AuthService();
  PremiumSubscription? _subscription;
  String? _userId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('current_user_id');
    if (_userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    final subscription = await _premiumService.getUserSubscription(_userId!);
    setState(() {
      _subscription = subscription;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = _subscription?.isPremium ?? false;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Ad Settings'),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : ListView(
                children: [
                  // Premium status card
                  _buildPremiumStatusCard(isPremium),
                  
                  // Ad preferences section
                  _buildSectionHeader('Ad Preferences'),
                  _buildSettingsGroup([
                    _buildSwitchTile(
                      'Ad-Free Mode',
                      isPremium,
                      enabled: isPremium,
                      subtitle: isPremium
                          ? 'All ads are disabled'
                          : 'Upgrade to Premium to enable',
                    ),
                  ]),
                  
                  // Current ad status
                  _buildSectionHeader('Current Ad Status'),
                  _buildSettingsGroup([
                    _buildInfoTile(
                      'Banner Ads',
                      isPremium ? '✅ Disabled' : '🔴 Enabled',
                      CupertinoIcons.rectangle_stack,
                    ),
                    _buildInfoTile(
                      'Voice Ads',
                      isPremium ? '✅ Disabled' : '🔴 Enabled',
                      CupertinoIcons.speaker_2,
                    ),
                    _buildInfoTile(
                      'Forum Sponsored Posts',
                      isPremium ? '✅ Hidden' : '🔴 Visible',
                      CupertinoIcons.doc_text,
                    ),
                    _buildInfoTile(
                      'Map Logo Ads',
                      isPremium ? '✅ Hidden' : '🔴 Visible',
                      CupertinoIcons.map,
                    ),
                    _buildInfoTile(
                      'Ad Push Notifications',
                      isPremium ? '✅ Disabled' : '🔴 Enabled',
                      CupertinoIcons.bell,
                    ),
                  ]),
                  
                  // Subscription management
                  if (!isPremium) ...[
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: CupertinoButton(
                        color: const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(12),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        onPressed: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) =>
                                  const PremiumSubscriptionScreen(),
                            ),
                          ).then((_) => _loadSubscription());
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.star_fill,
                              color: CupertinoColors.black,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Upgrade to Premium',
                              style: TextStyle(
                                color: CupertinoColors.black,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  if (isPremium) ...[
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: CupertinoButton(
                        color: CupertinoColors.systemGrey5.resolveFrom(context),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) =>
                                  const PremiumSubscriptionScreen(),
                            ),
                          ).then((_) => _loadSubscription());
                        },
                        child: const Text(
                          'Manage Subscription',
                          style: TextStyle(
                            color: CupertinoColors.label,
                          ),
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 32),
                ],
              ),
      ),
    );
  }

  Widget _buildPremiumStatusCard(bool isPremium) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isPremium
            ? const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFB700)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  CupertinoColors.systemGrey5.resolveFrom(context),
                  CupertinoColors.systemGrey4.resolveFrom(context),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isPremium ? const Color(0xFFFFD700) : CupertinoColors.systemGrey)
                .withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isPremium
                ? CupertinoIcons.star_fill
                : CupertinoIcons.star,
            size: 48,
            color: isPremium
                ? CupertinoColors.white
                : CupertinoColors.secondaryLabel,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium ? 'Premium Member' : 'Free Plan',
                  style: TextStyle(
                    color: isPremium
                        ? CupertinoColors.white
                        : CupertinoColors.label.resolveFrom(context),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPremium
                      ? 'Enjoying ad-free experience'
                      : 'Viewing ads to support the app',
                  style: TextStyle(
                    color: isPremium
                        ? CupertinoColors.white.withOpacity(0.9)
                        : CupertinoColors.secondaryLabel.resolveFrom(context),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value, {
    required bool enabled,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    color: enabled
                        ? CupertinoColors.label.resolveFrom(context)
                        : CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            onChanged: enabled ? (val) {} : null,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.systemGrey5.resolveFrom(context),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: CupertinoColors.systemGrey.resolveFrom(context),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 17),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}

