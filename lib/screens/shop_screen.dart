import 'package:flutter/cupertino.dart';
import '../models/character.dart';
import '../models/user.dart';
import '../services/firebase_service.dart';
import '../widgets/animated_character_marker.dart';
import 'merchant_ad_screen.dart';
import 'premium_subscription_screen.dart';
import 'ad_settings_screen.dart';

class ShopScreen extends StatefulWidget {
  final User currentUser;
  final Function(User) onCharacterSelected;

  const ShopScreen({
    super.key,
    required this.currentUser,
    required this.onCharacterSelected,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final List<Character> _characters = Character.getAllCharacters();
  String? _selectedCharacterId;
  bool _isUpdating = false;
  final Map<String, double> _baseCharacterPrices = const {
    'warrior': 4.99,
    'archer': 5.99,
    'monk': 6.49,
    'lancer': 7.49,
  };
  double _walletBalanceRM = 25.0; // Fake wallet balance in Ringgit
  int _walletCredits = 1200; // Fake credits balance
  late Set<String> _ownedCharacterIds;

  @override
  void initState() {
    super.initState();
    _selectedCharacterId = widget.currentUser.selectedCharacter;
    _ownedCharacterIds = {
      _characters.first.id,
      if (_selectedCharacterId != null) _selectedCharacterId!,
    };
  }

  Color _getColorForCharacter(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'black':
        return const Color(0xFF2C2C2C);
      case 'blue':
        return CupertinoColors.systemBlue;
      case 'red':
        return CupertinoColors.systemRed;
      case 'yellow':
        return CupertinoColors.systemYellow;
      default:
        return CupertinoColors.systemGrey;
    }
  }

  Future<void> _selectCharacter(Character character) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      final updatedUser = widget.currentUser.copyWith(
        selectedCharacter: character.id,
      );

      await _firebaseService.updateUser(updatedUser);

      setState(() {
        _selectedCharacterId = character.id;
        _isUpdating = false;
      });

      widget.onCharacterSelected(updatedUser);
    } catch (e) {
      setState(() {
        _isUpdating = false;
      });

      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to select character: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    }
  }

  bool _isOwned(Character character) {
    return _ownedCharacterIds.contains(character.id);
  }

  double _getPriceForCharacter(Character character) {
    final basePrice = _baseCharacterPrices[character.name.toLowerCase()] ?? 5.0;
    final colorAdjustment = switch (character.color.toLowerCase()) {
      'black' => 0.0,
      'blue' => 0.5,
      'red' => 0.75,
      'yellow' => 1.0,
      _ => 0.0,
    };
    return (basePrice + colorAdjustment);
  }

  int _getCreditPrice(double priceRM) => (priceRM * 100).round();

  void _handleCharacterTap(Character character) {
    if (_isOwned(character)) {
      _selectCharacter(character);
    } else {
      _showPurchaseSheet(character);
    }
  }

  void _showPurchaseSheet(Character character) {
    final priceRM = _getPriceForCharacter(character);
    final creditPrice = _getCreditPrice(priceRM);

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Unlock ${character.name} (${character.color})'),
        message: Column(
          children: [
            Text('Wallet Balance: RM ${_walletBalanceRM.toStringAsFixed(2)}'),
            Text('Credits: $_walletCredits'),
          ],
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => _attemptPurchase(character, useCredits: false),
            child: Text('Buy with RM ${priceRM.toStringAsFixed(2)}'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => _attemptPurchase(character, useCredits: true),
            child: Text('Buy with $creditPrice credits'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _attemptPurchase(
    Character character, {
    required bool useCredits,
  }) async {
    final priceRM = _getPriceForCharacter(character);
    final creditPrice = _getCreditPrice(priceRM);

    if (useCredits) {
      if (_walletCredits < creditPrice) {
        _showErrorDialog(
          'Insufficient Credits',
          'You need $creditPrice credits, but only have $_walletCredits.',
        );
        return;
      }
      setState(() {
        _walletCredits -= creditPrice;
        _ownedCharacterIds.add(character.id);
      });
    } else {
      if (_walletBalanceRM < priceRM) {
        _showErrorDialog(
          'Insufficient Balance',
          'You need RM ${priceRM.toStringAsFixed(2)}, but only have RM ${_walletBalanceRM.toStringAsFixed(2)}.',
        );
        return;
      }
      setState(() {
        _walletBalanceRM -= priceRM;
        _ownedCharacterIds.add(character.id);
      });
    }

    Navigator.pop(context);
    await _selectCharacter(character);
    _showSuccessDialog(
      'Purchase Successful',
      '${character.name} (${character.color}) unlocked!',
    );
  }

  void _fakeTopUp({double rm = 10.0, int credits = 500}) {
    setState(() {
      _walletBalanceRM += rm;
      _walletCredits += credits;
    });
  }

  void _showErrorDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('Great!'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'In-App Wallet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGreen.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RM Balance',
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'RM ${_walletBalanceRM.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Credits',
                          style: TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_walletCredits',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CupertinoButton.filled(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onPressed: () => _fakeTopUp(rm: 10, credits: 300),
                    child: const Text('Add RM10 / 300 credits'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Character Shop'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: SafeArea(
        child: _isUpdating
            ? const Center(child: CupertinoActivityIndicator())
            : CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Your Character',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Choose a character to represent you on the map',
                            style: TextStyle(
                              fontSize: 15,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildWalletCard()),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final character = _characters[index];
                        final isSelected = character.id == _selectedCharacterId;

                        final priceRM = _getPriceForCharacter(character);
                        final creditPrice = _getCreditPrice(priceRM);
                        final owned = _isOwned(character);

                        return GestureDetector(
                          onTap: () => _handleCharacterTap(character),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemBackground,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? CupertinoColors.systemBlue
                                    : CupertinoColors.separator.withValues(
                                        alpha: 0.3,
                                      ),
                                width: isSelected ? 2.5 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: CupertinoColors.systemBlue
                                            .withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                        spreadRadius: 0,
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: CupertinoColors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  children: [
                                    // Character animation area
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 16,
                                          left: 8,
                                          right: 8,
                                        ),
                                        child: Center(
                                          child: AnimatedCharacterMarker(
                                            key: ValueKey(character.id),
                                            actions: character.actions,
                                            userName: '',
                                            showName: false,
                                            enableClick: false,
                                            scale:
                                                character.name.toLowerCase() ==
                                                    'lancer'
                                                ? 1.4
                                                : 1.0,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Info section
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? CupertinoColors.systemBlue
                                                  .withValues(alpha: 0.1)
                                            : CupertinoColors.systemGrey6
                                                  .withValues(alpha: 0.5),
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(14),
                                          bottomRight: Radius.circular(14),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          Text(
                                            character.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? CupertinoColors.systemBlue
                                                  : CupertinoColors.label,
                                              letterSpacing: -0.3,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getColorForCharacter(
                                                character.color,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              character.color,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: CupertinoColors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          if (!owned)
                                            Column(
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      CupertinoIcons
                                                          .money_dollar,
                                                      size: 14,
                                                      color:
                                                          CupertinoColors.label,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'RM ${priceRM.toStringAsFixed(2)}',
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      CupertinoIcons.star_fill,
                                                      size: 13,
                                                      color: CupertinoColors
                                                          .systemYellow,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '$creditPrice credits',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: CupertinoColors
                                                            .secondaryLabel,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            )
                                          else
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: CupertinoColors
                                                    .systemGreen
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    CupertinoIcons
                                                        .check_mark_circled_solid,
                                                    size: 14,
                                                    color: CupertinoColors
                                                        .systemGreen,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      'Owned',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: CupertinoColors
                                                            .systemGreen,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                // Selected indicator
                                if (isSelected)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: CupertinoColors.systemGreen,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.checkmark,
                                        color: CupertinoColors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }, childCount: _characters.length),
                    ),
                  ),
                  // Premium & Ads Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Premium & Ads',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Premium Subscription Card
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) =>
                                      const PremiumSubscriptionScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFFFB700),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFFD700,
                                    ).withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.star_fill,
                                    color: CupertinoColors.white,
                                    size: 40,
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Upgrade to Premium',
                                          style: TextStyle(
                                            color: CupertinoColors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Ad-free experience',
                                          style: TextStyle(
                                            color: CupertinoColors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    CupertinoIcons.chevron_right,
                                    color: CupertinoColors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Ad Settings Card
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) =>
                                      const AdSettingsScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemBackground
                                    .resolveFrom(context),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: CupertinoColors.systemGrey5
                                      .resolveFrom(context),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.slider_horizontal_3,
                                    color: CupertinoColors.systemGrey
                                        .resolveFrom(context),
                                    size: 32,
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Ad Settings',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Manage ad preferences',
                                          style: TextStyle(
                                            color:
                                                CupertinoColors.secondaryLabel,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    CupertinoIcons.chevron_right,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Merchant Ads Card
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (context) =>
                                      const MerchantAdScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF007AFF),
                                    Color(0xFF5856D6),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF007AFF,
                                    ).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.chart_bar_alt_fill,
                                    color: CupertinoColors.white,
                                    size: 32,
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Merchant Ads',
                                          style: TextStyle(
                                            color: CupertinoColors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Promote your business',
                                          style: TextStyle(
                                            color: CupertinoColors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    CupertinoIcons.chevron_right,
                                    color: CupertinoColors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
                ],
              ),
      ),
    );
  }
}
