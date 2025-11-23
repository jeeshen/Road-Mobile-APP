import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/post.dart';
import '../models/post_category.dart';
import '../models/district.dart';
import '../models/character.dart';
import '../models/user.dart';
import '../models/user_location.dart';
import '../services/navigation_service.dart' as nav_service;
import '../services/location_service.dart';
import '../services/location_sharing_service.dart';
import '../services/voice_alert_service.dart';
import '../services/road_damage_service.dart';
import '../services/firebase_service.dart';
import '../services/chatgpt_service.dart';
import '../services/nlp_service.dart';
import '../widgets/animated_character_marker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';
import '../models/trip_status_update.dart';
import '../models/trip_message.dart';
import '../services/convoy_service.dart';
import '../services/friend_service.dart';
import '../services/ad_service.dart';
import '../services/premium_service.dart';
import '../models/ad.dart';
import '../widgets/ad_banner_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';

class NavigationScreen extends StatefulWidget {
  final LatLng destination;
  final String destinationName;
  final Position currentPosition;
  final List<Post> allPosts;
  final List<District> districts;
  final Trip?
  existingTrip; // If provided, join this trip instead of creating new one

  const NavigationScreen({
    super.key,
    required this.destination,
    required this.destinationName,
    required this.currentPosition,
    required this.allPosts,
    required this.districts,
    this.existingTrip,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _VoiceAdPopup extends StatelessWidget {
  final Ad ad;
  final VoidCallback onDismiss;

  const _VoiceAdPopup({required this.ad, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                CupertinoIcons.speaker_2_fill,
                color: CupertinoColors.systemBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey5.resolveFrom(
                            context,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Voice Ad',
                          style: TextStyle(
                            fontSize: 10,
                            color: CupertinoColors.systemGrey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ad.merchantName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: CupertinoColors.systemGrey,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ad.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ad.content,
                    style: const TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: onDismiss,
              child: const Icon(
                CupertinoIcons.xmark_circle_fill,
                color: CupertinoColors.systemGrey,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationScreenState extends State<NavigationScreen> {
  final nav_service.NavigationService _navigationService =
      nav_service.NavigationService();
  final LocationService _locationService = LocationService();
  final VoiceAlertService _voiceService = VoiceAlertService();
  final MapController _mapController = MapController();
  final ConvoyService _convoyService = ConvoyService();
  final FriendService _friendService = FriendService();
  final AdService _adService = AdService();
  final PremiumService _premiumService = PremiumService();
  final FlutterTts _tts = FlutterTts();
  final RoadDamageService _roadDamageService = RoadDamageService();
  final FirebaseService _firebaseService = FirebaseService();
  final NLPService _nlpService = NLPService();
  final ChatGPTService? _chatGPTService = ChatGPTService(
    apiKey:
        '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',
  );
  final Uuid _uuid = const Uuid();

  List<nav_service.NavigationRoute>? _routes;
  nav_service.NavigationRoute? _selectedRoute;
  int _selectedRouteIndex = 0;
  bool _isLoading = true;
  bool _isNavigating = false;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  nav_service.RouteSegment? _currentSegment;
  double? _distanceToNextInstruction;
  Timer? _navigationTimer;
  bool _voiceEnabled = true;
  bool _liveLocationEnabled = false;
  double _currentSpeed = 0.0;
  double _currentHeading = 0.0;
  List<UserLocation> _liveUsers = [];
  User? _currentUser;
  bool _isMoving = false;
  Trip? _activeTrip;
  bool _showChat = false;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  TripStatusUpdate? _currentStatusDisplay;
  Timer? _statusDisplayTimer;
  bool _showingStatus = false;
  StreamSubscription<List<TripStatusUpdate>>? _statusSubscription;

  // Notification system
  Set<String> _seenPostIds = {};
  Set<String> _notifiedPostIds = {};
  Timer? _notificationCheckTimer;
  Post? _currentNotification;
  Timer? _notificationDisplayTimer;

  // Ad system
  bool _isPremiumUser = false;
  Ad? _currentBannerAd;
  bool _showBannerAd = false;
  Ad? _currentVoiceAd;
  bool _showVoiceAdPopup = false;
  Set<String> _shownAdIds = {};
  Timer? _adCheckTimer;
  Timer? _voicePopupTimer;
  List<Ad> _nearbyAds = [];
  DateTime? _navigationStartTime;

  static const Duration _voiceAdDelay = Duration(seconds: 5);

  double get _bannerOffsetHeight =>
      (_showBannerAd && _currentBannerAd != null && !_isPremiumUser) ? 100 : 0;

  double get _voiceAdOffsetHeight =>
      (_showVoiceAdPopup && _currentVoiceAd != null && !_isPremiumUser)
      ? 100
      : 0;

  double get _adOverlayHeight => _bannerOffsetHeight + _voiceAdOffsetHeight;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.currentPosition;

    // If joining existing trip, skip route planning and start navigation
    if (widget.existingTrip != null) {
      _activeTrip = widget.existingTrip;
      _setupExistingTrip();
    } else {
      _calculateRoutes();
    }

    _loadLiveUsers();
    _loadCurrentUser();
    _checkPremiumStatus();
  }

  void _setupExistingTrip() {
    final estimatedDuration = widget.existingTrip!.estimatedArrival.difference(
      DateTime.now(),
    );

    // Create a route from the trip's polyline
    final route = nav_service.NavigationRoute(
      id: widget.existingTrip!.id,
      polyline: widget.existingTrip!.route,
      totalDistance: widget.existingTrip!.totalDistance,
      totalDuration: estimatedDuration.inSeconds.toDouble(),
      type: nav_service.RouteType.balanced,
      safetyScore: 100.0,
      summary: 'Following ${widget.existingTrip!.creatorName}\'s route',
      segments: [], // Will be calculated during navigation
      riskPoints: [], // Will be populated from posts during navigation
    );

    setState(() {
      _routes = [route];
      _selectedRoute = route;
      _isLoading = false;
    });

    // Auto-start navigation
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _beginNavigation();
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    try {
      // Get current user from local storage or session
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('current_user_id');
      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists && mounted) {
          setState(() {
            _currentUser = User.fromMap(userDoc.data()!);
            _liveLocationEnabled = _currentUser?.shareLocation ?? false;
          });

          // Start position tracking if live location is enabled
          if (_liveLocationEnabled && !_isNavigating) {
            _positionSubscription?.cancel();
            _positionSubscription = _locationService
                .getPositionStream(
                  accuracy: LocationAccuracy.high,
                  distanceFilter: 10,
                )
                .listen((position) {
                  if (!mounted) return;
                  setState(() {
                    _currentPosition = position;
                    _currentSpeed = position.speed * 3.6;
                    _isMoving = position.speed > 0.28;
                  });
                });
          }
        }
      }
    } catch (e) {
      print('Error loading current user: $e');
    }
  }

  Stream<List<UserLocation>>? _liveUsersStream;
  StreamSubscription<List<UserLocation>>? _liveUsersSubscription;

  void _loadLiveUsers() {
    _liveUsersStream = LocationSharingService().getUserLocationsStream();
    _liveUsersSubscription = _liveUsersStream?.listen((users) {
      if (mounted) {
        setState(() {
          _liveUsers = users;
        });
      }
    });
  }

  void _toggleLiveLocation() async {
    if (_currentUser == null) return;

    setState(() {
      _liveLocationEnabled = !_liveLocationEnabled;
    });

    // Start/stop position tracking based on live location status
    if (_liveLocationEnabled && !_isNavigating) {
      // Start position tracking for character animation during route planning
      _positionSubscription?.cancel();
      _positionSubscription = _locationService
          .getPositionStream(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          )
          .listen((position) {
            if (!mounted) return;
            setState(() {
              _currentPosition = position;
              _currentSpeed = position.speed * 3.6;
              _isMoving = position.speed > 0.28;
              _currentHeading = position.heading;
            });
            // Update map position during route planning
            if (!_isNavigating) {
              _mapController.move(
                LatLng(position.latitude, position.longitude),
                _mapController.camera.zoom,
              );
            }
          });
    } else if (!_liveLocationEnabled && !_isNavigating) {
      // Stop position tracking if not navigating and live location disabled
      _positionSubscription?.cancel();
    }

    // Update user's sharing status in Firebase
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.id)
          .update({'shareLocation': _liveLocationEnabled});

      setState(() {
        _currentUser = _currentUser!.copyWith(
          shareLocation: _liveLocationEnabled,
        );
      });
    } catch (e) {
      print('Error updating location sharing: $e');
    }
  }

  Future<void> _checkPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('current_user_id');
    if (userId != null) {
      final isPremium = await _premiumService.isPremiumUser(userId);
      setState(() => _isPremiumUser = isPremium);

      if (!isPremium) {
        print('NavigationScreen: User is not premium, will check for ads');
        // Check for ads immediately
        _checkForNearbyAds();

        // Start checking for nearby ads periodically
        _adCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
          _checkForNearbyAds();
        });
      } else {
        print('NavigationScreen: User is premium, no ads will be shown');
      }
    }
  }

  Future<void> _checkForNearbyAds() async {
    if (_currentPosition == null || _isPremiumUser) {
      print(
        'NavigationScreen: Cannot check ads - position: ${_currentPosition != null}, premium: $_isPremiumUser',
      );
      return;
    }

    print(
      'NavigationScreen: Checking for ads at (${_currentPosition!.latitude}, ${_currentPosition!.longitude})',
    );

    final ads = await _adService.getNearbyAds(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    print('NavigationScreen: Found ${ads.length} nearby ads');
    setState(() => _nearbyAds = ads);

    // Show banner ad if available and not already showing
    if (!_showBannerAd && ads.isNotEmpty) {
      final bannerAd = _adService.getNextAd(ads, AdType.banner);
      if (bannerAd != null && !_shownAdIds.contains(bannerAd.id)) {
        print('NavigationScreen: Showing banner ad: ${bannerAd.title}');
        setState(() {
          _currentBannerAd = bannerAd;
          _showBannerAd = true;
          _shownAdIds.add(bannerAd.id);
        });

        // Auto-hide after 8 seconds
        Future.delayed(const Duration(seconds: 8), () {
          if (mounted) {
            print('NavigationScreen: Auto-hiding banner ad');
            setState(() => _showBannerAd = false);
          }
        });
      } else {
        print(
          'NavigationScreen: No banner ad to show (bannerAd: $bannerAd, already shown: ${bannerAd != null ? _shownAdIds.contains(bannerAd.id) : "N/A"})',
        );
      }
    } else {
      print(
        'NavigationScreen: Not showing banner ad (already showing: $_showBannerAd, ads available: ${ads.length})',
      );
    }

    final bool canPlayVoiceAd =
        _isNavigating &&
        _voiceEnabled &&
        _navigationStartTime != null &&
        DateTime.now().difference(_navigationStartTime!) >= _voiceAdDelay;

    // Play voice ad if available (only during active navigation after delay)
    if (canPlayVoiceAd && ads.isNotEmpty) {
      final voiceAd = _adService.getNextAd(ads, AdType.voice);
      if (voiceAd != null && !_shownAdIds.contains(voiceAd.id)) {
        print('NavigationScreen: Playing voice ad: ${voiceAd.title}');
        _shownAdIds.add(voiceAd.id);
        await _playVoiceAd(voiceAd);
      }
    }
  }

  Future<void> _playVoiceAd(Ad ad) async {
    if (!mounted) return;

    setState(() {
      _currentVoiceAd = ad;
      _showVoiceAdPopup = true;
    });

    _voicePopupTimer?.cancel();
    _voicePopupTimer = Timer(const Duration(seconds: 12), () {
      if (mounted && _currentVoiceAd?.id == ad.id) {
        setState(() => _showVoiceAdPopup = false);
      }
    });

    try {
      await _tts.setLanguage('en-US');
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.4);
      await _tts.speak(ad.voiceScript ?? ad.content);
      await _adService.recordImpression(ad.id);
    } catch (e) {
      print('Error playing voice ad: $e');
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _liveUsersSubscription?.cancel();
    _navigationTimer?.cancel();
    _notificationCheckTimer?.cancel();
    _notificationDisplayTimer?.cancel();
    _statusDisplayTimer?.cancel();
    _statusSubscription?.cancel();
    _adCheckTimer?.cancel();
    _voicePopupTimer?.cancel();
    _voiceService.dispose();
    _tts.stop();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  Future<void> _calculateRoutes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final origin = LatLng(
        widget.currentPosition.latitude,
        widget.currentPosition.longitude,
      );

      final routes = await _navigationService.calculateRoutes(
        origin: origin,
        destination: widget.destination,
        allPosts: widget.allPosts,
        districts: widget.districts,
      );

      if (mounted) {
        setState(() {
          _routes = routes;
          _selectedRoute = routes.first;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Failed to calculate routes: $e');
      }
    }
  }

  void _startNavigation() {
    if (_selectedRoute == null) return;

    // Show drive party option before starting navigation
    if (_currentUser != null) {
      _showDrivePartyOption();
    } else {
      _beginNavigation();
    }
  }

  void _showDrivePartyOption() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(5),
        child: CupertinoActionSheet(
          title: const Text('Start Navigation'),
          message: const Text(
            'Would you like to create a drive party and invite friends?',
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _showInviteFriendsDialog();
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.car_detailed,
                    color: CupertinoColors.systemPurple,
                  ),
                  SizedBox(width: 8),
                  Text('Create Drive Party'),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _beginNavigation();
              },
              child: const Text('Navigate Solo'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
  }

  void _showInviteFriendsDialog() {
    final Set<String> selectedFriends = {};

    showCupertinoModalPopup(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: CupertinoColors.systemBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: CupertinoColors.separator,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          'Invite Friends',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          Navigator.pop(context);
                          await _createDriveParty(selectedFriends.toList());
                          _beginNavigation();
                        },
                        child: const Text(
                          'Start',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                // Friends list
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _friendService.getFriendsStream(_currentUser!.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CupertinoActivityIndicator(),
                        );
                      }

                      final friends = snapshot.data ?? [];

                      if (friends.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text(
                              'No friends to invite\nAdd friends first!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          final friendId = friend['friendId'] as String;
                          final friendName = friend['friendName'] as String;
                          final isSelected = selectedFriends.contains(friendId);

                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  selectedFriends.remove(friendId);
                                } else {
                                  selectedFriends.add(friendId);
                                }
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? CupertinoColors.systemPurple.withValues(
                                        alpha: 0.1,
                                      )
                                    : CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? CupertinoColors.systemPurple
                                      : CupertinoColors.systemGrey6,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemBlue
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        friendName.isNotEmpty
                                            ? friendName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: CupertinoColors.systemBlue,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      friendName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      CupertinoIcons.check_mark_circled_solid,
                                      color: CupertinoColors.systemPurple,
                                      size: 24,
                                    )
                                  else
                                    const Icon(
                                      CupertinoIcons.circle,
                                      color: CupertinoColors.systemGrey3,
                                      size: 24,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                // Start without inviting button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: CupertinoColors.separator,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      Navigator.pop(context);
                      await _createDriveParty([]);
                      _beginNavigation();
                    },
                    child: Text(
                      selectedFriends.isEmpty
                          ? 'Start Solo'
                          : 'Start Without Inviting',
                      style: const TextStyle(
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _createDriveParty(List<String> friendIds) async {
    if (_currentUser == null ||
        _selectedRoute == null ||
        _currentPosition == null)
      return;

    try {
      // Calculate ETA
      final duration = _parseDuration(_selectedRoute!.durationText);
      final eta = DateTime.now().add(duration);

      // Create trip
      final trip = await _convoyService.createTrip(
        creatorId: _currentUser!.id,
        creatorName: _currentUser!.name,
        title: 'Trip to ${widget.destinationName}',
        startLocation: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
        startAddress: 'Current Location',
        destination: widget.destination,
        destinationAddress: widget.destinationName,
        route: _selectedRoute!.polyline,
        estimatedArrival: eta,
        updateInterval: 30,
        totalDistance: _parseDistance(_selectedRoute!.distanceText),
      );

      setState(() {
        _activeTrip = trip;
      });

      // Invite friends if any selected
      if (friendIds.isNotEmpty) {
        await _convoyService.inviteFriendsToTrip(
          tripId: trip.id,
          friendIds: friendIds,
          inviterName: _currentUser!.name,
        );
      }

      // Start the trip
      await _convoyService.startTrip(trip.id);

      if (mounted) {
        // Show success message
        showCupertinoDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('🚗 Drive Party Created!'),
            content: Text(
              friendIds.isEmpty
                  ? 'Your drive party is active. You can invite friends later from the convoy screen.'
                  : 'Drive party created and ${friendIds.length} friend(s) invited!',
            ),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to create drive party: $e'),
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

  Duration _parseDuration(String text) {
    // Parse "X min" or "X h Y min" format
    final parts = text.split(' ');
    int hours = 0;
    int minutes = 0;

    for (int i = 0; i < parts.length; i++) {
      if (parts[i] == 'h' && i > 0) {
        hours = int.tryParse(parts[i - 1]) ?? 0;
      } else if (parts[i] == 'min' && i > 0) {
        minutes = int.tryParse(parts[i - 1]) ?? 0;
      }
    }

    return Duration(hours: hours, minutes: minutes);
  }

  double _parseDistance(String text) {
    // Parse "X km" or "X.Y km" format
    final match = RegExp(r'([\d.]+)').firstMatch(text);
    if (match != null) {
      return (double.tryParse(match.group(1) ?? '0') ?? 0) *
          1000; // Convert to meters
    }
    return 0;
  }

  void _beginNavigation() {
    if (_selectedRoute == null) return;

    setState(() {
      _isNavigating = true;
      _navigationStartTime = DateTime.now();
    });

    // Initialize seen posts with current posts
    _seenPostIds = widget.allPosts.map((p) => p.id).toSet();

    // Announce navigation start
    _voiceService.announceNavigationStart(
      widget.destinationName,
      _selectedRoute!.durationText,
    );

    // Start position tracking (cancel any existing subscription first)
    _positionSubscription?.cancel();
    _positionSubscription = _locationService
        .getPositionStream(accuracy: LocationAccuracy.high, distanceFilter: 10)
        .listen(_handlePositionUpdate);

    // Start navigation monitoring
    _navigationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkNavigationState();
    });

    // Start notification checking
    _notificationCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkForNotifications();
    });

    // Start road damage detection during navigation
    _roadDamageService.onRoadDamageDetected = (position, severity) {
      _handleRoadDamageDetected(position, severity);
    };
    _roadDamageService.startMonitoring();

    // Update trip location if drive party is active
    if (_activeTrip != null) {
      Timer.periodic(const Duration(seconds: 30), (_) async {
        if (_currentPosition != null && _activeTrip != null) {
          await _convoyService.updateParticipantLocation(
            tripId: _activeTrip!.id,
            userId: _currentUser!.id,
            position: _currentPosition!,
          );
        }
      });

      // Listen to status updates
      _listenToStatusUpdates();
    }
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _showVoiceAdPopup = false;
      _navigationStartTime = null;
    });

    // Cancel navigation-specific subscriptions and timers
    _navigationTimer?.cancel();
    _notificationCheckTimer?.cancel();
    _notificationDisplayTimer?.cancel();
    _voiceService.stop();

    // Stop road damage detection
    _roadDamageService.stopMonitoring();

    // Keep position tracking if live location is enabled, otherwise cancel it
    if (!_liveLocationEnabled) {
      _positionSubscription?.cancel();
    } else {
      // Restart with lighter updates for route planning mode
      _positionSubscription?.cancel();
      _positionSubscription = _locationService
          .getPositionStream(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          )
          .listen((position) {
            if (!mounted) return;
            setState(() {
              _currentPosition = position;
              _currentSpeed = position.speed * 3.6;
              _isMoving = position.speed > 0.28;
            });
          });
    }
  }

  void _handlePositionUpdate(Position position) {
    if (!mounted || _selectedRoute == null) return;

    setState(() {
      _currentPosition = position;
      _currentSpeed = position.speed * 3.6; // Convert m/s to km/h
      // Character is moving if speed is above 1 km/h (approx 0.28 m/s)
      _isMoving = position.speed > 0.28;
      _currentHeading = position.heading;
    });

    // Live location updates handled by location sharing service

    // Update map position and rotation - road points upward
    final center = LatLng(position.latitude, position.longitude);
    _mapController.moveAndRotate(
      center,
      18.5, // Increased zoom for better visibility
      -position.heading, // Rotate map so travel direction points up
    );

    // Check if off route
    final isOff = _navigationService.isOffRoute(
      position,
      _selectedRoute!.polyline,
    );

    if (isOff) {
      _handleOffRoute();
    } else {
      _updateCurrentSegment(position);
    }
  }

  void _updateCurrentSegment(Position position) {
    if (_selectedRoute == null) return;

    final segment = _navigationService.getNextSegment(
      position,
      _selectedRoute!.segments,
    );

    if (segment != null && segment != _currentSegment) {
      setState(() {
        _currentSegment = segment;
      });

      // Announce instruction
      if (_voiceEnabled) {
        _voiceService.announceInstruction(
          segment.instruction,
          segment.distance,
        );
      }
    }

    // Calculate distance to next instruction
    if (segment != null) {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        segment.end.latitude,
        segment.end.longitude,
      );
      setState(() {
        _distanceToNextInstruction = distance;
      });
    }
  }

  void _checkNavigationState() {
    if (_currentPosition == null || _selectedRoute == null) return;

    // Check for nearby risk points
    final currentLatLng = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    for (final risk in _selectedRoute!.riskPoints) {
      final distance = Geolocator.distanceBetween(
        currentLatLng.latitude,
        currentLatLng.longitude,
        risk.location.latitude,
        risk.location.longitude,
      );

      if (distance < 1000 && _voiceEnabled) {
        _voiceService.announceRiskPoint(risk, distance);
      }
    }

    // Check for nearby posts from widget.allPosts
    for (final post in widget.allPosts) {
      if (post.latitude != null && post.longitude != null) {
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          post.latitude!,
          post.longitude!,
        );

        // Alert if within 500m of a post
        if (distance < 500) {
          _showNearbyPostAlert(post, distance);
        }
      }
    }

    // Check if arrived
    final distanceToDestination = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      widget.destination.latitude,
      widget.destination.longitude,
    );

    if (distanceToDestination < 50) {
      _handleArrival();
    }
  }

  /// Check for notifications: new road conditions, accidents on route, traffic jams
  void _checkForNotifications() {
    if (_currentPosition == null || _selectedRoute == null || !_isNavigating) {
      return;
    }

    final currentLatLng = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    // 1. Check for new road conditions in the region (within 5km)
    for (final post in widget.allPosts) {
      if (_notifiedPostIds.contains(post.id)) continue;

      // Check if post is new (not in seen posts)
      final isNewPost = !_seenPostIds.contains(post.id);

      if (post.latitude != null && post.longitude != null) {
        final distance = Geolocator.distanceBetween(
          currentLatLng.latitude,
          currentLatLng.longitude,
          post.latitude!,
          post.longitude!,
        );

        // New road condition in region (within 5km)
        if (isNewPost && distance < 5000) {
          _showNotification(post, 'New road condition in your area');
          _seenPostIds.add(post.id);
          _notifiedPostIds.add(post.id);
          continue;
        }

        // 2. Check for accidents on the followed route (within 1km of route)
        if (post.category == PostCategory.accident &&
            _isPostOnRoute(post, _selectedRoute!.polyline)) {
          final routeDistance = _getDistanceToRoute(
            post,
            _selectedRoute!.polyline,
          );
          if (routeDistance < 1000) {
            _showNotification(post, 'Accident on your route');
            _notifiedPostIds.add(post.id);
            continue;
          }
        }

        // 3. Check for traffic jams on frequently used routes (within 2km)
        if (post.category == PostCategory.trafficJam && distance < 2000) {
          _showNotification(post, 'Traffic jam nearby');
          _notifiedPostIds.add(post.id);
          continue;
        }
      }
    }

    // Update seen posts
    _seenPostIds = widget.allPosts.map((p) => p.id).toSet();
  }

  /// Handle road damage detection during navigation - automatically create post
  Future<void> _handleRoadDamageDetected(
    Position position,
    double severity,
  ) async {
    // Find nearest district
    final nearestDistrict = _locationService.findNearestDistrict(
      position,
      widget.districts,
    );
    if (nearestDistrict == null) return;

    try {
      // Generate AI content for the post
      String title = 'Road Damage Detected';
      String content =
          'Road damage detected in ${nearestDistrict.name}. '
          'Severity level: ${(severity * 100).toStringAsFixed(0)}%. '
          'Please drive with caution in this area.';

      final chatGPTService = _chatGPTService;
      if (chatGPTService != null) {
        try {
          final aiReport = await chatGPTService.generateRoadDamageReport(
            nearestDistrict.name,
            nearestDistrict.state,
            severity,
            position.latitude,
            position.longitude,
          );
          title = aiReport['title'] ?? title;
          content = aiReport['content'] ?? content;
        } catch (e) {
          print('Error generating AI content: $e');
          // Use fallback content
        }
      }

      // Create post
      final activeUserId = _currentUser?.id ?? 'guest_user';
      final displayName = _currentUser?.name.isNotEmpty == true
          ? _currentUser!.name
          : 'Anonymous';

      Post post = Post(
        id: _uuid.v4(),
        districtId: nearestDistrict.id,
        userId: activeUserId,
        username: displayName,
        title: title,
        content: content,
        category: PostCategory.pothole,
        mediaUrls: [],
        createdAt: DateTime.now(),
        latitude: position.latitude,
        longitude: position.longitude,
        isRoadDamage: true,
      );

      // Apply NLP analysis for auto-tagging and risk level
      post = _nlpService.enhancePost(post);

      // Save post to Firebase (no media files)
      await _firebaseService.createPost(post, []);

      print('Road damage post auto-created: ${post.id}');
    } catch (e) {
      print('Error auto-creating road damage post: $e');
      // Silently fail - don't show any error to user
    }
  }

  /// Check if a post is on or near the route
  bool _isPostOnRoute(Post post, List<LatLng> route) {
    if (post.latitude == null || post.longitude == null) return false;
    if (route.isEmpty) return false;

    final distanceToRoute = _getDistanceToRoute(post, route);

    // Consider post "on route" if within 500m
    return distanceToRoute < 500;
  }

  /// Calculate minimum distance from post to route
  double _getDistanceToRoute(Post post, List<LatLng> route) {
    if (post.latitude == null || post.longitude == null) return double.infinity;
    if (route.isEmpty) return double.infinity;

    final postLocation = LatLng(post.latitude!, post.longitude!);
    double minDistance = double.infinity;

    // Check distance to each segment of the route
    for (int i = 0; i < route.length - 1; i++) {
      final segmentStart = route[i];
      final segmentEnd = route[i + 1];

      // Calculate distance to line segment
      final distance = _pointToLineSegmentDistance(
        postLocation,
        segmentStart,
        segmentEnd,
      );

      if (distance < minDistance) {
        minDistance = distance;
      }
    }

    return minDistance;
  }

  /// Calculate distance from point to line segment
  double _pointToLineSegmentDistance(
    LatLng point,
    LatLng lineStart,
    LatLng lineEnd,
  ) {
    final A = point.latitude - lineStart.latitude;
    final B = point.longitude - lineStart.longitude;
    final C = lineEnd.latitude - lineStart.latitude;
    final D = lineEnd.longitude - lineStart.longitude;

    final dot = A * C + B * D;
    final lenSq = C * C + D * D;
    double param = -1;

    if (lenSq != 0) {
      param = dot / lenSq;
    }

    double xx, yy;

    if (param < 0) {
      xx = lineStart.latitude;
      yy = lineStart.longitude;
    } else if (param > 1) {
      xx = lineEnd.latitude;
      yy = lineEnd.longitude;
    } else {
      xx = lineStart.latitude + param * C;
      yy = lineStart.longitude + param * D;
    }

    // Convert to meters
    return Geolocator.distanceBetween(point.latitude, point.longitude, xx, yy);
  }

  /// Show notification in convoy status area
  void _showNotification(Post post, String notificationType) {
    if (_notifiedPostIds.contains(post.id)) return;

    // Don't show if already showing a status or notification
    if (_showingStatus && _currentStatusDisplay != null) return;
    if (_currentNotification != null) return;

    setState(() {
      _currentNotification = post;
      _showingStatus = true;
    });

    // Auto-dismiss after 8 seconds
    _notificationDisplayTimer?.cancel();
    _notificationDisplayTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _currentNotification = null;
          _showingStatus = false;
        });
      }
    });

    // Voice alert using announceRiskPoint if it's a risk-related post
    if (_voiceEnabled && post.riskLevel != null) {
      final distance = post.latitude != null && post.longitude != null
          ? Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              post.latitude!,
              post.longitude!,
            )
          : null;

      if (distance != null && distance < 2000) {
        // Create a risk point for voice announcement
        final riskPoint = nav_service.RiskPoint(
          location: LatLng(post.latitude!, post.longitude!),
          level: post.riskLevel == RiskLevel.critical
              ? nav_service.NavRiskLevel.critical
              : post.riskLevel == RiskLevel.high
              ? nav_service.NavRiskLevel.high
              : post.riskLevel == RiskLevel.medium
              ? nav_service.NavRiskLevel.medium
              : nav_service.NavRiskLevel.low,
          description: post.content,
          type: post.category == PostCategory.accident
              ? 'accident'
              : post.category == PostCategory.trafficJam
              ? 'traffic'
              : 'general',
          timestamp: post.createdAt,
        );
        _voiceService.announceRiskPoint(riskPoint, distance);
      }
    }
  }

  final Set<String> _announcedPosts = {};

  void _showNearbyPostAlert(Post post, double distance) {
    // Prevent duplicate alerts
    if (_announcedPosts.contains(post.id)) return;
    _announcedPosts.add(post.id);

    // Show notification in convoy status area instead of dialog
    if (_currentNotification == null && !_showingStatus) {
      _showNotification(post, 'Nearby alert');
    }

    // Also show voice alert using announceRiskPoint if it's a risk-related post
    if (_voiceEnabled &&
        post.riskLevel != null &&
        post.latitude != null &&
        post.longitude != null) {
      final riskPoint = nav_service.RiskPoint(
        location: LatLng(post.latitude!, post.longitude!),
        level: post.riskLevel == RiskLevel.critical
            ? nav_service.NavRiskLevel.critical
            : post.riskLevel == RiskLevel.high
            ? nav_service.NavRiskLevel.high
            : post.riskLevel == RiskLevel.medium
            ? nav_service.NavRiskLevel.medium
            : nav_service.NavRiskLevel.low,
        description: post.content,
        type: post.category == PostCategory.accident
            ? 'accident'
            : post.category == PostCategory.trafficJam
            ? 'traffic'
            : 'general',
        timestamp: post.createdAt,
      );
      _voiceService.announceRiskPoint(riskPoint, distance);
    }
  }

  void _handleOffRoute() {
    _voiceService.announceOffRoute();
    _recalculateRoute();
  }

  Future<void> _recalculateRoute() async {
    if (_currentPosition == null) return;

    final origin = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    try {
      final routes = await _navigationService.calculateRoutes(
        origin: origin,
        destination: widget.destination,
        allPosts: widget.allPosts,
        districts: widget.districts,
      );

      if (mounted) {
        setState(() {
          _routes = routes;
          _selectedRoute =
              routes[_selectedRouteIndex.clamp(0, routes.length - 1)];
        });
        _voiceService.announceRerouting();
      }
    } catch (e) {
      print('Rerouting error: $e');
    }
  }

  Future<void> _handleArrival() async {
    _voiceService.announceArrival();
    _stopNavigation();

    // Complete drive party if active
    if (_activeTrip != null) {
      final stats = {
        'totalDistance': _activeTrip!.totalDistance,
        'duration': DateTime.now()
            .difference(_activeTrip!.startedAt ?? DateTime.now())
            .inMinutes,
        'participants': _activeTrip!.participants
            .where((p) => p.status == ParticipantStatus.active)
            .length,
      };
      await _convoyService.completeTrip(_activeTrip!.id, stats);
    }

    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('🎉 Arrived!'),
          content: Text(
            'You have arrived at ${widget.destinationName}${_activeTrip != null ? '\n\nDrive party completed!' : ''}',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go to home
              },
            ),
          ],
        ),
      );
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
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // Don't handle gestures when chat is open
        if (_showChat) return;

        // Enable swipe back gesture
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          if (_isNavigating) {
            _showExitConfirmation();
          } else {
            Navigator.of(context).maybePop();
          }
        }
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text(_isNavigating ? 'Navigating' : 'Route Planning'),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.back),
            onPressed: () {
              if (_isNavigating) {
                _showExitConfirmation();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          trailing: _isNavigating
              ? _activeTrip != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: Icon(
                              _voiceEnabled
                                  ? CupertinoIcons.speaker_2_fill
                                  : CupertinoIcons.speaker_slash_fill,
                            ),
                            onPressed: () {
                              setState(() {
                                _voiceEnabled = !_voiceEnabled;
                                _voiceService.setEnabled(_voiceEnabled);
                              });
                            },
                          ),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: const Icon(CupertinoIcons.ellipsis_circle),
                            onPressed: _showStatusPicker,
                          ),
                        ],
                      )
                    : CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Icon(
                          _voiceEnabled
                              ? CupertinoIcons.speaker_2_fill
                              : CupertinoIcons.speaker_slash_fill,
                        ),
                        onPressed: () {
                          setState(() {
                            _voiceEnabled = !_voiceEnabled;
                            _voiceService.setEnabled(_voiceEnabled);
                          });
                        },
                      )
              : null,
        ),
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator())
            : Stack(
                children: [
                  // Map
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _currentPosition != null
                          ? LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            )
                          : widget.destination,
                      initialZoom: _isNavigating ? 18.5 : 13.0,
                      minZoom: 10.0,
                      maxZoom: 19.0,
                      interactionOptions: InteractionOptions(
                        flags: _isNavigating
                            ? InteractiveFlag.all & ~InteractiveFlag.rotate
                            : InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                        subdomains: const ['a', 'b', 'c', 'd'],
                        userAgentPackageName: 'com.roadmobile.app',
                        retinaMode: true,
                        keepBuffer:
                            2, // Reduced from 8 to 2 for better performance
                        maxNativeZoom: 19,
                        maxZoom: 19,
                        panBuffer:
                            1, // Reduced from 2 to 1 for better performance
                        tileProvider: NetworkTileProvider(),
                        tileDisplay: const TileDisplay.fadeIn(
                          duration: Duration(milliseconds: 100),
                        ),
                      ),
                      // Route polylines
                      if (_selectedRoute != null && !_isNavigating)
                        ..._buildRoutePolylines(),
                      // Active route during navigation
                      if (_selectedRoute != null && _isNavigating)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _selectedRoute!.polyline,
                              strokeWidth: 6.0,
                              color: CupertinoColors.systemBlue,
                              borderStrokeWidth: 2.0,
                              borderColor: CupertinoColors.white,
                            ),
                          ],
                        ),
                      // Risk point markers
                      if (_selectedRoute != null)
                        MarkerLayer(markers: _buildRiskMarkers()),
                      // Post markers
                      MarkerLayer(markers: _buildPostMarkers()),
                      // Merchant ad logo markers (if not premium)
                      if (!_isPremiumUser)
                        MarkerLayer(markers: _buildAdLogoMarkers()),
                      // Live user markers
                      MarkerLayer(markers: _buildLiveUserMarkers()),
                      // Destination marker
                      MarkerLayer(markers: [_buildDestinationMarker()]),
                      // Current position marker (blue dot or character)
                      if (_currentPosition != null)
                        MarkerLayer(markers: [_buildCurrentPositionMarker()]),
                    ],
                  ),
                  // Route selection panel (when not navigating)
                  if (!_isNavigating && _routes != null)
                    _buildRouteSelectionPanel(),
                  // Navigation info panel (when navigating)
                  if (_isNavigating) _buildNavigationInfoPanel(),
                ],
              ),
      ),
    );
  }

  List<Widget> _buildRoutePolylines() {
    if (_routes == null) return [];

    return _routes!.asMap().entries.map((entry) {
      final index = entry.key;
      final route = entry.value;
      final isSelected = index == _selectedRouteIndex;

      return PolylineLayer(
        polylines: [
          Polyline(
            points: route.polyline,
            strokeWidth: isSelected ? 6.0 : 4.0,
            color: isSelected
                ? CupertinoColors.systemBlue
                : CupertinoColors.systemGrey,
            borderStrokeWidth: isSelected ? 2.0 : 1.0,
            borderColor: CupertinoColors.white,
          ),
        ],
      );
    }).toList();
  }

  List<Marker> _buildRiskMarkers() {
    if (_selectedRoute == null) return [];

    return _selectedRoute!.riskPoints.map((risk) {
      return Marker(
        point: risk.location,
        width: 32,
        height: 32,
        child: Container(
          decoration: BoxDecoration(
            color: _getRiskColor(risk.level),
            shape: BoxShape.circle,
            border: Border.all(color: CupertinoColors.white, width: 2),
          ),
          child: Icon(
            _getRiskIcon(risk.type),
            color: CupertinoColors.white,
            size: 16,
          ),
        ),
      );
    }).toList();
  }

  Color _getRiskColor(nav_service.NavRiskLevel level) {
    switch (level) {
      case nav_service.NavRiskLevel.critical:
        return CupertinoColors.systemRed;
      case nav_service.NavRiskLevel.high:
        return CupertinoColors.systemOrange;
      case nav_service.NavRiskLevel.medium:
        return CupertinoColors.systemYellow;
      case nav_service.NavRiskLevel.low:
        return CupertinoColors.systemGrey;
    }
  }

  IconData _getRiskIcon(String type) {
    switch (type) {
      case 'accident':
        return CupertinoIcons.exclamationmark_triangle_fill;
      case 'damage':
        return CupertinoIcons.hammer_fill;
      case 'weather':
        return CupertinoIcons.cloud_rain_fill;
      case 'traffic':
        return CupertinoIcons.car_fill;
      default:
        return CupertinoIcons.exclamationmark_circle_fill;
    }
  }

  Marker _buildDestinationMarker() {
    return Marker(
      point: widget.destination,
      width: 40,
      height: 50,
      alignment: Alignment.topCenter,
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed,
              shape: BoxShape.circle,
              border: Border.all(color: CupertinoColors.white, width: 3),
            ),
            child: const Icon(
              CupertinoIcons.placemark_fill,
              color: CupertinoColors.white,
              size: 18,
            ),
          ),
          Container(width: 3, height: 12, color: CupertinoColors.systemRed),
        ],
      ),
    );
  }

  Marker _buildCurrentPositionMarker() {
    // Show character avatar if user has one selected (during navigation or when live sharing)
    if (_currentUser != null &&
        _currentUser!.selectedCharacter != null &&
        _liveLocationEnabled) {
      final character = Character.getAllCharacters().firstWhere(
        (c) => c.id == _currentUser!.selectedCharacter,
        orElse: () => Character.getAllCharacters().first,
      );

      final isLancer = character.name.toLowerCase() == 'lancer';
      final scale = isLancer ? 1.4 : 1.0;

      return Marker(
        point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        width: 120,
        height: 120,
        alignment: Alignment.center,
        rotate: false, // Rotate with map during navigation
        child: AnimatedCharacterMarker(
          key: ValueKey(_currentUser!.selectedCharacter),
          actions: character.actions,
          userName: _currentUser!.name,
          enableClick: false,
          scale: scale,
          isMoving: _isMoving,
        ),
      );
    }

    // Default blue dot with direction indicator
    return Marker(
      point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      width: 50,
      height: 50,
      alignment: Alignment.center,
      rotate: false, // Rotate with map during navigation
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing circle
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
          ),
          // Inner solid circle with direction indicator
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: CupertinoColors.systemBlue,
              shape: BoxShape.circle,
              border: Border.all(color: CupertinoColors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.systemBlue.withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          // Direction arrow (only during navigation) - points up
          if (_isNavigating)
            const Positioned(
              top: 5,
              child: Icon(
                CupertinoIcons.arrowtriangle_up_fill,
                color: CupertinoColors.systemBlue,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  List<Marker> _buildPostMarkers() {
    return widget.allPosts
        .where((post) => post.latitude != null && post.longitude != null)
        .map((post) {
          return Marker(
            point: LatLng(post.latitude!, post.longitude!),
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => _showPostDetail(post),
              child: Container(
                decoration: BoxDecoration(
                  color: post.category.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: CupertinoColors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    post.category.icon,
                    color: CupertinoColors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          );
        })
        .toList();
  }

  List<Marker> _buildAdLogoMarkers() {
    return _nearbyAds
        .where(
          (ad) =>
              ad.type == AdType.mapLogo &&
              ad.latitude != null &&
              ad.longitude != null,
        )
        .map((ad) {
          return Marker(
            point: LatLng(ad.latitude!, ad.longitude!),
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () async {
                await _adService.recordClick(ad.id);
                _showAdDetail(ad);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF007AFF), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ad.logoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          ad.logoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                CupertinoIcons.building_2_fill,
                                color: Color(0xFF007AFF),
                                size: 20,
                              ),
                        ),
                      )
                    : const Icon(
                        CupertinoIcons.building_2_fill,
                        color: Color(0xFF007AFF),
                        size: 20,
                      ),
              ),
            ),
          );
        })
        .toList();
  }

  void _showAdDetail(Ad ad) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(ad.merchantName),
        message: Column(
          children: [
            if (ad.imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  ad.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              ad.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(ad.content),
            if (ad.merchantAddress != null) ...[
              const SizedBox(height: 8),
              Text('📍 ${ad.merchantAddress}'),
            ],
            if (ad.merchantPhone != null) ...[
              const SizedBox(height: 4),
              Text('📞 ${ad.merchantPhone}'),
            ],
          ],
        ),
        actions: [
          if (ad.latitude != null && ad.longitude != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to merchant location
                final destination = LatLng(ad.latitude!, ad.longitude!);
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => NavigationScreen(
                      destination: destination,
                      destinationName: ad.merchantName,
                      currentPosition: _currentPosition!,
                      allPosts: widget.allPosts,
                      districts: widget.districts,
                    ),
                  ),
                );
              },
              child: const Text('Navigate Here'),
            ),
          if (ad.merchantPhone != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                // Call merchant (would integrate with phone dialer)
              },
              child: const Text('Call'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ),
    );
  }

  void _showPostDetail(Post post) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(post.category.name),
        content: Text(post.content),
        actions: [
          CupertinoDialogAction(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildLiveUserMarkers() {
    final currentUserId = _currentUser?.id;
    final visibleUsers = currentUserId == null
        ? _liveUsers
        : _liveUsers.where((user) => user.userId != currentUserId).toList();

    return visibleUsers.map((userLoc) {
      // Show animated character if user has one selected
      if (userLoc.selectedCharacter != null) {
        final character = Character.getAllCharacters().firstWhere(
          (c) => c.id == userLoc.selectedCharacter!,
          orElse: () => Character.getAllCharacters().first,
        );

        final isLancer = character.name.toLowerCase() == 'lancer';
        final scale = isLancer ? 1.4 : 1.0;

        // Determine if user is moving (speed > 1 km/h)
        final isMoving = (userLoc.speed ?? 0) > 0.28; // 0.28 m/s = ~1 km/h

        return Marker(
          point: LatLng(userLoc.latitude, userLoc.longitude),
          width: 120,
          height: 120,
          alignment: Alignment.center,
          child: AnimatedCharacterMarker(
            key: ValueKey(userLoc.userId),
            actions: character.actions,
            userName: userLoc.userName,
            enableClick: false,
            scale: scale,
            isMoving: isMoving,
          ),
        );
      }

      // Default fallback for users without characters
      return Marker(
        point: LatLng(userLoc.latitude, userLoc.longitude),
        width: 50,
        height: 50,
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: CupertinoColors.systemBlue,
            border: Border.all(color: CupertinoColors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.systemBlue.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              userLoc.userName.isNotEmpty
                  ? userLoc.userName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildRouteSelectionPanel() {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.25,
      maxChildSize: 0.75,
      snap: true,
      snapSizes: const [0.25, 0.35, 0.75],
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Destination info
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          CupertinoIcons.placemark_fill,
                          color: CupertinoColors.systemRed,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Destination',
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                            Text(
                              widget.destinationName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: CupertinoColors.separator),
                // Route options
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: _routes!.asMap().entries.map((entry) {
                      final index = entry.key;
                      final route = entry.value;
                      final isSelected = index == _selectedRouteIndex;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedRouteIndex = index;
                            _selectedRoute = route;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? CupertinoColors.systemBlue.withOpacity(0.1)
                                : CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? CupertinoColors.systemBlue
                                  : CupertinoColors.systemGrey6,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Route type icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: _getRouteTypeColor(
                                    route.type,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getRouteTypeIcon(route.type),
                                  color: _getRouteTypeColor(route.type),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getRouteTypeName(route.type),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? CupertinoColors.systemBlue
                                            : CupertinoColors.label,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      route.summary,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: CupertinoColors.secondaryLabel,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    route.durationText,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    route.distanceText,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: CupertinoColors.secondaryLabel,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildSafetyBadge(route.safetyScore),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                // Start navigation button
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.of(context).padding.bottom + 16,
                  ),
                  child: CupertinoButton(
                    color: CupertinoColors.systemBlue,
                    borderRadius: BorderRadius.circular(12),
                    onPressed: _startNavigation,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.location_fill,
                          color: CupertinoColors.white,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Start Navigation',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationInfoPanel() {
    return Stack(
      children: [
        // Ad banner at top (if not premium and ad available)
        if (_showBannerAd && _currentBannerAd != null && !_isPremiumUser)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: AdBannerWidget(
                ad: _currentBannerAd!,
                onDismiss: () => setState(() => _showBannerAd = false),
              ),
            ),
          ),
        // Voice ad popup (shown only during navigation voice ads)
        if (_showVoiceAdPopup && _currentVoiceAd != null && !_isPremiumUser)
          Positioned(
            top: (_showBannerAd && _currentBannerAd != null && !_isPremiumUser)
                ? 100
                : 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _VoiceAdPopup(
                ad: _currentVoiceAd!,
                onDismiss: () {
                  setState(() => _showVoiceAdPopup = false);
                },
              ),
            ),
          ),
        // Combined instruction/status box at top (if drive party is active and chat is hidden)
        if (_activeTrip != null && !_showChat)
          Positioned(
            top: _adOverlayHeight,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child:
                      _showingStatus &&
                          (_currentStatusDisplay != null ||
                              _currentNotification != null)
                      ? _buildStatusContent()
                      : _buildDirectionContent(),
                ),
              ),
            ),
          ),
        // Turn instruction only (if no drive party or chat is shown)
        if (_activeTrip == null &&
            _currentSegment != null &&
            _distanceToNextInstruction != null)
          Positioned(
            top: _adOverlayHeight,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBlue.withValues(
                          alpha: 0.1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        CupertinoIcons.arrow_up,
                        color: CupertinoColors.systemBlue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _distanceToNextInstruction! < 1000
                                ? '${_distanceToNextInstruction!.toInt()} m'
                                : '${(_distanceToNextInstruction! / 1000).toStringAsFixed(1)} km',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _currentSegment!.instruction,
                            style: const TextStyle(
                              fontSize: 15,
                              color: CupertinoColors.secondaryLabel,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Chat panel (overlay when toggled)
        if (_showChat && _activeTrip != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (_) {}, // Absorb horizontal gestures
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _buildChatPanel(),
                ),
              ),
            ),
          ),
        // Bottom controls
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Navigation action buttons
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Live location toggle - iOS style like home page
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _toggleLiveLocation,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _liveLocationEnabled
                              ? CupertinoColors.systemGreen
                              : CupertinoColors.systemBackground,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.black.withValues(
                                alpha: 0.15,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _liveLocationEnabled
                              ? CupertinoIcons.dot_radiowaves_left_right
                              : CupertinoIcons.dot_square,
                          color: _liveLocationEnabled
                              ? CupertinoColors.white
                              : CupertinoColors.systemGrey,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Relocate button - iOS style
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        if (_currentPosition != null) {
                          // Focus on character position
                          final center = LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          );
                          if (_isNavigating) {
                            _mapController.moveAndRotate(
                              center,
                              18.5,
                              -_currentHeading,
                            );
                          } else {
                            _mapController.move(center, 17.0);
                          }
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.black.withValues(
                                alpha: 0.15,
                              ),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          CupertinoIcons.location_fill,
                          color: CupertinoColors.systemBlue,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Chat toggle button (only if drive party is active)
                    if (_activeTrip != null) ...[
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            _showChat = !_showChat;
                          });
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _showChat
                                ? CupertinoColors.systemPurple
                                : CupertinoColors.systemBackground,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _showChat
                                    ? CupertinoColors.systemPurple.withValues(
                                        alpha: 0.4,
                                      )
                                    : CupertinoColors.black.withValues(
                                        alpha: 0.15,
                                      ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            CupertinoIcons.chat_bubble_2_fill,
                            color: _showChat
                                ? CupertinoColors.white
                                : CupertinoColors.systemPurple,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Stop navigation button
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      color: CupertinoColors.destructiveRed,
                      borderRadius: BorderRadius.circular(22),
                      onPressed: () {
                        _stopNavigation();
                        Navigator.pop(context); // Go to home
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.stop_fill,
                            size: 18,
                            color: CupertinoColors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'End',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Current instruction card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Speed and Speed Limit Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Current Speed
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                CupertinoIcons.speedometer,
                                size: 18,
                                color: CupertinoColors.systemBlue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_currentSpeed.toInt()} km/h',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.systemBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Speed Limit
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _currentSpeed > 110
                                ? CupertinoColors.systemRed.withOpacity(0.1)
                                : CupertinoColors.systemGrey6,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _currentSpeed > 110
                                  ? CupertinoColors.systemRed
                                  : CupertinoColors.systemGrey,
                              width: 3,
                            ),
                          ),
                          child: Text(
                            '110',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _currentSpeed > 110
                                  ? CupertinoColors.systemRed
                                  : CupertinoColors.label,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(height: 1, color: CupertinoColors.separator),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoItem(
                          'ETA',
                          _selectedRoute!.durationText,
                          CupertinoIcons.clock,
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: CupertinoColors.separator,
                        ),
                        _buildInfoItem(
                          'Distance',
                          _selectedRoute!.distanceText,
                          CupertinoIcons.location,
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: CupertinoColors.separator,
                        ),
                        _buildInfoItem(
                          'Safety',
                          _selectedRoute!.safetyText,
                          CupertinoIcons.shield,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Bottom padding for navigation bar
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: CupertinoColors.secondaryLabel),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: CupertinoColors.secondaryLabel,
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyBadge(double score) {
    Color color;
    if (score >= 80) {
      color = CupertinoColors.systemGreen;
    } else if (score >= 60) {
      color = CupertinoColors.systemYellow;
    } else {
      color = CupertinoColors.systemOrange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.shield_fill, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            '${score.toInt()}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getRouteTypeName(nav_service.RouteType type) {
    switch (type) {
      case nav_service.RouteType.fastest:
        return 'Fastest';
      case nav_service.RouteType.safest:
        return 'Safest';
      case nav_service.RouteType.balanced:
        return 'Balanced';
    }
  }

  IconData _getRouteTypeIcon(nav_service.RouteType type) {
    switch (type) {
      case nav_service.RouteType.fastest:
        return CupertinoIcons.speedometer;
      case nav_service.RouteType.safest:
        return CupertinoIcons.shield_fill;
      case nav_service.RouteType.balanced:
        return CupertinoIcons.star_fill;
    }
  }

  Color _getRouteTypeColor(nav_service.RouteType type) {
    switch (type) {
      case nav_service.RouteType.fastest:
        return CupertinoColors.systemBlue;
      case nav_service.RouteType.safest:
        return CupertinoColors.systemGreen;
      case nav_service.RouteType.balanced:
        return CupertinoColors.systemOrange;
    }
  }

  void _showExitConfirmation() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('End Navigation'),
        content: const Text('Are you sure you want to stop navigation?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _stopNavigation();
              Navigator.pop(context); // Go to home
            },
            child: const Text('End'),
          ),
        ],
      ),
    );
  }

  void _showStatusPicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(5),
        child: CupertinoActionSheet(
          title: const Text('Convoy Actions'),
          message: const Text('Update status or manage trip'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _postStatus(StatusType.restStop);
              },
              child: const Text('🅿 Rest Stop'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _postStatus(StatusType.toilet);
              },
              child: const Text('🚻 Toilet Break'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _postStatus(StatusType.fuel);
              },
              child: const Text('⛽ Fuel Stop'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _postStatus(StatusType.eating);
              },
              child: const Text('🍔 Food Break'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _postStatus(StatusType.issue);
              },
              child: const Text('⚠️ Having Issues'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _postStatus(StatusType.resumeTrip);
              },
              child: const Text('🚙 Resume Trip'),
            ),
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _showCompleteConfirmation();
              },
              child: const Text('🏁 Complete Trip'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ),
      ),
    );
  }

  void _showCompleteConfirmation() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Complete Trip'),
        content: const Text(
          'Are you sure you want to complete this drive party? This will end the convoy for all participants.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              await _manuallyCompleteTrip();
            },
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  Future<void> _manuallyCompleteTrip() async {
    if (_activeTrip == null) return;

    final stats = {
      'totalDistance': _activeTrip!.totalDistance,
      'duration': _activeTrip!.startedAt != null
          ? DateTime.now().difference(_activeTrip!.startedAt!).inMinutes
          : 0,
      'participants': _activeTrip!.participants
          .where((p) => p.status == ParticipantStatus.active)
          .length,
    };

    try {
      await _convoyService.completeTrip(_activeTrip!.id, stats);

      if (mounted) {
        showCupertinoDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) Navigator.of(context, rootNavigator: true).pop();
            });

            return Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: CupertinoColors.systemGreen,
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Drive Party Completed!',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );

        setState(() {
          _activeTrip = null;
        });
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to complete trip: $e'),
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

  Future<void> _postStatus(StatusType type) async {
    if (_activeTrip == null ||
        _currentPosition == null ||
        _currentUser == null) {
      return;
    }

    try {
      print('📝 Posting status: ${type.name}');
      await _convoyService.postStatusUpdate(
        tripId: _activeTrip!.id,
        userId: _currentUser!.id,
        userName: _currentUser!.name,
        type: type,
        location: LatLng(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        ),
      );
      print('✅ Status posted successfully');
    } catch (e) {
      print('❌ Error posting status: $e');
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to update status: $e'),
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

  Widget _buildStatusContent() {
    // Show notification if available, otherwise show status
    if (_currentNotification != null) {
      return _buildNotificationContent(_currentNotification!);
    }

    if (_currentStatusDisplay == null) return const SizedBox();

    return Row(
      key: const ValueKey('status'),
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: CupertinoColors.systemPurple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              _currentStatusDisplay!.displayText.split(' ')[0],
              style: const TextStyle(fontSize: 28),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentStatusDisplay!.userName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _currentStatusDisplay!.displayText.replaceAll(
                  RegExp(r'^[^\w\s]+\s*'),
                  '',
                ),
                style: const TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              _showingStatus = false;
            });
            _statusDisplayTimer?.cancel();
          },
          child: const Icon(
            CupertinoIcons.xmark_circle_fill,
            color: CupertinoColors.systemGrey3,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationContent(Post post) {
    // Determine notification type and color
    Color notificationColor;
    IconData notificationIcon;
    String notificationTitle;

    if (post.category == PostCategory.accident) {
      notificationColor = CupertinoColors.systemRed;
      notificationIcon = CupertinoIcons.exclamationmark_triangle_fill;
      notificationTitle = 'Accident Alert';
    } else if (post.category == PostCategory.trafficJam) {
      notificationColor = CupertinoColors.systemOrange;
      notificationIcon = CupertinoIcons.car_fill;
      notificationTitle = 'Traffic Alert';
    } else {
      notificationColor = CupertinoColors.systemOrange;
      notificationIcon = CupertinoIcons.info_circle_fill;
      notificationTitle = 'Road Condition';
    }

    // Calculate distance if available
    String distanceText = '';
    if (post.latitude != null &&
        post.longitude != null &&
        _currentPosition != null) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        post.latitude!,
        post.longitude!,
      );
      if (distance < 1000) {
        distanceText = '${distance.toInt()}m away';
      } else {
        distanceText = '${(distance / 1000).toStringAsFixed(1)}km away';
      }
    }

    return Row(
      key: ValueKey('notification_${post.id}'),
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: notificationColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(notificationIcon, color: notificationColor, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    notificationTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: notificationColor,
                    ),
                  ),
                  if (distanceText.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      distanceText,
                      style: const TextStyle(
                        fontSize: 13,
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                post.content.length > 60
                    ? '${post.content.substring(0, 60)}...'
                    : post.content,
                style: const TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.label,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              _currentNotification = null;
              _showingStatus = false;
            });
            _notificationDisplayTimer?.cancel();
          },
          child: const Icon(
            CupertinoIcons.xmark_circle_fill,
            color: CupertinoColors.systemGrey3,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildDirectionContent() {
    if (_currentSegment == null || _distanceToNextInstruction == null) {
      return Row(
        key: const ValueKey('no-direction'),
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey5,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              CupertinoIcons.location,
              color: CupertinoColors.systemGrey,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Following route...',
              style: TextStyle(
                fontSize: 17,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      key: const ValueKey('direction'),
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: CupertinoColors.systemBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            CupertinoIcons.arrow_up,
            color: CupertinoColors.systemBlue,
            size: 28,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _distanceToNextInstruction! < 1000
                    ? '${_distanceToNextInstruction!.toInt()} m'
                    : '${(_distanceToNextInstruction! / 1000).toStringAsFixed(1)} km',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _currentSegment!.instruction,
                style: const TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _listenToStatusUpdates() {
    if (_activeTrip == null) {
      print('⚠️ Cannot listen to status updates: no active trip');
      return;
    }

    print('👂 Listening to status updates for trip: ${_activeTrip!.id}');

    // Cancel existing subscription
    _statusSubscription?.cancel();

    _statusSubscription = _convoyService
        .getStatusUpdates(_activeTrip!.id)
        .listen(
          (updates) {
            print('🔔 Received ${updates.length} status updates');
            print('   Current _showingStatus: $_showingStatus');
            print(
              '   Current _currentStatusDisplay: ${_currentStatusDisplay?.id}',
            );

            if (updates.isEmpty) {
              print('   ℹ️ No status updates yet');
              return;
            }

            if (!mounted) {
              print('   ⚠️ Widget not mounted, ignoring');
              return;
            }

            final latestStatus = updates.first;
            print(
              '   Latest status: ${latestStatus.displayText} by ${latestStatus.userName} (${latestStatus.id})',
            );

            // Only show if it's a new status
            if (_currentStatusDisplay == null ||
                _currentStatusDisplay!.id != latestStatus.id) {
              print('   ✨ Displaying new status!');

              setState(() {
                _currentStatusDisplay = latestStatus;
                _showingStatus = true;
              });

              print('   After setState: _showingStatus = $_showingStatus');

              // Cancel existing timer
              _statusDisplayTimer?.cancel();

              // Switch back to directions after 5 seconds
              _statusDisplayTimer = Timer(const Duration(seconds: 5), () {
                print('   ⏰ Timer expired, hiding status');
                if (mounted) {
                  setState(() {
                    _showingStatus = false;
                  });
                }
              });
            } else {
              print('   ℹ️ Status already displayed, skipping');
            }
          },
          onError: (error) {
            print('❌ Status stream error: $error');
          },
        );
  }

  Widget _buildChatPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: CupertinoColors.systemBackground,
        child: Column(
          children: [
            // Chat header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: CupertinoColors.systemBackground,
                border: Border(
                  bottom: BorderSide(
                    color: CupertinoColors.separator,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    CupertinoIcons.chat_bubble_2_fill,
                    color: CupertinoColors.systemPurple,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Convoy Chat',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      setState(() {
                        _showChat = false;
                      });
                    },
                    child: const Icon(
                      CupertinoIcons.xmark_circle_fill,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ],
              ),
            ),
            // Messages
            Expanded(
              child: StreamBuilder<List<TripMessage>>(
                stream: _convoyService.getMessages(_activeTrip!.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CupertinoActivityIndicator());
                  }

                  final messages = snapshot.data ?? [];

                  if (messages.isEmpty) {
                    return const Center(
                      child: Text(
                        'No messages yet\nStart the conversation!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: CupertinoColors.secondaryLabel),
                      ),
                    );
                  }

                  // Scroll to bottom when messages change
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_chatScrollController.hasClients) {
                      _chatScrollController.jumpTo(
                        _chatScrollController.position.maxScrollExtent,
                      );
                    }
                  });

                  return ListView.builder(
                    controller: _chatScrollController,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isCurrentUser =
                          message.senderId == _currentUser?.id;
                      final isSystem = message.type == MessageType.systemAlert;
                      final isFirstMessage = index == 0;

                      if (isSystem) {
                        return Center(
                          child: Container(
                            margin: EdgeInsets.only(
                              top: isFirstMessage ? 4 : 8,
                              bottom: 8,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey5,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              message.content ?? '',
                              style: const TextStyle(
                                fontSize: 12,
                                color: CupertinoColors.secondaryLabel,
                              ),
                            ),
                          ),
                        );
                      }

                      return Align(
                        alignment: isCurrentUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.only(
                            top: isFirstMessage ? 4 : 0,
                            bottom: 8,
                          ),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.65,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrentUser
                                ? CupertinoColors.systemPurple
                                : CupertinoColors.systemGrey5,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isCurrentUser)
                                Text(
                                  message.senderName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isCurrentUser
                                        ? CupertinoColors.white.withValues(
                                            alpha: 0.8,
                                          )
                                        : CupertinoColors.secondaryLabel,
                                  ),
                                ),
                              if (!isCurrentUser) const SizedBox(height: 2),
                              Text(
                                message.content ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isCurrentUser
                                      ? CupertinoColors.white
                                      : CupertinoColors.label,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Message input
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: CupertinoColors.systemBackground,
                border: Border(
                  top: BorderSide(color: CupertinoColors.separator, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _sendPhotoMessage,
                    child: const Icon(CupertinoIcons.camera, size: 24),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CupertinoTextField(
                      controller: _chatController,
                      placeholder: 'Type a message...',
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _sendTextMessage,
                    child: const Icon(
                      CupertinoIcons.arrow_up_circle_fill,
                      color: CupertinoColors.systemPurple,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTextMessage() async {
    if (_activeTrip == null ||
        _chatController.text.trim().isEmpty ||
        _currentUser == null) {
      return;
    }

    try {
      await _convoyService.sendMessage(
        tripId: _activeTrip!.id,
        senderId: _currentUser!.id,
        senderName: _currentUser!.name,
        type: MessageType.text,
        content: _chatController.text.trim(),
      );
      _chatController.clear();

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Future<void> _sendPhotoMessage() async {
    if (_activeTrip == null || _currentUser == null) return;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      try {
        await _convoyService.sendMessage(
          tripId: _activeTrip!.id,
          senderId: _currentUser!.id,
          senderName: _currentUser!.name,
          type: MessageType.photo,
          content: image.path,
        );

        // Scroll to bottom
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_chatScrollController.hasClients) {
            _chatScrollController.animateTo(
              _chatScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } catch (e) {
        print('Error sending photo: $e');
      }
    }
  }
}
