import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/district.dart';
import '../models/post.dart';
import '../models/post_category.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../services/chatgpt_service.dart';
import '../services/analytics_service.dart' hide RiskLevel;
import '../services/road_damage_service.dart';
import 'forum_screen.dart';
import 'debug_screen.dart';
import 'post_detail_screen.dart';
import 'create_post_screen.dart';
import 'historical_data_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final LocationService _locationService = LocationService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final RoadDamageService _roadDamageService = RoadDamageService();
  final ChatGPTService? _chatGPTService = ChatGPTService(
    apiKey:
        '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',
  );
  List<District> _districts = [];
  List<Post> _allPosts = [];
  bool _isLoading = true;
  StreamSubscription<List<Post>>? _postsSubscription;
  StreamSubscription<Position>? _positionSubscription;
  Map<String, District>? _districtMap;
  List<Marker>? _cachedPostMarkers;
  List<Marker>? _cachedEmergencyMarkers;
  List<Marker>? _cachedDangerPointMarkers; // AI-detected danger points
  List<CircleMarker>? _cachedHeatmapCircles;
  District? _currentDistrict;
  String? _districtSummary;
  bool _isLoadingSummary = false;
  bool _showHeatmap = false;
  bool _showEmergencies = true;
  bool _showDangerPoints = true;
  bool _showAllDistricts = false; // Show only current state by default
  String _gpsStatus = 'Checking...';
  double? _currentSpeed;
  Timer? _gpsUpdateTimer;
  Position? _currentUserPosition; // User's current GPS position
  final MapController _mapController =
      MapController(); // Map controller for centering
  bool _isDrivingMode = false; // Driving mode state

  // Box visibility and sliding state
  bool _showLegendBox = false; // Hide legend by default
  double _legendBoxOffset = 0.0; // Horizontal offset for sliding right

  @override
  void initState() {
    super.initState();
    _loadDistricts();
    _loadAllPosts();
    _startLocationTracking();
    _startRoadDamageDetection();
    _startGPSStatusUpdates();
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    _positionSubscription?.cancel();
    _roadDamageService.stopMonitoring();
    _gpsUpdateTimer?.cancel();
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

  void _startRoadDamageDetection() {
    // Set up callback for road damage detection
    _roadDamageService.onRoadDamageDetected = (position, severity) {
      _handleRoadDamageDetected(position, severity);
    };

    // Only start monitoring if driving mode is enabled
    // Monitoring will be started when user enables driving mode via long press on GPS button
  }

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

    // Show alert to user
    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Road Damage Detected'),
          content: Text(
            'Road damage detected at your location.\n\n'
            'Severity: ${(severity * 100).toStringAsFixed(0)}%\n'
            'Location: ${nearestDistrict.name}',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Report'),
              onPressed: () {
                Navigator.pop(context);
                _navigateToCreatePostWithLocation(
                  nearestDistrict,
                  LatLng(position.latitude, position.longitude),
                  isRoadDamage: true,
                  roadDamageSeverity: severity,
                );
              },
            ),
          ],
        ),
      );
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

  List<Marker> _buildPostMarkers() {
    if (_cachedPostMarkers != null &&
        _allPosts.length == _cachedPostMarkers!.length) {
      return _cachedPostMarkers!;
    }

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
    // Filter districts based on current state if not showing all
    List<District> districtsToShow = _districts;
    if (!_showAllDistricts && _currentDistrict != null) {
      districtsToShow = _districts
          .where((d) => d.state == _currentDistrict!.state)
          .toList();
    }

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
                  constraints: const BoxConstraints(maxWidth: 65),
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
      CupertinoPageRoute(builder: (context) => ForumScreen(district: district)),
    );
  }

  void _navigateToPostDetail(Post post) {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (context) => PostDetailScreen(post: post)),
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
        ),
      ),
    );
  }

  /// Build user location marker
  List<Marker> _buildUserLocationMarker() {
    if (_currentUserPosition == null) return [];

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
        middle: const Text('Traffic Safety Malaysia'),
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
          child: const Icon(CupertinoIcons.info_circle),
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (context) => const DebugScreen()),
            );
          },
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
                  ),
                  children: [
                    Builder(
                      builder: (context) {
                        final devicePixelRatio = MediaQuery.of(
                          context,
                        ).devicePixelRatio;
                        return TileLayer(
                          // CartoDB Positron - Minimal road-focused style like Waze (roads only, minimal labels)
                          urlTemplate:
                              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.roadmobile.app',
                          retinaMode: devicePixelRatio > 1.0,
                          maxZoom: 19,
                          // Alternative: OpenStreetMap France (more detailed roads)
                          // urlTemplate: 'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
                        );
                      },
                    ),
                    // Heatmap layer
                    if (_showHeatmap)
                      CircleLayer(circles: _buildHeatmapCircles()),
                    // User location marker (always on top)
                    if (_currentUserPosition != null)
                      MarkerLayer(markers: _buildUserLocationMarker()),
                    // Danger point markers (AI-detected high risk)
                    MarkerLayer(markers: _buildDangerPointMarkers()),
                    // Post markers (incidents)
                    if (_allPosts.isNotEmpty)
                      MarkerLayer(markers: _buildPostMarkers()),
                    // Emergency markers
                    MarkerLayer(markers: _buildEmergencyMarkers()),
                    // District markers (forums)
                    MarkerLayer(markers: _buildDistrictMarkers()),
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
                        setState(() {
                          if (_legendBoxOffset < -175) {
                            _legendBoxOffset = -350;
                            _showLegendBox = false;
                          } else {
                            _legendBoxOffset = 0;
                          }
                        });
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
                              Row(
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
                            if (_currentUserPosition != null)
                              const SizedBox(height: 10),
                            Row(
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
                            const SizedBox(height: 10),
                            Row(
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
                            const SizedBox(height: 10),
                            Row(
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
                              onPressed: () {
                                setState(() {
                                  _showAllDistricts = !_showAllDistricts;
                                });
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
                                      const Text(
                                        'Regional Forums',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -0.5,
                                        ),
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
                                final district = _districts[index];
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
                              }, childCount: _districts.length),
                            ),
                          ),
                          // GPS Info Box at bottom
                          SliverToBoxAdapter(
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemBackground,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: CupertinoColors.black.withValues(
                                      alpha: 0.05,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _gpsStatus == 'GPS Disabled' ||
                                                _gpsStatus == 'No Location'
                                            ? CupertinoIcons.location_slash
                                            : CupertinoIcons.location_fill,
                                        size: 18,
                                        color: _gpsStatus == 'High Accuracy'
                                            ? CupertinoColors.systemGreen
                                            : _gpsStatus == 'Medium Accuracy'
                                            ? CupertinoColors.systemOrange
                                            : CupertinoColors.systemRed,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'GPS Status',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Accuracy',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: CupertinoColors
                                                  .secondaryLabel,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _gpsStatus,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  _gpsStatus == 'High Accuracy'
                                                  ? CupertinoColors.systemGreen
                                                  : _gpsStatus ==
                                                        'Medium Accuracy'
                                                  ? CupertinoColors.systemOrange
                                                  : CupertinoColors
                                                        .secondaryLabel,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (_currentSpeed != null &&
                                          _currentSpeed! > 0)
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            const Text(
                                              'Speed',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: CupertinoColors
                                                    .secondaryLabel,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${_currentSpeed!.toStringAsFixed(0)} km/h',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: CupertinoColors.label,
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  if (_currentUserPosition != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      height: 0.5,
                                      color: CupertinoColors.separator,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          CupertinoIcons.map_pin,
                                          size: 14,
                                          color: CupertinoColors.secondaryLabel,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            '${_currentUserPosition!.latitude.toStringAsFixed(6)}, ${_currentUserPosition!.longitude.toStringAsFixed(6)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: CupertinoColors
                                                  .secondaryLabel,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
                      onPressed: () {
                        setState(() {
                          _showLegendBox = true;
                          _legendBoxOffset = 0;
                        });
                      },
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
