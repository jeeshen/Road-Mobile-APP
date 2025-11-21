import 'package:flutter/cupertino.dart';
import '../models/ad.dart';
import '../models/merchant_wallet.dart';
import '../models/district.dart';
import '../services/ad_service.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ad_location_picker_screen.dart';
import 'package:latlong2/latlong.dart';

class MerchantAdScreen extends StatefulWidget {
  const MerchantAdScreen({super.key});

  @override
  State<MerchantAdScreen> createState() => _MerchantAdScreenState();
}

class _MerchantAdScreenState extends State<MerchantAdScreen> {
  final AdService _adService = AdService();
  MerchantWallet? _wallet;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('current_user_id');
    if (_userId == null) {
      return;
    }

    final wallet = await _adService.getMerchantWallet(_userId!);
    setState(() {
      _wallet = wallet;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text('Merchant Ads'),
        ),
        child: Center(child: Text('Please login')),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Merchant Ads'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.plus_circle_fill),
          onPressed: () => _showCreateAdSheet(context),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Wallet balance card
            _buildWalletCard(),
            const SizedBox(height: 8),
            // Ads list
            Expanded(
              child: _userId == null
                  ? const Center(child: Text('Please login'))
                  : StreamBuilder<List<Ad>>(
                      stream: _adService.getMerchantAds(_userId!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CupertinoActivityIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  CupertinoIcons.exclamationmark_triangle,
                                  size: 60,
                                  color: CupertinoColors.systemRed,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading ads',
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${snapshot.error}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: CupertinoColors.systemGrey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        final ads = snapshot.data ?? [];
                        print('Merchant ads loaded: ${ads.length} ads for user $_userId');
                        
                        if (ads.isEmpty) {
                          return _buildEmptyState();
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: ads.length,
                          itemBuilder: (context, index) => _buildAdCard(ads[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard() {
    return Container(
      margin: const EdgeInsets.all(16),
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
            color: const Color(0xFF007AFF).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ad Wallet Balance',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '\$${(_wallet?.balance ?? 0.0).toStringAsFixed(2)}',
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: _showAddFundsSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: CupertinoColors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '+ Add Funds',
                style: TextStyle(
                  color: Color(0xFF007AFF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdCard(Ad ad) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(ad.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ad.status.displayName,
                  style: TextStyle(
                    color: _getStatusColor(ad.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                ad.type.displayName,
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ad.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ad.content,
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('👁️', ad.impressions.toString()),
              const SizedBox(width: 16),
              _buildStatItem('👆', ad.clicks.toString()),
              const SizedBox(width: 16),
              _buildStatItem('📊', '${ad.clickThroughRate.toStringAsFixed(1)}%'),
              const Spacer(),
              Text(
                '\$${ad.spent.toStringAsFixed(2)} / \$${ad.budget.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            CupertinoIcons.chart_bar_alt_fill,
            size: 64,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No Ads Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your first ad to reach more customers',
            style: TextStyle(
              color: CupertinoColors.systemGrey,
            ),
          ),
          const SizedBox(height: 24),
          CupertinoButton.filled(
            onPressed: () => _showCreateAdSheet(context),
            child: const Text('Create Ad'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(AdStatus status) {
    switch (status) {
      case AdStatus.active:
        return CupertinoColors.systemGreen;
      case AdStatus.paused:
        return CupertinoColors.systemOrange;
      case AdStatus.completed:
        return CupertinoColors.systemGrey;
      case AdStatus.outOfBudget:
        return CupertinoColors.systemRed;
    }
  }

  void _showAddFundsSheet() {
    final amountController = TextEditingController();
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Add Funds to Wallet'),
        message: Column(
          children: [
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: amountController,
              placeholder: 'Enter amount',
              keyboardType: TextInputType.number,
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('\$'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fake payment - Any amount will be added',
              style: TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ],
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0 && _userId != null) {
                await _adService.updateWalletBalance(_userId!, amount);
                await _loadWallet();
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSuccessDialog('Funds added successfully!');
                }
              }
            },
            child: const Text('Add Funds'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _showCreateAdSheet(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => CreateAdScreen(wallet: _wallet),
      ),
    ).then((_) => _loadWallet());
  }

  void _showSuccessDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
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

class CreateAdScreen extends StatefulWidget {
  final MerchantWallet? wallet;

  const CreateAdScreen({super.key, this.wallet});

  @override
  State<CreateAdScreen> createState() => _CreateAdScreenState();
}

class _CreateAdScreenState extends State<CreateAdScreen> {
  final AdService _adService = AdService();
  final AuthService _authService = AuthService();

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _budgetController = TextEditingController();
  final _voiceScriptController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  AdType _selectedType = AdType.banner;
  District? _selectedDistrict;
  List<District> _districts = [];
  int _durationDays = 7;
  String? _userId;
  String _userName = 'Merchant';
  LatLng? _selectedLocation;
  double _radiusKm = 0.5;
  bool _isLoadingDistricts = true;

  @override
  void initState() {
    super.initState();
    _loadUserAndDistricts();
  }

  Future<void> _loadUserAndDistricts() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('current_user_id');
    if (_userId != null) {
      final user = await _authService.getUserById(_userId!);
      if (user != null) {
        setState(() => _userName = user.name);
      }
    }
    
    // Load actual districts from Firebase
    final firebaseService = FirebaseService();
    final districts = await firebaseService.getDistricts();
    
    // If no districts found, initialize them first
    if (districts.isEmpty) {
      await firebaseService.initializeDistricts();
      final newDistricts = await firebaseService.getDistricts();
      setState(() {
        _districts = newDistricts;
        _isLoadingDistricts = false;
      });
    } else {
      setState(() {
        _districts = districts;
        _isLoadingDistricts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Create Ad'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _createAd,
          child: const Text('Create'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection('Ad Type', _buildTypeSelector()),
            _buildSection('Title', _buildTextField(_titleController, 'Ad title')),
            _buildSection(
                'Content', _buildTextField(_contentController, 'Ad description', maxLines: 3)),
            if (_selectedType == AdType.voice)
              _buildSection(
                  'Voice Script',
                  _buildTextField(_voiceScriptController,
                      'What will be spoken (3-5 seconds)',
                      maxLines: 2)),
            _buildSection('Ad Location', _buildLocationPicker()),
            _buildSection('Trigger Radius', _buildRadiusPicker()),
            _buildSection('Coverage Area (Optional)', _buildDistrictPicker()),
            _buildSection('Duration', _buildDurationPicker()),
            _buildSection('Budget', _buildTextField(_budgetController, '\$0.00')),
            _buildSection('Contact Phone (Optional)',
                _buildTextField(_phoneController, '+1234567890')),
            _buildSection('Address (Optional)',
                _buildTextField(_addressController, 'Your business address')),
            const SizedBox(height: 16),
            _buildCostEstimate(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            color: CupertinoColors.systemGrey,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: CupertinoSlidingSegmentedControl<AdType>(
        groupValue: _selectedType,
        children: {
          AdType.banner: _buildSegmentChild('📱 Banner'),
          AdType.voice: _buildSegmentChild('🔊 Voice'),
          AdType.mapLogo: _buildSegmentChild('📍 Map'),
          AdType.forumPost: _buildSegmentChild('📝 Forum'),
        },
        onValueChanged: (type) {
          if (type != null) setState(() => _selectedType = type);
        },
      ),
    );
  }

  Widget _buildSegmentChild(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String placeholder, {
    int maxLines = 1,
  }) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      maxLines: maxLines,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildLocationPicker() {
    return CupertinoButton(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF007AFF).withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      onPressed: _showLocationPicker,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              CupertinoIcons.map_pin_ellipse,
              color: CupertinoColors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tap to select on map',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007AFF),
                  ),
                ),
                if (_selectedLocation != null)
                  Text(
                    '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            _selectedLocation != null
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.chevron_right,
            color: _selectedLocation != null
                ? CupertinoColors.systemGreen
                : CupertinoColors.systemGrey,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildRadiusPicker() {
    return CupertinoButton(
      padding: const EdgeInsets.all(12),
      color: CupertinoColors.systemGrey6.resolveFrom(context),
      borderRadius: BorderRadius.circular(10),
      onPressed: _showRadiusPicker,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Trigger Radius',
                style: TextStyle(fontSize: 13, color: CupertinoColors.secondaryLabel),
              ),
              Text(
                '${_radiusKm.toStringAsFixed(1)} km',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const Icon(CupertinoIcons.chevron_right, size: 20),
        ],
      ),
    );
  }

  Widget _buildDistrictPicker() {
    return CupertinoButton(
      padding: const EdgeInsets.all(12),
      color: CupertinoColors.systemGrey6.resolveFrom(context),
      borderRadius: BorderRadius.circular(10),
      onPressed: _showDistrictPicker,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedDistrict != null 
                      ? '${_selectedDistrict!.name}, ${_selectedDistrict!.state}'
                      : 'None (location-based only)',
                  style: TextStyle(
                    fontSize: 15,
                    color: _selectedDistrict != null
                        ? CupertinoColors.label.resolveFrom(context)
                        : CupertinoColors.placeholderText.resolveFrom(context),
                  ),
                ),
                if (_isLoadingDistricts)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Loading districts...',
                      style: TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            _isLoadingDistricts 
                ? CupertinoIcons.circle_fill 
                : CupertinoIcons.chevron_right,
            size: 20,
            color: _isLoadingDistricts 
                ? CupertinoColors.systemGrey 
                : null,
          ),
        ],
      ),
    );
  }

  void _showLocationPicker() async {
    final location = await Navigator.push<LatLng>(
      context,
      CupertinoPageRoute(
        builder: (context) => AdLocationPickerScreen(
          initialLocation: _selectedLocation,
        ),
      ),
    );
    
    if (location != null) {
      setState(() => _selectedLocation = location);
    }
  }

  void _showRadiusPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoButton(
                    child: const Text('Done'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                scrollController: FixedExtentScrollController(
                  initialItem: [0.5, 1.0, 2.0, 3.0, 5.0, 10.0].indexOf(_radiusKm),
                ),
                onSelectedItemChanged: (index) {
                  setState(() => _radiusKm = [0.5, 1.0, 2.0, 3.0, 5.0, 10.0][index]);
                },
                children: const [
                  Center(child: Text('0.5 km (500m)')),
                  Center(child: Text('1.0 km')),
                  Center(child: Text('2.0 km')),
                  Center(child: Text('3.0 km')),
                  Center(child: Text('5.0 km')),
                  Center(child: Text('10.0 km')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationPicker() {
    return CupertinoButton(
      padding: const EdgeInsets.all(12),
      color: CupertinoColors.systemGrey6.resolveFrom(context),
      borderRadius: BorderRadius.circular(10),
      onPressed: _showDurationPicker,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$_durationDays days'),
          const Icon(CupertinoIcons.chevron_right, size: 20),
        ],
      ),
    );
  }

  Widget _buildCostEstimate() {
    final budget = double.tryParse(_budgetController.text) ?? 0;
    final estimatedImpressions = (budget / 0.10).floor();
    final estimatedClicks = (budget / 0.50).floor();
    final hasLocation = _selectedLocation != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasLocation
            ? CupertinoColors.systemBlue.withOpacity(0.1)
            : CupertinoColors.systemRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasLocation
              ? const Color(0xFF007AFF).withOpacity(0.3)
              : CupertinoColors.systemRed.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasLocation ? CupertinoIcons.info_circle : CupertinoIcons.exclamationmark_triangle,
                color: hasLocation ? const Color(0xFF007AFF) : CupertinoColors.systemRed,
              ),
              const SizedBox(width: 8),
              Text(
                hasLocation ? 'Cost Estimate' : 'Location Required',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: hasLocation ? null : CupertinoColors.systemRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!hasLocation)
            const Text(
              'Please select a location on the map to continue',
              style: TextStyle(color: CupertinoColors.systemRed),
            )
          else ...[
            Text('Est. Impressions: ~$estimatedImpressions'),
            Text('Est. Clicks: ~$estimatedClicks'),
            Text('Coverage: ${_radiusKm.toStringAsFixed(1)} km radius'),
            Text('Cost per impression: \$0.10'),
            Text('Cost per click: \$0.50'),
          ],
        ],
      ),
    );
  }

  void _showDistrictPicker() {
    if (_isLoadingDistricts) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Loading'),
          content: const Text('Please wait while districts are loading...'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (_districts.isEmpty) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('No Districts'),
          content: const Text('No districts available. You can still create an ad without district targeting.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Group districts by state
    final districtsByState = <String, List<District>>{};
    for (var district in _districts) {
      districtsByState.putIfAbsent(district.state, () => []).add(district);
    }
    
    // Flatten for picker with state headers
    final List<String> pickerItems = [];
    final List<District?> pickerDistricts = []; // null for state headers
    
    districtsByState.forEach((state, districts) {
      pickerItems.add('--- $state ---');
      pickerDistricts.add(null);
      for (var district in districts) {
        pickerItems.add('  ${district.name}');
        pickerDistricts.add(district);
      }
    });

    int initialItem = 0;
    if (_selectedDistrict != null) {
      final index = pickerDistricts.indexOf(_selectedDistrict);
      if (index != -1) initialItem = index;
    }

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('Clear'),
                    onPressed: () {
                      setState(() => _selectedDistrict = null);
                      Navigator.pop(context);
                    },
                  ),
                  const Text(
                    'Select District',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CupertinoButton(
                    child: const Text('Done'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                scrollController: FixedExtentScrollController(initialItem: initialItem),
                onSelectedItemChanged: (index) {
                  if (pickerDistricts[index] != null) {
                    setState(() => _selectedDistrict = pickerDistricts[index]);
                  }
                },
                children: pickerItems.asMap().entries.map((entry) {
                  final isHeader = pickerDistricts[entry.key] == null;
                  return Center(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: isHeader ? 14 : 16,
                        fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
                        color: isHeader 
                            ? CupertinoColors.systemGrey 
                            : CupertinoColors.label.resolveFrom(context),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDurationPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoButton(
                    child: const Text('Done'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                onSelectedItemChanged: (index) {
                  setState(() => _durationDays = [1, 3, 7, 14, 30][index]);
                },
                children: ['1 day', '3 days', '7 days', '14 days', '30 days']
                    .map((d) => Center(child: Text(d)))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAd() async {
    if (_userId == null) {
      _showError('Please login first');
      return;
    }

    if (_selectedLocation == null) {
      _showError('Please select a location on the map');
      return;
    }

    final budget = double.tryParse(_budgetController.text) ?? 0;
    if (budget <= 0) {
      _showError('Please enter a valid budget');
      return;
    }

    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      _showError('Please fill in all required fields');
      return;
    }

    if (widget.wallet == null || widget.wallet!.balance < budget) {
      _showError('Insufficient wallet balance');
      return;
    }

    final now = DateTime.now();
    final ad = Ad(
      id: '',
      merchantId: _userId!,
      merchantName: _userName,
      type: _selectedType,
      title: _titleController.text,
      content: _contentController.text,
      voiceScript: _selectedType == AdType.voice
          ? (_voiceScriptController.text.isEmpty ? _contentController.text : _voiceScriptController.text)
          : null,
      districtId: _selectedDistrict?.id,
      state: _selectedDistrict?.state,
      latitude: _selectedLocation!.latitude,
      longitude: _selectedLocation!.longitude,
      radiusKm: _radiusKm,
      budget: budget,
      startDate: now,
      endDate: now.add(Duration(days: _durationDays)),
      createdAt: now,
      merchantPhone: _phoneController.text.isEmpty ? null : _phoneController.text,
      merchantAddress: _addressController.text.isEmpty ? null : _addressController.text,
    );

    try {
      await _adService.createAd(ad);
      await _adService.updateWalletBalance(_userId!, -budget);
      if (mounted) {
        Navigator.pop(context);
        _showSuccess();
      }
    } catch (e) {
      _showError('Failed to create ad: $e');
    }
  }

  void _showError(String message) {
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

  void _showSuccess() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: const Text('Your ad has been created and is now active!'),
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

