import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/district.dart';
import '../models/post.dart';
import '../models/post_category.dart';
import '../models/user.dart';
import '../models/user_location.dart';
import '../models/character.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/chatgpt_service.dart';
import '../services/nlp_service.dart';
import 'package:uuid/uuid.dart';
import '../services/analytics_service.dart' hide RiskLevel;
import '../services/road_damage_service.dart';
import '../services/location_sharing_service.dart';
import '../services/session_service.dart';
import '../services/ad_service.dart';
import '../services/premium_service.dart';
import '../widgets/animated_character_marker.dart';
import 'auth_screen.dart';
import 'forum_screen.dart';
import 'post_detail_screen.dart';
import 'create_post_screen.dart';
import 'historical_data_screen.dart';
import 'friends_screen.dart';
import 'shop_screen.dart';
import 'destination_search_screen.dart';
import 'convoy_list_screen.dart';
import '../models/ad.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Duration _onlinePresenceThreshold = Duration(seconds: 45);
  final List<Character> _allCharacters = Character.getAllCharacters();
  late final Map<String, Character> _charactersById = {
    for (final character in _allCharacters) character.id: character,
  };
  late final Character _fallbackCharacter = _allCharacters.first;
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  final LocationService _locationService = LocationService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final RoadDamageService _roadDamageService = RoadDamageService();
  final LocationSharingService _locationSharingService =
      LocationSharingService();
  final SessionService _sessionService = SessionService();
  final AdService _adService = AdService();
  final PremiumService _premiumService = PremiumService();
  final ChatGPTService? _chatGPTService = ChatGPTService(
    apiKey:
        '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',
  );
  final NLPService _nlpService = NLPService();
  final Uuid _uuid = const Uuid();
  List<District> _districts = [];
  List<Post> _allPosts = [];
  List<UserLocation> _userLocations = [];
  List<Marker> _otherUserMarkers = const <Marker>[];
  User? _currentUser;
  bool _isLoading = true;
  StreamSubscription<List<Post>>? _postsSubscription;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<UserLocation>>? _userLocationsSubscription;
  Map<String, District>? _districtMap;
  List<Marker>? _cachedPostMarkers;
  List<Marker>? _cachedEmergencyMarkers;
  List<Marker>? _cachedDangerPointMarkers; // AI-detected danger points
  List<CircleMarker>? _cachedHeatmapCircles;
  List<Ad>? _nearbyMapAds;  // Make nullable to avoid undefined issues
  bool _isPremiumUser = false;
  Timer? _adRefreshTimer;
  District? _currentDistrict;
  String? _stateFilter;
  String? _districtSummary;
  bool _isLoadingSummary = false;
  bool _showHeatmap = false;
  bool _showEmergencies = true;
  bool _showDangerPoints = true;
  bool _showAllDistricts = false; // Show only current state by default
  String _gpsStatus = 'Checking...';
  double? _currentSpeed;
  Timer? _gpsUpdateTimer;
  Timer? _locationShareTimer;
  Position? _currentUserPosition; // User's current GPS position
  final MapController _mapController =
      MapController(); // Map controller for centering
  bool _isDrivingMode = false; // Driving mode state
  double _currentZoom =
      15.0; // Track current zoom level for performance optimization

  // Box visibility and sliding state
  bool _showLegendBox = false; // Hide legend by default
  double _legendBoxOffset = 0.0; // Horizontal offset for sliding right

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
    _loadDistricts();
    _loadAllPosts();
    _loadUserLocations();
    _startLocationTracking();
    _startRoadDamageDetection();
    _startGPSStatusUpdates();
    _locationSharingService.startCleanupTimer();
    _checkPremiumAndLoadAds();
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    _positionSubscription?.cancel();
    _userLocationsSubscription?.cancel();
    _roadDamageService.stopMonitoring();
    _locationSharingService.dispose();
    _gpsUpdateTimer?.cancel();
    _locationShareTimer?.cancel();
    _adRefreshTimer?.cancel();
    super.dispose();
  }

  /// Start GPS status updates every 2 seconds
  void _startGPSStatusUpdates() async {
    await _updateGPSStatus();

    _gpsUpdateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _updateGPSStatus();
    });
  }

  /// Update GPS status information
  Future<void> _updateGPSStatus() async {
    final status = await _locationService.getGPSStatus();

    if (mounted) {
      setState(() {
        _gpsStatus = status['accuracy'] as String;
        _currentSpeed = status['currentSpeed'] as double?;
      });
    }
  }

  void _startLocationShareTimer() {
    _locationShareTimer?.cancel();
    _locationShareTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_sendLocationUpdate());
    });
    unawaited(_sendLocationUpdate());
  }

  void _stopLocationShareTimer() {
    _locationShareTimer?.cancel();
    _locationShareTimer = null;
  }

  Future<void> _sendLocationUpdate([Position? latestPosition]) async {
    if (_currentUser == null || !_currentUser!.shareLocation) return;

    Position? position = latestPosition ?? _currentUserPosition;
    if (position == null) {
      position = await _locationService.getCurrentPosition();
      if (position == null) {
        return;
      }
      if (mounted) {
        setState(() {
          _currentUserPosition = position;
        });
      }
    }

    await _locationSharingService.updateUserLocation(_currentUser!, position);
  }

  void _startRoadDamageDetection() {
    // Set up callback for road damage detection
    _roadDamageService.onRoadDamageDetected = (position, severity) {
      _handleRoadDamageDetected(position, severity);
    };

    // Only start monitoring if driving mode is enabled
    // Monitoring will be started when user enables driving mode via long press on GPS button
  }

  /// Handle road damage detection - automatically create post
  Future<void> _handleRoadDamageDetected(
    Position position,
    double severity,
  ) async {
    // Find nearest district
    final nearestDistrict = _locationService.findNearestDistrict(
      position,
      _districts,
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

  void _startLocationTracking() async {
    final hasPermission = await _locationService.checkPermission();
    if (!hasPermission) {
      return;
    }

    _positionSubscription = _locationService
        .getPositionStream(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update every 10 meters
        )
        .listen(
          (position) {
            // Update user position for map marker
            if (mounted) {
              final wasFirstPosition = _currentUserPosition == null;
              setState(() {
                _currentUserPosition = position;
              });

              // Center map on user location on first position update
              if (wasFirstPosition) {
                _mapController.move(
                  LatLng(position.latitude, position.longitude),
                  15.0,
                );
                unawaited(_syncStateFilterWithPosition(position));
                // Load map ads now that we have position
                unawaited(_loadNearbyMapAds());
              }

              // Share location if enabled
              if (_currentUser != null && _currentUser!.shareLocation) {
                unawaited(_sendLocationUpdate(position));
              }
            }

            if (_districts.isEmpty) return;

            final nearestDistrict = _locationService.findNearestDistrict(
              position,
              _districts,
            );

            if (nearestDistrict != null &&
                (_currentDistrict == null ||
                    nearestDistrict.id != _currentDistrict!.id)) {
              setState(() {
                _currentDistrict = nearestDistrict;
                _stateFilter = nearestDistrict.state;
                _districtSummary = null;
              });
              _showDistrictAlert(nearestDistrict);
              _loadDistrictSummary(nearestDistrict);
            }
          },
          onError: (error) {
            print('Location stream error: $error');
          },
        );
  }

  void _showDistrictAlert(District district) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Entering New Area'),
        content: Text('You are now in ${district.name}, ${district.state}'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('View Forum'),
            onPressed: () {
              Navigator.pop(context);
              _navigateToForum(district);
            },
          ),
        ],
      ),
    );
  }

  /// Generates AI traffic summary for a district using ChatGPT
  ///
  /// Triggered automatically when:
  /// - User enters a new district (detected via location tracking)
  ///
  /// Can also be triggered manually via refresh button in the UI
  Future<void> _loadDistrictSummary(District district) async {
    // ChatGPT service is optional - skip if not configured
    if (_chatGPTService == null) return;

    setState(() {
      _isLoadingSummary = true;
    });

    try {
      final districtPosts = _allPosts
          .where((post) => post.districtId == district.id)
          .take(20)
          .toList();

      final summary = await _chatGPTService.generateTrafficSummary(
        district,
        districtPosts,
      );

      if (mounted) {
        setState(() {
          _districtSummary = summary;
          _isLoadingSummary = false;
        });
      }
    } catch (e) {
      print('Error loading summary: $e');
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
        });
      }
    }
  }

  Future<void> _loadDistricts() async {
    final districts = await _firebaseService.getDistricts();
    if (districts.isEmpty) {
      await _firebaseService.initializeDistricts();
      final newDistricts = await _firebaseService.getDistricts();
      setState(() {
        _districts = newDistricts;
        _districtMap = {for (var d in newDistricts) d.id: d};
        _isLoading = false;
      });
    } else {
      setState(() {
        _districts = districts;
        _districtMap = {for (var d in districts) d.id: d};
        _isLoading = false;
      });
    }
    await _syncStateFilterWithPosition();
  }

  void _loadAllPosts() {
    // Listen to all posts for real-time updates
    _postsSubscription = _firebaseService.getAllPostsStream().listen((posts) {
      if (mounted) {
        setState(() {
          _allPosts = posts;
          _cachedPostMarkers = null; // Invalidate cache
          _cachedEmergencyMarkers = null;
          _cachedDangerPointMarkers = null; // Invalidate danger points cache
          _cachedHeatmapCircles = null;
        });
      }
    });
  }

  void _setLegendVisibility(bool visible) {
    setState(() {
      _showLegendBox = visible;
      _legendBoxOffset = visible ? 0 : -350;
    });
  }

  void _toggleLegendVisibility() {
    _setLegendVisibility(!_showLegendBox);
  }

  void _loadUserLocations() {
    // Listen to user locations for real-time updates
    _userLocationsSubscription = _locationSharingService
        .getUserLocationsStream()
        .listen((locations) {
          if (mounted) {
            setState(() {
              _userLocations = locations;
              _otherUserMarkers = _createOtherUserMarkers(locations);
            });
          }
        });
  }

  List<Marker> _buildPostMarkers() {
    // Show simplified markers at lower zoom levels
    final showSimplified = _currentZoom < 11.0;

    if (_cachedPostMarkers != null &&
        _allPosts.length == _cachedPostMarkers!.length &&
        !showSimplified) {
      return _cachedPostMarkers!;
    }

    // Don't show individual posts at very low zoom
    if (_currentZoom < 9.0) return [];

    _cachedPostMarkers = _allPosts
        .map((post) {
          double lat;
          double lon;

          if (post.latitude != null && post.longitude != null) {
            lat = post.latitude!;
            lon = post.longitude!;
          } else {
            final district = _districtMap?[post.districtId];
            if (district == null) return null;
            lat = district.latitude;
            lon = district.longitude;
          }

          return Marker(
            point: LatLng(lat, lon),
            width: 32,
            height: 32,
            child: GestureDetector(
              onTap: () => _navigateToPostDetail(post),
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
        .whereType<Marker>()
        .toList();

    return _cachedPostMarkers!;
  }

  List<Marker> _buildDistrictMarkers() {
    // Skip district markers at high zoom levels to reduce clutter and improve performance
    if (_currentZoom > 13.0) return [];

    final districtsToShow = _getVisibleDistricts();
    final postCounts = _analyticsService.getPostCountsByDistrict(_allPosts);

    return districtsToShow.map((district) {
      final postCount = postCounts[district.id] ?? 0;

      return Marker(
        point: LatLng(district.latitude, district.longitude),
        width: 70,
        height: 100,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: () => _navigateToForum(district),
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // iOS-style pin head with post count badge and connected tail
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Pin head with badge
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Pin head circle - centered
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemRed,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: CupertinoColors.white,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: CupertinoColors.black.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: const Icon(
                              CupertinoIcons.location_fill,
                              color: CupertinoColors.white,
                              size: 16,
                            ),
                          ),
                          // Post count badge - positioned at top right
                          if (postCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemOrange,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: CupertinoColors.white,
                                    width: 1.5,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Center(
                                  child: Text(
                                    postCount > 99
                                        ? '99+'
                                        : postCount.toString(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: CupertinoColors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // iOS-style pin tail - centered below icon
                    Container(
                      width: 3,
                      height: 12,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemRed,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(1.5),
                          bottomRight: Radius.circular(1.5),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.black.withValues(alpha: 0.2),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // District name label
                Container(
                  constraints: const BoxConstraints(maxWidth: 120),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    district.name,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label,
                      letterSpacing: -0.2,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildEmergencyMarkers() {
    if (!_showEmergencies) return [];
    if (_cachedEmergencyMarkers != null) {
      return _cachedEmergencyMarkers!;
    }

    final emergencies = _analyticsService.getCurrentEmergencies(_allPosts);

    _cachedEmergencyMarkers = emergencies
        .map((post) {
          double lat;
          double lon;

          if (post.latitude != null && post.longitude != null) {
            lat = post.latitude!;
            lon = post.longitude!;
          } else {
            final district = _districtMap?[post.districtId];
            if (district == null) return null;
            lat = district.latitude;
            lon = district.longitude;
          }

          return Marker(
            point: LatLng(lat, lon),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _navigateToPostDetail(post),
              child: Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed,
                  shape: BoxShape.circle,
                  border: Border.all(color: CupertinoColors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.systemRed.withValues(alpha: 0.6),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: CupertinoColors.white,
                  size: 20,
                ),
              ),
            ),
          );
        })
        .whereType<Marker>()
        .toList();

    return _cachedEmergencyMarkers!;
  }

  List<CircleMarker> _buildHeatmapCircles() {
    if (!_showHeatmap) return [];
    if (_cachedHeatmapCircles != null) {
      return _cachedHeatmapCircles!;
    }

    final heatmapData = _analyticsService.calculateHeatmapData(_allPosts);
    if (heatmapData.isEmpty) return [];

    final maxValue = heatmapData.values.reduce((a, b) => a > b ? a : b);
    if (maxValue == 0) return [];

    _cachedHeatmapCircles = heatmapData.entries
        .map((entry) {
          final district = _districtMap?[entry.key];
          if (district == null) return null;

          final intensity = (entry.value / maxValue).clamp(0.0, 1.0);
          final radius = 5000 + (intensity * 15000); // 5km to 20km radius

          return CircleMarker(
            point: LatLng(district.latitude, district.longitude),
            radius: radius,
            color: CupertinoColors.systemOrange.withValues(
              alpha: 0.2 * intensity,
            ),
            useRadiusInMeter: true,
          );
        })
        .whereType<CircleMarker>()
        .toList();

    return _cachedHeatmapCircles!;
  }

  void _navigateToForum(District district) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) =>
            ForumScreen(district: district, currentUser: _currentUser),
      ),
    );
  }

  void _navigateToPostDetail(Post post) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) =>
            PostDetailScreen(post: post, currentUser: _currentUser),
      ),
    );
  }

  void _handleProfileButton() {
    if (_currentUser == null) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => AuthScreen(
            onAuthSuccess: (user) {
              if (!mounted) return;
              setState(() {
                _currentUser = user;
                _otherUserMarkers = _createOtherUserMarkers(_userLocations);
              });
              if (user.shareLocation) {
                _startLocationShareTimer();
              }
              Future.microtask(_openFriendsScreen);
            },
          ),
        ),
      );
    } else {
      _openFriendsScreen();
    }
  }

  void _openFriendsScreen() {
    if (_currentUser == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) =>
            FriendsScreen(currentUser: _currentUser!, onLogout: _handleLogout),
      ),
    );
  }

  void _handleLogout() {
    if (!mounted) return;
    if (_currentUser != null) {
      _stopLocationShareTimer();
      unawaited(_locationSharingService.stopSharingLocation(_currentUser!.id));
    }
    unawaited(_sessionService.clear());
    setState(() {
      _currentUser = null;
      _otherUserMarkers = _createOtherUserMarkers(_userLocations);
    });
  }

  Future<void> _restoreSession() async {
    final savedUserId = await _sessionService.getSavedUserId();
    if (savedUserId == null) return;

    final savedUser = await _authService.getUserById(savedUserId);
    if (!mounted) return;

    if (savedUser == null) {
      await _sessionService.clear();
      return;
    }

    setState(() {
      _currentUser = savedUser;
      _otherUserMarkers = _createOtherUserMarkers(_userLocations);
    });

    if (savedUser.shareLocation) {
      _startLocationShareTimer();
    }
  }

  void _showLocationPermissionDialog() {
    if (!mounted) return;
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Location Permission Needed'),
        content: const Text(
          'Enable location access to share your live position with friends.',
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

  Future<void> _toggleLocationSharing() async {
    if (_currentUser == null) return;

    final enableSharing = !_currentUser!.shareLocation;

    if (enableSharing) {
      final hasPermission = await _locationService.checkPermission();
      if (!hasPermission) {
        _showLocationPermissionDialog();
        return;
      }
    }

    final updatedUser = _currentUser!.copyWith(shareLocation: enableSharing);

    try {
      await _firebaseService.updateUser(updatedUser);

      setState(() {
        _currentUser = updatedUser;
      });

      if (enableSharing) {
        _startLocationShareTimer();
      } else {
        _stopLocationShareTimer();
        await _locationSharingService.stopSharingLocation(_currentUser!.id);
      }

      // No confirmation dialog to keep toggle non-intrusive
    } catch (e) {
      print('Error toggling location sharing: $e');
    }
  }

  void _openShopScreen() {
    if (_currentUser == null) {
      _handleProfileButton();
      return;
    }

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ShopScreen(
          currentUser: _currentUser!,
          onCharacterSelected: (updatedUser) {
            if (mounted) {
              setState(() {
                _currentUser = updatedUser;
              });
            }
            if (_currentUserPosition != null &&
                _currentUser != null &&
                _currentUser!.shareLocation) {
              unawaited(
                _locationSharingService.updateUserLocation(
                  _currentUser!,
                  _currentUserPosition!,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  void _openNavigationSearch() {
    if (_currentUserPosition == null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Location Required'),
          content: const Text(
            'Please enable location services to use navigation.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => DestinationSearchScreen(
          currentPosition: _currentUserPosition!,
          districts: _districts,
          allPosts: _allPosts,
        ),
      ),
    );
  }

  void _openConvoyScreen() {
    if (_currentUser == null) {
      _handleProfileButton();
      return;
    }

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ConvoyListScreen(currentUser: _currentUser!),
      ),
    );
  }

  void _showCreatePostDialog(LatLng location) {
    // Find nearest district
    District? nearestDistrict = _findNearestDistrict(location);

    if (nearestDistrict == null) return;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Create Post'),
        content: Text(
          'Create a new post for ${nearestDistrict.name}?\n\nLocation: ${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Create Post'),
            onPressed: () {
              Navigator.pop(context);
              _navigateToCreatePostWithLocation(nearestDistrict, location);
            },
          ),
        ],
      ),
    );
  }

  void _navigateToCreatePostWithLocation(
    District district,
    LatLng location, {
    bool isRoadDamage = false,
    double? roadDamageSeverity,
  }) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => CreatePostScreen(
          district: district,
          latitude: location.latitude,
          longitude: location.longitude,
          isRoadDamage: isRoadDamage,
          roadDamageSeverity: roadDamageSeverity,
          currentUser: _currentUser,
        ),
      ),
    );
  }

  /// Build user location marker (current user - character or dot)
  List<Marker> _buildUserLocationMarker() {
    if (_currentUserPosition == null) return [];

    // Show character ONLY if location sharing is enabled
    if (_currentUser != null &&
        _currentUser!.shareLocation &&
        _currentUser!.selectedCharacter != null) {
      // Find character by ID
      final character = Character.getAllCharacters().firstWhere(
        (c) => c.id == _currentUser!.selectedCharacter,
        orElse: () => Character.getAllCharacters().first,
      );

      // Lancer needs bigger scale
      final isLancer = character.name.toLowerCase() == 'lancer';
      final scale = isLancer ? 1.4 : 1.0;

      return [
        Marker(
          point: LatLng(
            _currentUserPosition!.latitude,
            _currentUserPosition!.longitude,
          ),
          width: 120,
          height: 120,
          alignment: Alignment.center,
          child: AnimatedCharacterMarker(
            key: ValueKey(_currentUser!.selectedCharacter),
            actions: character.actions,
            userName: _currentUser!.name,
            enableClick: true,
            scale: scale,
          ),
        ),
      ];
    }

    // Fallback to blue dot
    return [
      Marker(
        point: LatLng(
          _currentUserPosition!.latitude,
          _currentUserPosition!.longitude,
        ),
        width: 50,
        height: 50,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulsing circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
            // Middle circle
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
            // Inner dot (user position)
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: CupertinoColors.systemBlue,
                shape: BoxShape.circle,
                border: Border.all(color: CupertinoColors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemBlue.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            // Direction arrow (if heading available)
            if (_currentUserPosition!.heading != 0.0)
              Transform.rotate(
                angle: (_currentUserPosition!.heading * 3.14159) / 180,
                child: const Icon(
                  CupertinoIcons.arrow_up,
                  color: CupertinoColors.white,
                  size: 12,
                ),
              ),
          ],
        ),
      ),
    ];
  }

  bool _isUserOnline(UserLocation location, DateTime now) {
    return now.difference(location.lastUpdate) <= _onlinePresenceThreshold;
  }

  List<District> _getVisibleDistricts() {
    if (_showAllDistricts) {
      return _districts;
    }
    final fallbackState = _districts.isNotEmpty ? _districts.first.state : null;
    final currentState =
        _stateFilter ?? _currentDistrict?.state ?? fallbackState;
    if (currentState == null) {
      return _districts;
    }
    return _districts
        .where((district) => district.state == currentState)
        .toList();
  }

  Future<void> _syncStateFilterWithPosition([Position? position]) async {
    Position? reference = position ?? _currentUserPosition;
    if (reference == null) {
      reference = await _locationService.getCurrentPosition();
      if (reference == null) {
        return;
      }
      if (mounted) {
        setState(() {
          _currentUserPosition = reference;
        });
      }
    }

    if (_districts.isEmpty) return;

    final nearestDistrict = _locationService.findNearestDistrict(
      reference,
      _districts,
    );
    if (nearestDistrict == null) return;

    final bool districtChanged =
        _currentDistrict == null || nearestDistrict.id != _currentDistrict!.id;

    if (!mounted) return;

    setState(() {
      _currentDistrict = nearestDistrict;
      _stateFilter = nearestDistrict.state;
      if (districtChanged) {
        _districtSummary = null;
      }
    });

    if (districtChanged) {
      _loadDistrictSummary(nearestDistrict);
    }
  }

  List<Marker> _createOtherUserMarkers(List<UserLocation> locations) {
    final now = DateTime.now();
    final currentUserId = _currentUser?.id;
    return locations
        .where(
          (location) =>
              location.userId != currentUserId && _isUserOnline(location, now),
        )
        .map((location) {
          final character =
              _charactersById[location.selectedCharacter] ?? _fallbackCharacter;
          final isLancer = character.name.toLowerCase() == 'lancer';
          final scale = isLancer ? 1.4 : 1.0;

          // Determine if user is moving (speed > 1 km/h)
          final isMoving = (location.speed ?? 0) > 0.28; // 0.28 m/s = ~1 km/h

          return Marker(
            point: LatLng(location.latitude, location.longitude),
            width: 100,
            height: 100,
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedCharacterMarker(
                key: ValueKey(
                  '${location.userId}_${location.selectedCharacter}',
                ),
                actions: character.actions,
                userName: location.userName,
                enableClick: false,
                scale: scale,
                isMoving: isMoving,
              ),
            ),
          );
        })
        .toList();
  }

  /// Check premium status and load map ads
  Future<void> _checkPremiumAndLoadAds() async {
    try {
      if (_currentUser == null) return;
      
      final isPremium = await _premiumService.isPremiumUser(_currentUser!.id);
      if (!mounted) return;
      
      setState(() => _isPremiumUser = isPremium);
      
      if (!isPremium) {
        print('HomeScreen: User is not premium, loading map ads');
        unawaited(_loadNearbyMapAds());
        
        // Refresh ads every 30 seconds
        _adRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          if (mounted) _loadNearbyMapAds();
        });
      } else {
        print('HomeScreen: User is premium, no map ads will be shown');
      }
    } catch (e) {
      print('Error checking premium status for ads: $e');
    }
  }
  
  /// Load nearby map logo ads
  Future<void> _loadNearbyMapAds() async {
    try {
      if (_currentUserPosition == null || _isPremiumUser) {
        print('HomeScreen: Cannot load map ads - position: ${_currentUserPosition != null}, premium: $_isPremiumUser');
        return;
      }
      
      print('HomeScreen: Loading map ads at (${_currentUserPosition!.latitude}, ${_currentUserPosition!.longitude})');
      
      final ads = await _adService.getNearbyAds(
        _currentUserPosition!.latitude,
        _currentUserPosition!.longitude,
        type: AdType.mapLogo,
      );
      
      print('HomeScreen: Found ${ads.length} map logo ads');
      
      if (mounted) {
        setState(() {
          _nearbyMapAds = ads;
        });
      }
    } catch (e) {
      print('Error loading map ads: $e');
    }
  }
  
  /// Build map logo ad markers (styled like posts)
  List<Marker> _buildMapAdMarkers() {
    try {
      if (_isPremiumUser) return [];
      
      final ads = _nearbyMapAds;
      if (ads == null) return [];
      if (ads.isEmpty) return [];
      
      final markers = <Marker>[];
      
      for (final ad in ads) {
        if (ad.latitude == null || ad.longitude == null) continue;
        
        // Style like posts: 32x32 circular markers
        markers.add(Marker(
          point: LatLng(ad.latitude!, ad.longitude!),
          width: 32,
          height: 32,
          child: GestureDetector(
            onTap: () {
              try {
                _adService.recordClick(ad.id);
                _showMapAdDetail(ad);
              } catch (e) {
                print('Error handling ad tap: $e');
              }
            },
            child: Container(
              decoration: BoxDecoration(
                // Yellow/gold color for ads to distinguish from posts
                color: const Color(0xFFFFB800),
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
                  CupertinoIcons.money_dollar_circle_fill,
                  color: CupertinoColors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ));
      }
      
      return markers;
    } catch (e) {
      print('Error building map ad markers: $e');
      return [];
    }
  }
  
  /// Show map ad detail popup
  void _showMapAdDetail(Ad ad) {
    try {
      // Record impression when detail is shown
      _adService.recordImpression(ad.id);
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(ad.merchantName),
        message: Column(
          children: [
            if (ad.imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  ad.imageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: CupertinoColors.systemGrey6,
                    child: const Icon(
                      CupertinoIcons.photo,
                      size: 50,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              ad.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(ad.content),
            if (ad.merchantAddress != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.location_fill,
                    size: 16,
                    color: CupertinoColors.systemGrey,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      ad.merchantAddress!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: CupertinoColors.secondaryLabel,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (ad.merchantPhone != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.phone_fill,
                    size: 16,
                    color: CupertinoColors.systemGrey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ad.merchantPhone!,
                    style: const TextStyle(
                      color: CupertinoColors.secondaryLabel,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          if (ad.latitude != null && ad.longitude != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                // Center map on ad location
                _mapController.move(
                  LatLng(ad.latitude!, ad.longitude!),
                  16.0,
                );
              },
              child: const Text('View Location'),
            ),
          if (ad.merchantPhone != null)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                // In a real app, this would open phone dialer
                showCupertinoDialog(
                  context: context,
                  builder: (context) => CupertinoAlertDialog(
                    title: const Text('Call Merchant'),
                    content: Text('Call ${ad.merchantPhone}?'),
                    actions: [
                      CupertinoDialogAction(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      CupertinoDialogAction(
                        isDefaultAction: true,
                        onPressed: () {
                          Navigator.pop(context);
                          // TODO: Implement actual phone call
                        },
                        child: const Text('Call'),
                      ),
                    ],
                  ),
                );
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
    } catch (e) {
      print('Error showing map ad detail: $e');
    }
  }

  /// Build danger point markers based on AI analysis (high risk posts)
  List<Marker> _buildDangerPointMarkers() {
    if (!_showDangerPoints) return [];
    if (_cachedDangerPointMarkers != null) {
      return _cachedDangerPointMarkers!;
    }

    // Filter posts with high/critical risk levels
    final dangerPosts = _allPosts.where((post) {
      if (post.riskLevel == null) return false;
      return post.riskLevel == RiskLevel.high ||
          post.riskLevel == RiskLevel.critical;
    }).toList();

    _cachedDangerPointMarkers = dangerPosts
        .map((post) {
          double lat;
          double lon;

          if (post.latitude != null && post.longitude != null) {
            lat = post.latitude!;
            lon = post.longitude!;
          } else {
            final district = _districtMap?[post.districtId];
            if (district == null) return null;
            lat = district.latitude;
            lon = district.longitude;
          }

          return Marker(
            point: LatLng(lat, lon),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _navigateToPostDetail(post),
              child: Container(
                decoration: BoxDecoration(
                  color: post.riskLevel == RiskLevel.critical
                      ? CupertinoColors.systemRed
                      : CupertinoColors.systemOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: CupertinoColors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (post.riskLevel == RiskLevel.critical
                                  ? CupertinoColors.systemRed
                                  : CupertinoColors.systemOrange)
                              .withValues(alpha: 0.6),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.exclamationmark_triangle_fill,
                  color: CupertinoColors.white,
                  size: 20,
                ),
              ),
            ),
          );
        })
        .whereType<Marker>()
        .toList();

    return _cachedDangerPointMarkers!;
  }

  District? _findNearestDistrict(LatLng location) {
    if (_districts.isEmpty) return null;

    District? nearest;
    double minDistance = double.infinity;

    for (var district in _districts) {
      final distance = _calculateDistance(
        location.latitude,
        location.longitude,
        district.latitude,
        district.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearest = district;
      }
    }

    return nearest;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Simple distance calculation
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    return dLat * dLat + dLon * dLon;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Roady'),
        backgroundColor: CupertinoColors.systemBackground,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.chart_bar_square),
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(
                builder: (context) => HistoricalDataScreen(
                  posts: _allPosts,
                  districts: _districts,
                ),
              ),
            );
          },
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            _currentUser == null
                ? CupertinoIcons.person_crop_circle_badge_plus
                : CupertinoIcons.person_crop_circle_fill,
          ),
          onPressed: _handleProfileButton,
        ),
      ),
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : Stack(
              children: [
                // Map Section - Full Screen
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentUserPosition != null
                        ? LatLng(
                            _currentUserPosition!.latitude,
                            _currentUserPosition!.longitude,
                          )
                        : const LatLng(3.1390, 101.6869), // KL default
                    initialZoom: _currentUserPosition != null ? 15.0 : 10.0,
                    minZoom: 6.0,
                    maxZoom: 19.0, // Higher zoom for road detail
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onLongPress: (tapPosition, point) {
                      _showCreatePostDialog(point);
                    },
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) {
                        setState(() {
                          _currentZoom = position.zoom;
                        });
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      // CartoDB Positron - Minimal road-focused style like Waze (roads only, minimal labels)
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.roadmobile.app',
                      retinaMode: true,
                      maxZoom: 19,
                      maxNativeZoom: 19,
                      keepBuffer:
                          2, // Reduced from 8 to 2 for better performance
                      panBuffer:
                          1, // Reduced from 2 to 1 for better performance
                      tileProvider: NetworkTileProvider(),
                      tileDisplay: const TileDisplay.fadeIn(
                        duration: Duration(milliseconds: 100),
                      ),
                      // Alternative: OpenStreetMap France (more detailed roads)
                      // urlTemplate: 'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
                    ),
                    // Heatmap layer
                    if (_showHeatmap)
                      CircleLayer(circles: _buildHeatmapCircles()),
                    // Danger point markers (AI-detected high risk)
                    MarkerLayer(markers: _buildDangerPointMarkers()),
                    // Post markers (incidents)
                    if (_allPosts.isNotEmpty)
                      MarkerLayer(markers: _buildPostMarkers()),
                    // Emergency markers
                    MarkerLayer(markers: _buildEmergencyMarkers()),
                    // District markers (forums)
                    MarkerLayer(markers: _buildDistrictMarkers()),
                    // Map logo ads (if not premium)
                    if (!_isPremiumUser && _nearbyMapAds != null && _nearbyMapAds!.isNotEmpty)
                      MarkerLayer(markers: _buildMapAdMarkers()),
                    // Other users markers with animated characters
                    MarkerLayer(markers: _otherUserMarkers),
                    // User location marker (always on top)
                    if (_currentUserPosition != null)
                      MarkerLayer(markers: _buildUserLocationMarker()),
                  ],
                ),
                // Map legend (slides to right to hide)
                Positioned(
                  top: 16,
                  right: _showLegendBox ? 16 + _legendBoxOffset : -350,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _legendBoxOffset += details.delta.dx;
                          if (_legendBoxOffset > 0) _legendBoxOffset = 0;
                          if (_legendBoxOffset < -350) _legendBoxOffset = -350;
                        });
                      },
                      onHorizontalDragEnd: (details) {
                        if (_legendBoxOffset < -175) {
                          _setLegendVisibility(false);
                        } else {
                          setState(() {
                            _legendBoxOffset = 0;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.black.withValues(
                                alpha: 0.08,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // User Location
                            if (_currentUserPosition != null)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _toggleLegendVisibility,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: CupertinoColors.systemBlue,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Your Location',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_currentUserPosition != null)
                              const SizedBox(height: 10),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _toggleLegendVisibility,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: CupertinoColors.systemRed,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Districts',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _toggleLegendVisibility,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: CupertinoColors.systemOrange,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Posts',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _toggleLegendVisibility,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.systemRed,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: CupertinoColors.white,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Emergencies',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 0,
                              onPressed: () {
                                setState(() {
                                  _showDangerPoints = !_showDangerPoints;
                                  _cachedDangerPointMarkers = null;
                                });
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _showDangerPoints
                                          ? CupertinoColors.systemRed
                                          : CupertinoColors.tertiaryLabel,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Danger Points',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _showDangerPoints
                                          ? CupertinoColors.label
                                          : CupertinoColors.tertiaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 0,
                              onPressed: () {
                                setState(() {
                                  _showHeatmap = !_showHeatmap;
                                  _cachedHeatmapCircles = null;
                                });
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _showHeatmap
                                          ? CupertinoColors.systemOrange
                                          : CupertinoColors.tertiaryLabel,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Heatmap',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _showHeatmap
                                          ? CupertinoColors.label
                                          : CupertinoColors.tertiaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 0,
                              onPressed: () async {
                                setState(() {
                                  _showAllDistricts = !_showAllDistricts;
                                  if (_showAllDistricts) {
                                    _stateFilter = null;
                                  }
                                });
                                if (!_showAllDistricts) {
                                  await _syncStateFilterWithPosition();
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _showAllDistricts
                                          ? CupertinoColors.systemRed
                                          : CupertinoColors.tertiaryLabel,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _showAllDistricts
                                        ? 'All Districts'
                                        : 'Current State',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _showAllDistricts
                                          ? CupertinoColors.label
                                          : CupertinoColors.tertiaryLabel,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_allPosts.length} active',
                              style: const TextStyle(
                                fontSize: 11,
                                color: CupertinoColors.secondaryLabel,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Draggable Regional Forums Panel
                DraggableScrollableSheet(
                  initialChildSize: 0.33, // Start at 33% of screen height
                  minChildSize: 0.33, // Minimum 33% of screen height
                  maxChildSize: 1.0, // Maximum 100% - can pull to bottom
                  snap: true,
                  snapSizes: const [0.33, 0.66, 1.0], // Three snap positions
                  builder: (context, scrollController) {
                    final visibleDistricts = _getVisibleDistricts();
                    return Container(
                      decoration: const BoxDecoration(
                        color: CupertinoColors.systemGroupedBackground,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: CustomScrollView(
                        controller: scrollController,
                        physics: const ClampingScrollPhysics(),
                        slivers: [
                          // Header with drag handle
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Drag handle
                                Center(
                                  child: Container(
                                    margin: const EdgeInsets.only(
                                      top: 12,
                                      bottom: 8,
                                    ),
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.tertiaryLabel,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                // Title
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    16,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              'Regional Forums',
                                              style: TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                          ),
                                          if (!_showAllDistricts &&
                                              _currentDistrict != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    CupertinoColors.systemGrey6,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                _currentDistrict!.state,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: CupertinoColors.label,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      // Current District Summary
                                      if (_currentDistrict != null) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: CupertinoColors.systemBlue
                                                .withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: CupertinoColors.systemBlue
                                                  .withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                    CupertinoIcons
                                                        .location_fill,
                                                    size: 16,
                                                    color: CupertinoColors
                                                        .systemBlue,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      'Current: ${_currentDistrict!.name}',
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: CupertinoColors
                                                            .systemBlue,
                                                      ),
                                                    ),
                                                  ),
                                                  if (_chatGPTService != null)
                                                    CupertinoButton(
                                                      padding: EdgeInsets.zero,
                                                      minSize: 0,
                                                      onPressed:
                                                          _currentDistrict !=
                                                              null
                                                          ? () => _loadDistrictSummary(
                                                              _currentDistrict!,
                                                            )
                                                          : null,
                                                      child: Icon(
                                                        CupertinoIcons
                                                            .arrow_clockwise,
                                                        size: 16,
                                                        color: _isLoadingSummary
                                                            ? CupertinoColors
                                                                  .tertiaryLabel
                                                            : CupertinoColors
                                                                  .systemBlue,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              if (_isLoadingSummary) ...[
                                                const SizedBox(height: 8),
                                                const CupertinoActivityIndicator(),
                                              ] else if (_districtSummary !=
                                                  null) ...[
                                                const SizedBox(height: 8),
                                                Text(
                                                  _districtSummary!,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color:
                                                        CupertinoColors.label,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Scrollable list
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final district = visibleDistricts[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemBackground,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: CupertinoListTile(
                                    leading: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.systemRed
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(
                                        CupertinoIcons.map_pin_ellipse,
                                        color: CupertinoColors.systemRed,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(
                                      district.name,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                    subtitle: Text(
                                      district.state,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: CupertinoColors.secondaryLabel,
                                      ),
                                    ),
                                    trailing: const Icon(
                                      CupertinoIcons.chevron_right,
                                      size: 16,
                                      color: CupertinoColors.tertiaryLabel,
                                    ),
                                    onTap: () => _navigateToForum(district),
                                  ),
                                );
                              }, childCount: visibleDistricts.length),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Shop Button
                Positioned(
                  left: 16,
                  top: 16,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _openShopScreen,
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
                        CupertinoIcons.bag,
                        color: CupertinoColors.systemBlue,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                // Location Sharing Toggle
                if (_currentUser != null)
                  Positioned(
                    left: 16,
                    top: 70,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _toggleLocationSharing,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _currentUser!.shareLocation
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
                          _currentUser!.shareLocation
                              ? CupertinoIcons.dot_radiowaves_left_right
                              : CupertinoIcons.dot_square,
                          color: _currentUser!.shareLocation
                              ? CupertinoColors.white
                              : CupertinoColors.systemGrey,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                // Navigation Button (moved to top left)
                if (_currentUserPosition != null)
                  Positioned(
                    left: 16,
                    top: 124,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _openNavigationSearch,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBlue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.systemBlue.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          CupertinoIcons.location_north_fill,
                          color: CupertinoColors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                // Convoy/Drive Party Button
                if (_currentUser != null)
                  Positioned(
                    left: 16,
                    top: 178,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _openConvoyScreen,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemPurple,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.systemPurple.withValues(
                                alpha: 0.4,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          CupertinoIcons.car_detailed,
                          color: CupertinoColors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                // Center on User Location Button
                if (_currentUserPosition != null)
                  Positioned(
                    bottom: 250, // Moved down
                    right: 16,
                    child: GestureDetector(
                      onLongPress: () {
                        setState(() {
                          _isDrivingMode = !_isDrivingMode;
                        });
                        if (_isDrivingMode) {
                          // Enable driving mode features
                          _roadDamageService.startMonitoring();
                        } else {
                          // Disable driving mode features
                          _roadDamageService.stopMonitoring();
                        }
                        // Show feedback
                        showCupertinoDialog(
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: Text(
                              _isDrivingMode
                                  ? 'Driving Mode Enabled'
                                  : 'Driving Mode Disabled',
                            ),
                            content: Text(
                              _isDrivingMode
                                  ? 'Road damage detection is now active. The app will automatically detect and report road damage while you drive.'
                                  : 'Driving mode has been disabled.',
                            ),
                            actions: [
                              CupertinoDialogAction(
                                child: const Text('OK'),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        );
                      },
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          _mapController.move(
                            LatLng(
                              _currentUserPosition!.latitude,
                              _currentUserPosition!.longitude,
                            ),
                            15.0,
                          );
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _isDrivingMode
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
                            CupertinoIcons.location_fill,
                            color: _isDrivingMode
                                ? CupertinoColors.white
                                : CupertinoColors.systemBlue,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Show Legend Box Button (when hidden)
                if (!_showLegendBox)
                  Positioned(
                    top: 16,
                    right: 8,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => _setLegendVisibility(true),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemBackground,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.black.withValues(
                                alpha: 0.1,
                              ),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          CupertinoIcons.list_bullet,
                          color: CupertinoColors.systemBlue,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
