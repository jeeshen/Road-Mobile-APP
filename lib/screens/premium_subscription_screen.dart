import 'package:flutter/cupertino.dart';
import '../models/premium_subscription.dart';
import '../services/premium_service.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PremiumSubscriptionScreen extends StatefulWidget {
  const PremiumSubscriptionScreen({super.key});

  @override
  State<PremiumSubscriptionScreen> createState() =>
      _PremiumSubscriptionScreenState();
}

class _PremiumSubscriptionScreenState extends State<PremiumSubscriptionScreen> {
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
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Premium Subscription'),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : _subscription?.isPremium == true
                ? _buildPremiumView()
                : _buildUpgradeView(),
      ),
    );
  }

  Widget _buildPremiumView() {
    final daysRemaining =
        _subscription!.endDate?.difference(DateTime.now()).inDays ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Premium badge
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFFD700),
                Color(0xFFFFB700),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(
                CupertinoIcons.star_fill,
                size: 64,
                color: CupertinoColors.white,
              ),
              const SizedBox(height: 16),
              const Text(
                'Premium Member',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$daysRemaining days remaining',
                style: const TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Benefits
        _buildSectionTitle('Your Premium Benefits'),
        _buildBenefitCard('🚫', 'No Banner Ads', 'Clean, distraction-free navigation'),
        _buildBenefitCard('🔇', 'No Voice Ads', 'Silent, peaceful driving experience'),
        _buildBenefitCard(
            '📝', 'No Forum Ads', 'Ad-free community discussions'),
        _buildBenefitCard('🎯', 'No Promoted Posts', 'Only genuine content'),
        _buildBenefitCard(
            '🔔', 'No Ad Push Notifications', 'Only important alerts'),
        const SizedBox(height: 24),

        // Subscription info
        _buildSectionTitle('Subscription Details'),
        _buildInfoCard(),
        const SizedBox(height: 16),

        // Cancel button
        CupertinoButton(
          padding: const EdgeInsets.symmetric(vertical: 16),
          borderRadius: BorderRadius.circular(12),
          color: CupertinoColors.systemGrey5.resolveFrom(context),
          onPressed: _showCancelDialog,
          child: const Text(
            'Cancel Subscription',
            style: TextStyle(
              color: CupertinoColors.destructiveRed,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradeView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero section
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF007AFF),
                Color(0xFF5856D6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(
                CupertinoIcons.star_circle_fill,
                size: 80,
                color: CupertinoColors.white,
              ),
              const SizedBox(height: 16),
              const Text(
                'Upgrade to Premium',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Experience Road Mobile without any ads',
                style: TextStyle(
                  color: CupertinoColors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Pricing
        _buildSectionTitle('Pricing'),
        _buildPricingCard(
          'Monthly',
          9.99,
          'Billed monthly',
          isPopular: true,
        ),
        const SizedBox(height: 12),
        _buildPricingCard(
          '3 Months',
          24.99,
          'Save \$5 - Just \$8.33/month',
          isPopular: false,
        ),
        const SizedBox(height: 12),
        _buildPricingCard(
          'Yearly',
          89.99,
          'Save \$30 - Just \$7.50/month',
          isPopular: false,
        ),
        const SizedBox(height: 32),

        // Benefits
        _buildSectionTitle('Premium Benefits'),
        _buildBenefitCard('🚫', 'No Banner Ads', 'Clean, distraction-free navigation'),
        _buildBenefitCard('🔇', 'No Voice Ads', 'Silent, peaceful driving experience'),
        _buildBenefitCard(
            '📝', 'No Forum Ads', 'Ad-free community discussions'),
        _buildBenefitCard('🎯', 'No Promoted Posts', 'Only genuine content'),
        _buildBenefitCard(
            '🔔', 'No Ad Push Notifications', 'Only important alerts'),
        const SizedBox(height: 32),

        // Subscribe button
        CupertinoButton(
          color: const Color(0xFFFFD700),
          borderRadius: BorderRadius.circular(12),
          padding: const EdgeInsets.symmetric(vertical: 16),
          onPressed: _showPaymentSheet,
          child: const Text(
            'Subscribe Now',
            style: TextStyle(
              color: CupertinoColors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Fake payment system - Subscription will be activated immediately',
          style: TextStyle(
            fontSize: 12,
            color: CupertinoColors.systemGrey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBenefitCard(String emoji, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            CupertinoIcons.checkmark_circle_fill,
            color: CupertinoColors.systemGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard(
    String duration,
    double price,
    String subtitle, {
    required bool isPopular,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPopular
              ? const Color(0xFF007AFF)
              : CupertinoColors.systemGrey5.resolveFrom(context),
          width: isPopular ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPopular)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'POPULAR',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  duration,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildInfoRow('Status', _subscription!.isActive ? 'Active' : 'Inactive'),
          _buildInfoRow(
            'Started',
            _subscription!.startDate != null
                ? _formatDate(_subscription!.startDate!)
                : 'N/A',
          ),
          _buildInfoRow(
            'Expires',
            _subscription!.endDate != null
                ? _formatDate(_subscription!.endDate!)
                : 'N/A',
          ),
          _buildInfoRow('Auto-Renew', _subscription!.autoRenew ? 'On' : 'Off'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showPaymentSheet() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Subscribe to Premium'),
        message: const Column(
          children: [
            SizedBox(height: 16),
            Text(
              'This is a fake payment system',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your subscription will be activated immediately',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => _processPayment('Credit Card', 9.99, 1),
            child: const Text('Monthly - \$9.99'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => _processPayment('Credit Card', 24.99, 3),
            child: const Text('3 Months - \$24.99'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => _processPayment('Credit Card', 89.99, 12),
            child: const Text('Yearly - \$89.99'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _processPayment(
    String paymentMethod,
    double amount,
    int months,
  ) async {
    Navigator.pop(context);

    if (_userId == null) {
      _showErrorDialog('Please login first');
      return;
    }

    // Show loading
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CupertinoActivityIndicator(radius: 20),
      ),
    );

    final success = await _premiumService.subscribeToPremium(
      _userId!,
      paymentMethod: paymentMethod,
      amount: amount,
      durationMonths: months,
    );

    if (mounted) {
      Navigator.pop(context); // Close loading

      if (success) {
        await _loadSubscription();
        _showSuccessDialog();
      } else {
        _showErrorDialog('Failed to process payment');
      }
    }
  }

  void _showCancelDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Cancel Subscription'),
        content: const Text(
          'Are you sure you want to cancel your Premium subscription? '
          'You will lose all Premium benefits.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Premium'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              if (_userId != null) {
                await _premiumService.cancelSubscription(_userId!);
                await _loadSubscription();
                _showSuccessDialog();
              }
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: const Text('Your subscription has been updated!'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

